class_name EchoTreeBoard
extends Control
## Arbre d'un Écho (docs/design/ARBRES_DES_ECHOS.md) : Puissance et Concentration, puis le choix entre ses deux sorts,
## puis la Signature. Affichage seul : états lus depuis EchoTree.

signal node_selected(id: StringName)

const ROLES := {"_might": &"might", "_focus": &"focus", "_spell_base": &"spell", "_spell_alt": &"spell",
	"_signature": &"signature"}

var _profile: ProfileData
var _monster: MonsterData
var _buttons: Dictionary = {}
var _or_label: Label


func setup(p: ProfileData, monster: MonsterData, selected: StringName) -> void:
	_profile = p
	_monster = monster
	custom_minimum_size = Vector2(380, 330)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	for n: SkillNodeData in EchoTree.nodes_of(monster.id):
		var button := HunterTreeNode.new()
		button.symbol = role(n)
		button.configure(n, state_of(p, n), EchoTree.active_rank(p, n) if EchoTree.active_rank(p, n) > 0
			else EchoTree.learned_rank(p, n), n.id == selected, node_icon(n), display_name(n, monster), MenuSkin.PAPER)
		button.set_tip(display_name(n, monster), tr(HunterTreeSkin.KIND_KEYS[n.kind]), state_text(p, n),
			description(n, monster))
		button.pressed.connect(func() -> void: node_selected.emit(n.id))
		add_child(button)
		_buttons[role_key(n)] = button
	_or_label = UiKit.title(tr("ECHO_TREE_OR"), 16, HunterTreeSkin.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(_or_label)
	resized.connect(_layout)
	_layout.call_deferred()


## Les symboles existants restent visibles si une illustration manque.
static func node_icon(n: SkillNodeData) -> Texture2D:
	var id := StringName("icon.echo." + String(n.id))
	return Assets.icon(id) if not Assets.entry(id).is_empty() else null


static func role_key(n: SkillNodeData) -> String:
	for suffix: String in ROLES:
		if String(n.id).ends_with(suffix):
			return suffix
	return String(n.id)


static func role(n: SkillNodeData) -> StringName:
	return ROLES.get(role_key(n), &"")


## Le sort d'origine porte le nom et la description de la Technique de l'Écho.
static func display_name(n: SkillNodeData, monster: MonsterData) -> String:
	if n.kind == SkillNodeData.Kind.SPELL and n.learned_by_default:
		return TranslationServer.translate(monster.technique.name_key)
	return TranslationServer.translate(n.name_key)


static func description(n: SkillNodeData, monster: MonsterData) -> String:
	if n.kind == SkillNodeData.Kind.SPELL and n.learned_by_default:
		return TranslationServer.translate(monster.technique.desc_key)
	return TranslationServer.translate(n.desc_key)


static func state_of(p: ProfileData, n: SkillNodeData) -> String:
	if EchoTree.active_rank(p, n) > 0:
		return "active"
	match EchoTree.status(p, n):
		HunterTree.Status.LEARNED:
			return "learned"
		HunterTree.Status.LEARNABLE:
			return "learnable"
	return "learned" if EchoTree.learned_rank(p, n) > 0 else "locked"


static func state_text(p: ProfileData, n: SkillNodeData) -> String:
	var keys := {"active": "C5_ACTIVE", "learned": "TREE_STATE_LEARNED", "learnable": "C5_LEARNABLE",
		"locked": "TREE_STATE_LOCKED"}
	if EchoTree.status(p, n) == HunterTree.Status.TOO_EXPENSIVE and EchoTree.learned_rank(p, n) == 0:
		return TranslationServer.translate("TREE_SKIN_NEED_SHARDS")
	return TranslationServer.translate(keys[state_of(p, n)])


func _layout() -> void:
	var icon: float = clampf((size.y - 3 * HunterTreeNode.CAPTION_HEIGHT - 80) / 3.0, 44, 76)
	var extent := Vector2(150, icon + HunterTreeNode.CAPTION_HEIGHT)
	var gap: float = (size.y - 3 * extent.y) / 4.0
	var left: float = size.x * 0.28 - extent.x * 0.5
	var right: float = size.x * 0.72 - extent.x * 0.5
	_put("_might", Vector2(left, gap), extent)
	_put("_focus", Vector2(right, gap), extent)
	_put("_spell_base", Vector2(left, gap * 2 + extent.y), extent)
	_put("_spell_alt", Vector2(right, gap * 2 + extent.y), extent)
	_put("_signature", Vector2(size.x * 0.5 - extent.x * 0.5, gap * 3 + extent.y * 2), extent)
	_or_label.position = Vector2(size.x * 0.5 - 40, gap * 2 + extent.y + icon * 0.5 - 12)
	_or_label.size = Vector2(80, 24)
	queue_redraw()


func _put(key: String, at: Vector2, extent: Vector2) -> void:
	if _buttons.has(key):
		var button: HunterTreeNode = _buttons[key]
		button.position = at
		button.size = extent
		button.layout_caption()


## Axe vertical lisible : les deux passifs se rejoignent, mènent au choix du sort (« ou »), puis à la Signature.
func _draw() -> void:
	if not (_buttons.has("_might") and _buttons.has("_focus") and _buttons.has("_signature")):
		return
	var ink: Color = MenuSkin.PAPER
	var might: HunterTreeNode = _buttons["_might"]
	var focus: HunterTreeNode = _buttons["_focus"]
	var signature: HunterTreeNode = _buttons["_signature"]
	var lit: bool = might.current in ["learned", "active"] or focus.current in ["learned", "active"]
	var color := Color(ink, 0.85 if lit else 0.3)
	var bus: float = might.position.y + might.size.y + 8
	var left: float = might.position.x + might.size.x * 0.5
	var right: float = focus.position.x + focus.size.x * 0.5
	var middle: float = size.x * 0.5
	var choice_top: float = _or_label.position.y - 4
	var choice_bottom: float = _or_label.position.y + _or_label.size.y + 4
	for segment: PackedVector2Array in [
			PackedVector2Array([Vector2(left, bus - 8), Vector2(left, bus), Vector2(right, bus), Vector2(right, bus - 8)]),
			PackedVector2Array([Vector2(middle, bus), Vector2(middle, choice_top)]),
			PackedVector2Array([Vector2(middle, choice_bottom), Vector2(middle, signature.position.y - 4)])]:
		draw_polyline(segment, Color(0.025, 0.025, 0.055, 0.9), 5, true)
		draw_polyline(segment, color, 2, true)
	# Les deux sorts s'excluent : un trait pointillé les relie de part et d'autre du « ou ».
	if _buttons.has("_spell_base") and _buttons.has("_spell_alt"):
		var a: HunterTreeNode = _buttons["_spell_base"]
		var b: HunterTreeNode = _buttons["_spell_alt"]
		var y: float = a.position.y + a.emblem_rect().get_center().y
		var gold := Color(HunterTreeSkin.GOLD, 0.55)
		draw_dashed_line(Vector2(a.position.x + a.emblem_rect().end.x + 8, y), Vector2(middle - 30, y), gold, 1.5, 6)
		draw_dashed_line(Vector2(middle + 30, y), Vector2(b.position.x + b.emblem_rect().position.x - 8, y), gold, 1.5, 6)
