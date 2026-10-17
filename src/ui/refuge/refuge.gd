class_name Refuge
extends Control
## Refuge : espace central entre les parties. Les onglets sont enregistrés dans TAB_SCRIPTS (modulaire).

const TAB_SCRIPTS: Array[String] = [
	"res://src/ui/refuge/expedition_tab.gd",
	"res://src/ui/refuge/tree_tab.gd",
	"res://src/ui/refuge/echo_tab.gd",
	"res://src/ui/refuge/bestiary_tab.gd",
	"res://src/ui/refuge/lab_tab.gd",
	"res://src/ui/refuge/objectives_tab.gd",
	"res://src/ui/refuge/stats_tab.gd",
	"res://src/ui/refuge/options_tab.gd",
]

var tabs: TabContainer
var _currencies: Label
var _warning: Label
var _tab_nodes: Array[RefugeTab] = []


func _ready() -> void:
	theme = MenuSkin.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	MenuSkin.background(self)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", MenuSkin.frame(Color(0.045, 0.025, 0.08, 0.92), MenuSkin.LANTERN))
	root.add_child(banner)
	banner.add_child(header)
	header.add_child(UiKit.label(tr("REFUGE_TITLE"), 32, MenuSkin.PAPER))
	_currencies = UiKit.label("", 20, UiKit.GOLD)
	_currencies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_currencies.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_currencies)
	header.add_child(UiKit.button(tr("REFUGE_MAIN_MENU"), func() -> void: Router.goto_main_menu(), 200))
	_warning = UiKit.label("", 15, UiKit.DANGER)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_warning)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	for path: String in TAB_SCRIPTS:
		var tab: RefugeTab = (load(path) as GDScript).new()
		tabs.add_child(tab)
		tab.setup(self)
		_tab_nodes.append(tab)
	tabs.tab_changed.connect(func(_index: int) -> void: refresh_current())
	Profile.changed.connect(refresh_all)
	Settings.changed.connect(refresh_all)
	refresh_all()
	Audio.play_context("refuge")


func refresh_all() -> void:
	for i: int in _tab_nodes.size():
		tabs.set_tab_title(i, tr(_tab_nodes[i].title_key()))
	_currencies.text = tr("REFUGE_CURRENCIES") % [Profile.profile.shards(), Profile.profile.essence()]
	_warning.text = Profile.status_message()
	_warning.visible = _warning.text != ""
	refresh_current()


func refresh_current() -> void:
	if tabs.current_tab >= 0 and tabs.current_tab < _tab_nodes.size():
		_tab_nodes[tabs.current_tab].refresh()
		MenuSkin.finish(_tab_nodes[tabs.current_tab])


## Sauvegarde puis rafraîchit (après un achat, un réglage...).
func commit() -> void:
	Audio.play_sfx(&"ui_click")
	Profile.save()
