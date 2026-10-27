class_name HunterTreeSkin
extends RefCounted
## Habillage de C5. Aucune décision de progression : états et icônes sont lus depuis les données/API.

const ART := "res://assets/ui/hunter_tree/"
const PAPER := Color("f5dfc6")
const MUTED := Color("a69ba9")
const NIGHT := Color("101326")
const GOLD := Color("edc18d")
const CYAN := Color("a5ebec")
## Coût hors de portée (Éclats ou points manquants).
const SHORT := Color("ef8f8f")
## États présentés dans la légende, du plus fermé au plus engagé.
const LEGEND: Array[String] = ["locked", "learnable", "learned", "active"]
const LEGEND_KEYS := {"locked": "TREE_STATE_LOCKED", "learnable": "C5_LEARNABLE", "learned": "TREE_STATE_LEARNED",
	"active": "TREE_LEGEND_ACTIVE"}
const PATHS: Array[StringName] = [&"blade", &"prism", &"abyss", &"bond"]
const ACCENTS := {&"trunk": PAPER, &"blade": GOLD, &"prism": Color("74dce7"),
	&"abyss": Color("b7a7df"), &"bond": Color("a5d4b5")}
const ICON_ALIASES := {"blade_slicing_dash": "slashing_dash", "blade_counter_cut": "counter_slash",
	"prism_propagation": "propagation", "prism_split_bolt": "split_bolt", "abyss_void_wake": "void_wake",
	"abyss_anchor": "anchor", "bond_close_guard": "close_guard", "bond_fusion": "fusion",
	"blade_master": "blade_master", "prism_living_prism": "living_prism",
	"abyss_void_master": "void_master", "bond_pack_soul": "pack_soul",
	"combat_training": "combat_training", "trunk_vigor": "trunk_vigor",
	"combat_phantom_step": "combat_phantom_step", "combat_last_breath": "combat_last_breath",
	"blade_honed_edge": "blade_honed_edge", "combat_rift_brawler": "combat_rift_brawler",
	"combat_shattering_dash": "combat_shattering_dash", "combat_marksman": "combat_marksman",
	"spec_chain_detonation": "spec_chain_detonation", "spec_prismatic_resonance": "spec_prismatic_resonance",
	"spec_pyromancer": "spec_pyromancer", "abyss_depths": "abyss_depths",
	"spec_deep_breach": "spec_deep_breach", "spec_gravitationist": "spec_gravitationist",
	"echoes_bonds": "echoes_bonds", "echoes_lone_hunter": "echoes_lone_hunter",
	"echoes_pack_leader": "echoes_pack_leader", "echoes_sharpened": "echoes_sharpened",
	"echoes_third_seal": "echoes_third_seal", "echoes_veteran": "echoes_veteran",
	"research_banish": "research_banish", "research_early_evolution": "research_early_evolution",
	"research_fourth_option": "research_fourth_option", "research_rift_study": "research_rift_study",
	"research_unstable": "research_unstable", "explore_essence_sense": "explore_essence_sense",
	"explore_magnet": "explore_magnet", "explore_prospector": "explore_prospector",
	"explore_sealed_chests": "explore_sealed_chests", "explore_starting_relic": "explore_starting_relic"}
const SPELL_ALIASES := {"aegis": "rift_aegis", "refracting_crystal": "refractor_crystal"}
const VARIANT_A: Array[StringName] = [&"whirlwind", &"return", &"mirror", &"fan", &"reaction", &"double",
	&"horizon", &"chains", &"loop", &"rally", &"riposte", &"relay"]
const KIND_KEYS := {
	SkillNodeData.Kind.UTILITY: "TREE_KIND_UTILITY", SkillNodeData.Kind.PASSIVE: "TREE_KIND_PASSIVE",
	SkillNodeData.Kind.SPELL: "TREE_KIND_SPELL", SkillNodeData.Kind.VARIANT: "TREE_KIND_VARIANT",
	SkillNodeData.Kind.TRANSFORM: "TREE_KIND_TRANSFORM", SkillNodeData.Kind.KEYSTONE: "TREE_KIND_KEYSTONE"}


static func accent(branch: StringName) -> Color:
	return ACCENTS.get(branch, PAPER)


static func state(p: ProfileData, node: SkillNodeData) -> String:
	if HunterTree.status(p, node) == HunterTree.Status.COMING_SOON:
		return "upcoming"
	if HunterTree.active_rank(p, node) > 0 and not node.is_utility():
		return "active"
	match HunterTree.status(p, node):
		HunterTree.Status.COMING_SOON: return "upcoming"
		HunterTree.Status.LEARNED: return "learned"
		HunterTree.Status.LEARNABLE: return "learnable"
	return "locked"


static func state_text(p: ProfileData, node: SkillNodeData) -> String:
	if HunterTree.status(p, node) == HunterTree.Status.TOO_EXPENSIVE and HunterTree.active_rank(p, node) == 0:
		return TranslationServer.translate("TREE_SKIN_NEED_SHARDS")
	var keys := {"upcoming": "TREE_COMING_SOON", "learned": "TREE_STATE_LEARNED",
		"learnable": "C5_LEARNABLE", "locked": "TREE_STATE_LOCKED", "active": "C5_ACTIVE"}
	return TranslationServer.translate(keys[state(p, node)])


