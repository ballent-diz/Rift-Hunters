extends Node
## Validation des huit FX dédiés des mutations v2 (docs/design/FICHES_VFX_MUTATIONS_V2.md) dans une vraie partie.
## Mode capture (par défaut) : chaque FX est mis en scène (ennemis immobiles, vrai lancer), photographié au pic et
## mesuré (largeur, ancrage, suivi, disparition).
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 \
##     res://tools/mutation_fx_showcase.tscn -- --bot --passive --out=docs/previews/mutations_v2 [--only=rain_storm]
## Mode balayage (`--sweep`, possible en --headless) : les 15 sorts, sans mutation puis avec chaque mutation seule et
## les deux mutations compatibles, lancés trois fois ; vérifie qu'aucun effet ne reste affiché après expiration.

const STAGES: Array[StringName] = [&"mark_execute", &"mark_hunt", &"rend_pierce", &"step_trap", &"stasis_shards",
	&"rain_storm", &"rain_focus", &"veil_recoil"]
## Largeur en jeu (m) et hauteur d'ancrage (m au-dessus du sol de la cible) attendues par la fiche.
const SPEC := {&"mark_execute": [2.2, 0.6], &"mark_hunt": [1.6, 1.0], &"rend_pierce": [1.6, 0.6],
	&"step_trap": [2.7, 0.3], &"stasis_shards": [1.2, 0.9], &"rain_storm": [6.0, 0.3], &"rain_focus": [1.6, 0.8],
	&"veil_recoil": [1.2, -1.0]}
## Temps d'attente maximal avant de constater qu'un effet est encore affiché (s).
const LINGER := 9.0

var run: DraftRun
var _out: String = "user://mutations_v2"
var _report: Array[String] = []
var _failures: int = 0


func _ready() -> void:
	var only: String = ""
	var sweep: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg == "--sweep":
			sweep = true
	if sweep:
		await _sweep()
	else:
		DirAccess.make_dir_recursive_absolute(_out)
		for stage: StringName in STAGES:
			if only == "" or only == String(stage):
				await _stage(stage)
	_report.append("ÉCHECS : %d" % _failures)
	print("\n".join(_report))
	get_tree().quit(1 if _failures > 0 else 0)


# --- Mise en place -------------------------------------------------------------------------------------------------

func _start() -> void:
	run = (load("res://draft3d/main.tscn") as PackedScene).instantiate()
	add_child(run)
	for frame: int in 900:
		if run.state == DraftRun.State.PLAYING:
			break
		await get_tree().physics_frame
	run._bot = false
	run.spells.auto_cast = false
	run.hunter.automating = false
	run.boss_time = INF
	run.tuning = run.tuning.duplicate()
	run.tuning.waves.assign([{"at": 0.0, "rate": 0.0, "cap": 0, "mix": {"skitterling": 1.0}}])
	run.tuning.swarm_every = INF
	run._swarm_at = INF
	run.hunter.attack_timer = 100000.0
	run.hunter.god_mode = true
	run.enemies.clear_all()
	for i: int in run.spells.slots.size():
		run.spells.stash(i)
	run.view_size = 10.0


func _equip(id: StringName, cards: Array) -> int:
	run.spells.learn(id)
	if not run.spells.has_spell(id):
		run.spells.equip(id, run.spells.slots.find(null))
	for card: String in cards:
		run.spells.add_mutation(_effect(card))
	return run.spells.slot_of(id)


func _effect(card: String) -> DraftSpellEffect:
	return (load("res://draft3d/spells/%s.tres" % card) as UpgradeData).effects[0] as DraftSpellEffect


func _foe(offset: Vector3, hp: float = 100000.0) -> DraftEnemies.Foe:
	var foe: DraftEnemies.Foe = run.enemies.spawn(GameDB.enemy(&"husk"), run.hunter.global_position + offset)
	foe.speed = 0.0
	foe.max_hp = hp
	foe.hp = hp
	return foe


func _cast(slot: int, offset: Vector3) -> void:
	run.spells.cooldowns[slot] = 0.0
	run.spells.cast(slot, run.hunter.global_position + offset)


func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().physics_frame


## Effets dédiés `mutation_<stage>` affichés en ce moment.
func _nodes(stage: StringName) -> Array[DraftPixelFx]:
	var found: Array[DraftPixelFx] = []
	for child: Node in run.get_children():
		if child is DraftPixelFx and not child.is_queued_for_deletion() and (child as DraftPixelFx).texture != null \
				and (child as DraftPixelFx).texture.resource_path.contains("mutation_" + String(stage)):
			found.append(child)
	return found


## Attend le premier effet dédié (au plus `limit` images).
func _wait_for(stage: StringName, limit: int) -> DraftPixelFx:
	for frame: int in limit:
		var found: Array[DraftPixelFx] = _nodes(stage)
		if not found.is_empty():
			return found[0]
		await get_tree().physics_frame
	return null


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
	_report.append("  %s %s" % ["ok  " if ok else "ÉCHEC", label])


