class_name DraftBossTest
extends RefCounted
## Raccourcis de test pour vérifier un combat de boss (demande du propriétaire, 17 novembre 2026) :
## - touche F9 ou bouton « Aller au boss (test) » de la pause : la vague en cours est retirée et le boss de la carte
##   arrive tout de suite (sommet de la tour compris) ;
## - `--boss-test --chapter=N [--boss-level=15]` : la partie démarre directement sur le boss du chapitre, avec un
##   Chasseur monté de niveaux (améliorations tirées comme au choix de niveau) ;
## - dans tous les cas, l'arsenal est rempli : tous les sorts et passifs, mutations tirées au hasard (`fill_arsenal`).
## Réservé aux versions de développement (`OS.is_debug_build`) : invisible dans une version exportée. Une partie où le
## raccourci a servi ne compte pas : ni victoire de chapitre ni gain de Fragments enregistrés (`DraftRun.test_run`).


static func enabled() -> bool:
	return OS.is_debug_build()


## `--boss=<id>` : ce boss remplace le Dévoreur du chapitre (et sa famille de monstres si la v2 lui en donne une).
## Sans effet dans une version exportée ou pour un identifiant inconnu.
static func force_boss(run: DraftRun, id: StringName) -> void:
	var boss: BossData = GameDB.boss(id)
	if not enabled() or boss == null:
		return
	run.test_run = true
	run.roster.boss = boss
	for entry: Dictionary in DraftRoster.V2_CHAPTERS:
		if entry.get("boss", &"") != id:
			continue
		var own: Array[EnemyData] = []
		for enemy_id: StringName in entry.get("enemies", []):
			if DraftRoster.usable(GameDB.enemy(enemy_id)):
				own.append(GameDB.enemy(enemy_id))
		if not own.is_empty():
			run.roster.enemies = own


## « Aller au boss » : vague retirée, gardien sauté, boss tout de suite. Sans effet si le boss est déjà là.
static func skip_to_boss(run: DraftRun) -> void:
	if run.state != DraftRun.State.PLAYING or run._boss_spawned:
		return
	run.test_run = true
	run._guardian_spawned = true
	run._swarm_at = INF
	run.enemies.clear_all()
	run.hazards.clear()
	if run.tower != null:
		while not run.tower.summit():
			await run.tower.climb()
		run.tower.arrived_at = run.time - run.tuning.tower_boss_delay
	fill_arsenal(run)
	run.boss_time = run.time
	run.hud.banner(run.tr("DRAFT_TEST_BOSS"), 3.0)


## Chasseur monté de `levels` niveaux ; les mutations qui demandent de choisir un emplacement sont laissées de côté.
static func prepare_hunter(run: DraftRun, levels: int) -> void:
	for i: int in levels:
		# Quelques tirages au besoin : un tirage peut n'offrir que des mutations à emplacement.
		var applied: bool = false
		for attempt: int in 8:
			for card: UpgradeData in run.upgrades.roll(run.rng, run.balance.upgrade_choices):
				var mutation := card.effects[0] as DraftSpellEffect if not card.effects.is_empty() else null
				if (mutation == null or mutation.kind != DraftSpellEffect.Kind.VARIANT) \
						and run.upgrades.apply(card, run.hunter.stats):
					applied = true
					break
			if applied:
				break
		if not applied:
			break
		run.hunter.level += 1
	run.hunter.heal(run.hunter.max_hp())
	run.hud.show_build(run.upgrades)


## Arsenal rempli pour le test (demande du propriétaire, 17 novembre) : emplacement en plus, tous les sorts raccordés
## appris (ordre tiré au hasard : les sorts équipés changent d'un test à l'autre, les autres vont en réserve), tous les
## passifs, et pour chaque sort des mutations tirées au hasard (deux au plus, compatibles). Déblocages ignorés.
static func fill_arsenal(run: DraftRun) -> void:
	var upgrades: DraftUpgrades = run.upgrades
	var locks: DraftUnlocks = upgrades.unlocks
	upgrades.unlocks = null
	var cards: Array[UpgradeData] = upgrades.spell_cards.duplicate()
	_shuffle(cards, run.rng)
	for kind: DraftSpellEffect.Kind in [DraftSpellEffect.Kind.RULE, DraftSpellEffect.Kind.LEARN,
			DraftSpellEffect.Kind.PASSIVE, DraftSpellEffect.Kind.VARIANT]:
		for card: UpgradeData in cards:
			var effect := card.effects[0] as DraftSpellEffect
			if effect == null or effect.kind != kind or not upgrades.can_offer(card):
				continue
			if kind == DraftSpellEffect.Kind.VARIANT:
				# Mutation seulement s'il reste une case compatible : jamais de remplacement.
				if run.spells.replaceable_mutations(effect) != ([&""] as Array[StringName]):
					continue
				run.spells.mutation_to_replace = &""
			upgrades.apply(card, run.hunter.stats)
	upgrades.unlocks = locks
	run.hud.show_build(upgrades)


static func _shuffle(cards: Array[UpgradeData], rng: RandomNumberGenerator) -> void:
	for i: int in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var swap: UpgradeData = cards[i]
		cards[i] = cards[j]
		cards[j] = swap
