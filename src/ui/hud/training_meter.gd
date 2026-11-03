class_name TrainingMeter
extends PanelContainer
## Salle d'entraînement (lot 6 des menus) : dégâts par seconde sur les dernières secondes, total et part de chaque
## source (Chasseur, Échos), lus dans les statistiques de la partie. Aucune règle de jeu ici.

const WINDOW := 5.0
const SAMPLE := 0.25

var _ctx: RunContext
## [instant, dégâts totaux] relevés toutes les SAMPLE secondes.
var _samples: Array[Vector2] = []
var _clock: float = 0.0
var _dps: Label
var _total: Label
var _sources: VBoxContainer


func _init(p_ctx: RunContext) -> void:
	_ctx = p_ctx
	name = "TrainingMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(20, 150)
	custom_minimum_size = Vector2(330, 0)
	add_theme_stylebox_override("panel", MenuSkin.frame(Color(0.04, 0.03, 0.07, 0.85), MenuSkin.LANTERN))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	box.add_child(UiKit.title(TranslationServer.translate("TRAINING_TITLE"), 20, MenuSkin.PAPER))
	_dps = UiKit.label("", 26, UiKit.GOLD)
	box.add_child(_dps)
	_total = UiKit.label("", 14, UiKit.MUTED)
	box.add_child(_total)
	_sources = VBoxContainer.new()
	box.add_child(_sources)
	box.add_child(UiKit.wrapped(TranslationServer.translate("TRAINING_HINT") % InputSetup.key_label(&"pause"), 12,
		UiKit.MUTED))


## Dégâts infligés depuis le début, par source (les dégâts subis, « taken_* », sont écartés).
static func dealt_by_source(damage: Dictionary) -> Dictionary:
	var dealt: Dictionary = {}
	for source: Variant in damage:
		if not String(source).begins_with("taken_"):
			dealt[String(source)] = float(damage[source])
	return dealt


## Dégâts par seconde sur la fenêtre [samples] (instant, total cumulé).
static func dps(samples: Array[Vector2]) -> float:
	if samples.size() < 2:
		return 0.0
	var span: float = samples[-1].x - samples[0].x
	return (samples[-1].y - samples[0].y) / span if span > 0.0 else 0.0


func _process(delta: float) -> void:
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = SAMPLE
	var dealt: Dictionary = dealt_by_source(_ctx.stats.damage_by_source)
	var total: float = 0.0
	for value: float in dealt.values():
		total += value
	_samples.append(Vector2(_ctx.time, total))
	while _samples.size() > 2 and _samples[-1].x - _samples[0].x > WINDOW:
		_samples.pop_front()
	_dps.text = TranslationServer.translate("TRAINING_DPS") % int(dps(_samples))
	_total.text = TranslationServer.translate("TRAINING_TOTAL") % int(total)
	UiKit.clear(_sources)
	var entries: Array = dealt.keys()
	entries.sort_custom(func(a: String, b: String) -> bool: return dealt[a] > dealt[b])
	for source: String in entries.slice(0, 4):
		var share: float = dealt[source] / maxf(total, 1.0)
		_sources.add_child(UiKit.label("%s · %d %%" % [ResultsPanel.source_name(source), roundi(share * 100.0)], 14,
			MenuSkin.PAPER))