# --- Captures des huit FX ------------------------------------------------------------------------------------------

func _stage(stage: StringName) -> void:
	await _start()
	_report.append("[%s]" % stage)
	var target: DraftEnemies.Foe = null
	var ground: Vector3 = run.hunter.global_position
	var peak: int = 4
	match stage:
		&"mark_execute":
			var slot: int = _equip(&"hunter_mark", ["mark_execute"])
			target = _foe(Vector3(3, 0, 0), 1000.0)
			await _frames(3)
			_cast(slot, Vector3(3, 0, 0))
			await _frames(2)
			target.hp = target.max_hp * 0.15
			peak = 14
		&"mark_hunt":
			var slot: int = _equip(&"hunter_mark", ["mark_hunt"])
			# La marque vise l'ennemi aux PV max les plus élevés : le premier porteur doit l'emporter.
			var first: DraftEnemies.Foe = _foe(Vector3(3, 0, 0))
			target = _foe(Vector3(4.5, 0, 1.2), 1000.0)
			await _frames(3)
			_cast(slot, Vector3(3, 0, 0))
			await _frames(2)
			first.hp = 1.0
			run.enemies.hit(first, 1000.0)
			peak = 8
		&"rend_pierce":
			var slot: int = _equip(&"void_rend", ["rend_pierce"])
			target = _foe(Vector3(2.0, 0, 0))
			_foe(Vector3(3.2, 0, 0.2))
			_foe(Vector3(4.4, 0, -0.2))
			await _frames(3)
			_cast(slot, Vector3(6, 0, 0))
			peak = 4
		&"step_trap":
			var slot: int = _equip(&"rift_step", ["step_trap"])
			_foe(Vector3(0.8, 0, 0.6))
			await _frames(3)
			ground = run.hunter.global_position
			_cast(slot, Vector3(5, 0, 0))
			peak = 12
		&"stasis_shards":
			var slot: int = _equip(&"stasis_wave", ["stasis_shards"])
			target = _foe(Vector3(2.5, 0, 0))
			_foe(Vector3(3.5, 0, 1.0))
			_foe(Vector3(3.5, 0, -1.0))
			await _frames(3)
			_cast(slot, Vector3(3, 0, 0))
			peak = 18
		&"rain_storm":
			var slot: int = _equip(&"shard_rain", ["rain_storm"])
			_foe(Vector3(2, 0, 1))
			await _frames(3)
			_cast(slot, Vector3(4, 0, 0))
			peak = 4
		&"rain_focus":
			var slot: int = _equip(&"shard_rain", ["rain_focus"])
			_foe(Vector3(4, 0, 0))
			await _frames(3)
			_cast(slot, Vector3(4, 0, 0))
			peak = 7
		&"veil_recoil":
			var slot: int = _equip(&"ash_veil", ["veil_recoil"])
			await _frames(3)
			_cast(slot, Vector3(2, 0, 0))
			await _frames(2)
			var here: Vector3 = run.hunter.global_position
			run.hostile_shot(here + Vector3(3.5, 0.6, 0), Vector3(-1, 0, 0), 4.0, 1.0, &"violet")
			peak = 9
	var node: DraftPixelFx = await _wait_for(stage, 150)
	_check(node != null, "effet dédié affiché au déclenchement")
	if node == null:
		run.queue_free()
		await _frames(2)
		return
	var width: float = node.region_rect.size.x * node.pixel_size
	var spec: Array = SPEC[stage]
	_check(absf(width - float(spec[0])) <= float(spec[0]) * 0.15,
		"largeur %.2f m (fiche %.2f m)" % [width, float(spec[0])])
	var ground_fx: bool = stage in [&"step_trap", &"rain_storm"]
	_check(node.render_priority == (DraftPixelFx.UNDER_TELEGRAPHS if ground_fx else 0),
		"priorité %d (%s)" % [node.render_priority, "sous les télégraphes" if ground_fx else "devant sa cible"])
	var bottom: float = node.position.y - run.camera.global_basis.y.y * node.region_rect.size.y * node.pixel_size * 0.5
	_check(bottom >= run.hunter.global_position.y - 0.01, "image non coupée par le sol (bas à %.2f m)" % bottom)
	if target != null:
		var lift: float = node.anchor.y - target.pos.y
		var flat: float = Vector2(node.anchor.x - target.pos.x, node.anchor.z - target.pos.z).length()
		_check(flat < 0.3 and absf(lift - float(spec[1])) < 0.15,
			"ancré sur la cible (écart %.2f m, hauteur %.2f m, fiche %.2f m)" % [flat, lift, float(spec[1])])
	elif stage == &"step_trap":
		var flat_step: float = Vector2(node.anchor.x - ground.x, node.anchor.z - ground.z).length()
		_check(flat_step < 0.3, "au point de départ (écart %.2f m)" % flat_step)
	await _frames(peak)
	if stage == &"rain_storm" and is_instance_valid(node):
		var hunter_before: Vector3 = run.hunter.global_position
		run.hunter.global_position = hunter_before + Vector3(1.5, 0, 0.8)
		await _frames(2)
		var gap: float = Vector2(node.anchor.x - run.hunter.global_position.x,
			node.anchor.z - run.hunter.global_position.z).length()
		_check(gap < 0.3, "la zone suit le Chasseur (écart %.2f m)" % gap)
		await _frames(30)
	await RenderingServer.frame_post_draw
	var shown: Array[DraftPixelFx] = _nodes(stage)
	_report.append("  capture : %d effet(s), image %s" % [shown.size(),
		str(int(shown[0].region_rect.position.x / maxf(shown[0].region_rect.size.x, 1.0))
			+ 4 * int(shown[0].region_rect.position.y / maxf(shown[0].region_rect.size.y, 1.0))) if not shown.is_empty() else "-"])
	get_viewport().get_texture().get_image().save_png(_out.path_join("%s.png" % stage))
	var gone: bool = false
	for frame: int in int(LINGER * 60.0):
		if _nodes(stage).is_empty():
			gone = true
			break
		await get_tree().physics_frame
	_check(gone, "retiré après expiration")
	run.queue_free()
	await _frames(2)


