class_name ChestPanel
extends Control
## Coffre de faille : choisir une relique OU briser le coffre (Éclats + soin). Une vraie décision.

signal closed

var ctx: RunContext
var _relics: Array[RelicData] = []
var _cards: HBoxContainer
var _footer: HBoxContainer
var _title: Label
var _subtitle: Label
var _free_choice: bool = false


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_child(UiKit.dimmer())
	var box: VBoxContainer = MenuSkin.modal_box(self, 16)
	_title = UiKit.label("", 34, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title)
	_subtitle = UiKit.label("", 16, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_subtitle)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 16)
	_cards.custom_minimum_size.x = 820
	box.add_child(_cards)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_footer)


## free_choice : relique de départ (pas d'option « briser »).
func open(free_choice: bool = false) -> void:
	_free_choice = free_choice
	_relics = UpgradeOffers.relic_choices(ctx, ctx.player.stats.get_int(StatKeys.RELIC_CHOICES))
	visible = true
	get_tree().paused = true
	_title.text = tr("CHEST_START_TITLE") if free_choice else tr("CHEST_TITLE")
	_subtitle.text = tr("CHEST_SUBTITLE")
	_refresh_cards()
	UiKit.clear(_footer)
	if not free_choice or _relics.is_empty():
		var shards: int = ctx.balance.chest_break_shards
		_footer.add_child(UiKit.button(tr("CHEST_BREAK") % shards, _break, 360))
	if ctx.setup.autopilot:
		if _relics.is_empty():
			_break.call_deferred()
		else:
			_take.call_deferred(0)


func _refresh_cards() -> void:
	UiKit.clear(_cards)
	for i: int in _relics.size():
		var relic: RelicData = _relics[i]
		var card: Button = UiKit.card(tr("RELIC_RARITY_%d" % relic.rarity), tr(relic.name_key), tr(relic.desc_key),
			relic.color, _take.bind(i))
		_cards.add_child(card)
		ItemArt.add_to_card(card, "relic", relic.id, relic.color)
	MenuSkin.finish(_cards)
	if _cards.get_child_count() > 0:
		(_cards.get_child(0) as Control).grab_focus.call_deferred()


func _take(index: int) -> void:
	if not visible:
		return
	UpgradeOffers.apply_relic(ctx, _relics[index])
	_close()


func _break() -> void:
	if not visible:
		return
	ctx.stats.add(&"shards_earned_raw", ctx.balance.chest_break_shards)
	ctx.stats.add(&"chests_broken")
	ctx.player.heal(ctx.player.max_hp * ctx.balance.chest_break_heal_ratio)
	_close()


func _close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()
