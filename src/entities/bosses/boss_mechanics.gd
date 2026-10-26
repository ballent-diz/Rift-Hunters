class_name BossMechanics
extends Node2D
## Base des mécaniques de boss qui durent au-delà d'une attaque (orbes, couronne, miroirs, marée…) : état, mise à jour
## et dessin propres, aide au bot. Créées par BossController à la première attaque qui en a besoin
## (docs/design/MONSTRES.md, « Mécanique phare de chaque boss »). Le nœud reste jusqu'à la fin de la partie.

var ctx: RunContext
var brain: BossController
var _time: float = 0.0
var _intros: Dictionary = {}


func setup(p_ctx: RunContext, p_brain: BossController) -> void:
	ctx = p_ctx
	brain = p_brain
	z_index = 3


func boss() -> Enemy:
	return brain.boss


func step(delta: float) -> void:
	_time += delta


## Entrée dans une phase : mécaniques passives qu'elle active (BossPhaseData.mechanics, réglages mechanic_params).
func on_phase(_index: int, _phase: BossPhaseData) -> void:
	pass


## Bot : poussée d'évitement.
func danger(_pos: Vector2) -> Vector2:
	return Vector2.ZERO


## Bot : déplacement voulu par la mécanique (zéro : aucun), et Ruée voulue.
func bot_move(_pos: Vector2) -> Vector2:
	return Vector2.ZERO


func bot_dash() -> bool:
	return false


## Mort du boss : tout ce qui reste est retiré.
func finish() -> void:
	pass


## Explication de la mécanique, une fois par partie (bandeau du HUD).
func intro(key: String) -> void:
	if not _intros.has(key):
		_intros[key] = true
		ctx.events.event_started.emit(key)


## Position de l'auteur d'un coup allié : l'Écho qui frappe, sinon le Chasseur (tirs, sorts).
func source_position(info: DamageInfo) -> Vector2:
	if info.source_kind == DamageInfo.SourceKind.ALLY and ctx.allies:
		var ally: Ally = ctx.allies.get_ally(info.source_id)
		if ally:
			return ally.global_position
	return ctx.player.global_position


## Coup d'environnement porté au boss par sa propre mécanique (orbe ou rayon renvoyé), compté pour le Chasseur.
func strike_boss(ratio: float) -> void:
	var tags: Array[StringName] = [DamageInfo.TAG_DETONATION]
	var info := DamageInfo.make(boss().max_hp * ratio, DamageInfo.SourceKind.PLAYER, &"player", tags)
	info.is_proc = true
	ctx.combat.deal_damage(boss(), info)
