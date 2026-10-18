class_name LevelUpPanel
extends Control
## Choix d'amélioration au passage de niveau (jeu en pause). Relance et bannissement selon l'arbre.
## Les choix sont mis en réserve pendant le combat et s'ouvrent aux temps forts (RunController.release_choices).

signal closed

var ctx: RunContext
var _offers: Array[UpgradeOffer] = []
var _banish_mode: bool = false
var _cards: HFlowContainer
var _footer: HBoxContainer
var _title: Label


func setup(p_ctx: RunContext) -> void:
	ctx = p_ctx
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_child(UiKit.dimmer())
	var box: VBoxContainer = MenuSkin.modal_box(self, 18)
	_title = UiKit.label("", 34, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title)
	_cards = HFlowContainer.new()
	_cards.add_theme_constant_override("h_separation", 16)
	_cards.add_theme_constant_override("v_separation", 16)

	box.add_child(_cards)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	_footer.add_theme_constant_override("separation", 16)
	box.add_child(_footer)


func open() -> void:
	_banish_mode = false
	_offers = UpgradeOffers.roll(ctx, ctx.player.stats.get_int(StatKeys.UPGRADE_CHOICES))
	visible = true
	get_tree().paused = true
	_refresh()
	if ctx.setup.autopilot:
		_choose.call_deferred(ctx.rng.randi() % _offers.size())


func _refresh() -> void:
	_title.text = tr("LEVELUP_BANISH_TITLE") if _banish_mode else tr("LEVELUP_TITLE") % ctx.player.level
	if not _banish_mode and ctx.player.pending_levels > 1:
		_title.text += "  ·  " + tr("LEVELUP_REMAINING") % (ctx.player.pending_levels - 1)
	UiKit.clear(_cards)
	for i: int in _offers.size():
		var offer: UpgradeOffer = _offers[i]
		var accent: Color = UiKit.DANGER if _banish_mode else offer.color()
		var card: Button = UiKit.card(offer.category(), offer.title(), offer.description(), accent, _choose.bind(i))
		_cards.add_child(card)
		if offer.monster_id != &"":
			var evolution: EvolutionData = offer.evolution
			var ally: Ally = ctx.allies.get_ally(offer.monster_id)
			if evolution == null and ally:
				evolution = ally.evolution
			EchoPortrait.add_to_card(card, GameDB.monster(offer.monster_id),
				ctx.setup.palettes.get(offer.monster_id, []), evolution)
		elif offer.upgrade:
			ItemArt.add_to_card(card, "upgrade", offer.upgrade.id, accent)
		else:
			ItemArt.add_to_card(card, "offer", &"heal" if offer.kind == UpgradeOffer.Kind.HEAL else &"shards", accent)
	MenuSkin.finish(_cards)
	MenuSkin.focus_first(_cards)
	UiKit.clear(_footer)
	var rerolls_left: int = ctx.player.stats.get_int(StatKeys.REROLLS) - ctx.build.rerolls_used
	var banishes_left: int = ctx.player.stats.get_int(StatKeys.BANISHES) - ctx.build.banishes_used
	if rerolls_left > 0:
		_footer.add_child(UiKit.button(tr("LEVELUP_REROLL") % rerolls_left, _reroll))
	if banishes_left > 0:
		var label: String = tr("LEVELUP_BANISH_CANCEL") if _banish_mode else tr("LEVELUP_BANISH") % banishes_left
		_footer.add_child(UiKit.button(label, _toggle_banish))


func _reroll() -> void:
	ctx.build.rerolls_used += 1
	_offers = UpgradeOffers.roll(ctx, ctx.player.stats.get_int(StatKeys.UPGRADE_CHOICES))
	_refresh()


func _toggle_banish() -> void:
	_banish_mode = not _banish_mode
	_refresh()


func _choose(index: int) -> void:
	if not visible or index >= _offers.size():
		return
	var offer: UpgradeOffer = _offers[index]
	if _banish_mode:
		ctx.build.banished.append(StringName(offer.key))
		ctx.build.banishes_used += 1
		_banish_mode = false
		_offers.remove_at(index)
		if _offers.is_empty():
			_offers = UpgradeOffers.roll(ctx, ctx.player.stats.get_int(StatKeys.UPGRADE_CHOICES))
		_refresh()
		return
	UpgradeOffers.apply(ctx, offer)
	ctx.player.pending_levels = maxi(ctx.player.pending_levels - 1, 0)
	visible = false
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed:
		return
	var key: int = (event as InputEventKey).physical_keycode
	if key >= KEY_1 and key <= KEY_4:
		_choose(key - KEY_1)
		get_viewport().set_input_as_handled()