static func frame(node: SkillNodeData, current: String) -> Texture2D:
	var kind: String = "passive"
	match node.kind:
		SkillNodeData.Kind.SPELL: kind = "spell"
		SkillNodeData.Kind.TRANSFORM, SkillNodeData.Kind.VARIANT: kind = "transform"
		SkillNodeData.Kind.KEYSTONE: kind = "keystone"
	return load(ART + "node_%s_%s.svg" % [kind, current])


## Cadre d'un état sans nœud particulier (légende, guide).
static func state_frame(current: String, kind: String = "passive") -> Texture2D:
	return load(ART + "node_%s_%s.svg" % [kind, current])


static func icon(node: SkillNodeData) -> Texture2D:
	var id: String = str(node.spell_id)
	if id == "":
		id = ICON_ALIASES.get(str(node.id), "")
	id = SPELL_ALIASES.get(id, id)
	return Assets.icon(StringName("icon.hunter." + id)) if id != "" else null


static func variant_letter(node: SkillNodeData) -> String:
	return "A" if node.variant_kind in VARIANT_A else "B"


static func panel(file: String = "panel", margin: int = 10) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(ART + file + ".svg")
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 14)
		style.set_content_margin(side, margin)
	return style


static func button(text: String, callback: Callable, active: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 32
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", panel("build_active" if active else "build_idle", 6))
	b.add_theme_stylebox_override("hover", panel("build_active", 6))
	b.add_theme_stylebox_override("pressed", panel("build_active", 6))
	b.add_theme_stylebox_override("disabled", panel("build_idle", 6))
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.pressed.connect(callback)
	return b


static func trimmed(text: String, font_size: int = 14, color: Color = PAPER) -> Label:
	var label: Label = UiKit.label(text, font_size, color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	return label


## Case scellée d'un plateau d'arbre : voile assombri et hachures coupées aux bords.
static func draw_veil(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color(0.01, 0.01, 0.03, 0.42))
	var y: float = rect.position.y - rect.size.x
	while y < rect.end.y:
		var a := Vector2(rect.position.x, y)
		var b := Vector2(rect.end.x, y + rect.size.x)
		var from: Vector2 = a if a.y >= rect.position.y else a + (b - a) * ((rect.position.y - a.y) / (b.y - a.y))
		var to: Vector2 = b if b.y <= rect.end.y else a + (b - a) * ((rect.end.y - a.y) / (b.y - a.y))
		canvas.draw_line(from, to, Color(1, 1, 1, 0.025), 2.0)
		y += 14.0


## Petit cadenas (colonne ou embranchement scellé).
static func draw_lock(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_rect(Rect2(center - Vector2(5, 1), Vector2(10, 8)), SHORT)
	canvas.draw_arc(center - Vector2(0, 1), 3.5, PI, TAU, 10, SHORT, 1.6, true)


## Pastille de ressource : symbole, rubrique (à quoi elle sert), valeur ; l'infobulle explique d'où elle vient.
static func chip(chip_name: String, glyph: String, color: Color, caption_text: String, value: String,
		hint: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.name = chip_name
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.1, 0.95)
	style.border_color = color.darkened(0.4)
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.set_corner_radius_all(3)
	style.content_margin_left = 10
	style.content_margin_right = 12
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	box.add_theme_stylebox_override("panel", style)
	box.tooltip_text = hint
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var icon: Label = UiKit.label(glyph, 18, color)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -3)
	row.add_child(text)
	text.add_child(UiKit.caption(caption_text, 9, MUTED))
	var amount: Label = UiKit.label(value, 15, color)
	amount.add_theme_font_override("font", UiKit.font(&"numbers"))
	text.add_child(amount)
	for child: Node in box.find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


## Bandeau des trois étapes (apprendre › activer › équiper), toujours sous les yeux ; hints : précision de chaque étape.
static func steps_strip(hints: Array[String]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "TreeSteps"
	row.add_theme_constant_override("separation", 6)
	var keys: Array[String] = ["TREE_STEP_LEARN", "TREE_STEP_ACTIVATE", "TREE_STEP_EQUIP"]
	var colors: Array[Color] = [CYAN, GOLD, PAPER]
	for i: int in keys.size():
		var step := HBoxContainer.new()
		step.add_theme_constant_override("separation", 6)
		step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i > 0:
			step.add_child(UiKit.label("›", 16, MUTED))
		step.add_child(UiKit.label(["①", "②", "③"][i], 15, colors[i]))
		var title: Label = UiKit.caption(TranslationServer.translate(keys[i]), 12, colors[i])
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		step.add_child(title)
		var hint: Label = trimmed(TranslationServer.translate(hints[i]), 13, MUTED)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		step.add_child(hint)
		row.add_child(step)
	return row