# --- Balayage des 15 sorts -----------------------------------------------------------------------------------------

## Sort → mutations (cartes VARIANT), lues dans draft3d/spells/.
func _catalog() -> Dictionary:
	var result: Dictionary = {}
	for file: String in DirAccess.get_files_at("res://draft3d/spells"):
		if not file.ends_with(".tres"):
			continue
		var card: UpgradeData = load("res://draft3d/spells/" + file) as UpgradeData
		var effect: DraftSpellEffect = card.effects[0] as DraftSpellEffect if not card.effects.is_empty() else null
		if effect == null:
			continue
		if effect.kind == DraftSpellEffect.Kind.LEARN:
			result[effect.spell_id] = result.get(effect.spell_id, [])
		elif effect.kind == DraftSpellEffect.Kind.VARIANT:
			var list: Array = result.get(effect.spell_id, [])
			list.append(file.get_basename())
			result[effect.spell_id] = list
	return result


## Effets visibles : sprites d'effets (hors Chasseur) et effets peints des sorts historiques.
func _visible_fx() -> int:
	var count: int = run.spells.vfx.playing.size()
	for child: Node in run.get_children():
		if child is SpriteBase3D and not child.is_queued_for_deletion() and child != run.hunter:
			count += 1
	return count


func _sweep() -> void:
	var catalog: Dictionary = _catalog()
	var spells: Array = catalog.keys()
	spells.sort()
	_report.append("%d sorts, %d mutations" % [spells.size(),
		spells.reduce(func(acc: int, id: StringName) -> int: return acc + (catalog[id] as Array).size(), 0)])
	for id: StringName in spells:
		var cards: Array = catalog[id]
		cards.sort()
		var configs: Array = [[]]
		for card: String in cards:
			configs.append([card])
		if cards.size() == 2 and not _effect(cards[0]).incompatible.has(_effect(cards[1]).variant):
			configs.append(cards)
		for config: Array in configs:
			await _sweep_one(id, config)


func _sweep_one(id: StringName, cards: Array) -> void:
	await _start()
	await _frames(5)
	var baseline: int = _visible_fx()
	var slot: int = _equip(id, cards)
	var taken: Array[StringName] = run.spells.mutations(id)
	for offset: Vector3 in [Vector3(3, 0, 0.6), Vector3(3, 0, -0.6), Vector3(5, 0, 1.5), Vector3(1.5, 0, -1.5)]:
		_foe(offset, 400.0)
	await _frames(3)
	var casts: int = 0
	for attempt: int in 3:
		run.spells.cooldowns[slot] = 0.0
		if run.spells.cast(slot, run.hunter.global_position + Vector3(3, 0, 0)):
			casts += 1
		if id == &"parry":
			run.hunter.parried.emit()
		await _frames(50)
	var peak: int = _visible_fx()
	run.enemies.clear_all()
	var left: int = 0
	for frame: int in int(LINGER * 60.0):
		left = _visible_fx() - baseline
		if left <= 0:
			break
		await get_tree().physics_frame
	var label: String = "%-20s %-40s lancers %d/3, effets au pic %d, restants %d" % [id, str(cards), casts,
		peak - baseline, maxi(left, 0)]
	_check(casts > 0 and left <= 0 and taken.size() == cards.size(), label)
	run.queue_free()
	await _frames(2)
