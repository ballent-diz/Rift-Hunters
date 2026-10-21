extends RefugeTab
## Boutique (lot M3, docs/design/MODES.md) : Échos en vente, consommables à emporter, avantages des épreuves de
## survie, apparences (plus tard). Toutes les règles sont dans Shop et EchoCollection.

func title_key() -> String:
	return "TAB_SHOP"


func refresh() -> void:
	var box: VBoxContainer = scroll_box(10)
	var p: ProfileData = profile()
	box.add_child(UiKit.wrapped(tr("SHOP_INTRO"), 15))
	box.add_child(UiKit.title(tr("SHOP_SECTION_ECHOES"), 20, MenuSkin.PAPER))
	var for_sale: Array[MonsterData] = []
	for monster: MonsterData in GameDB.monsters.values():
		if monster.discovery == EchoCollection.SHOP and not p.is_monster_unlocked(monster):
			for_sale.append(monster)
	for_sale.sort_custom(func(a: MonsterData, b: MonsterData) -> bool: return a.shop_price < b.shop_price)
	for monster: MonsterData in for_sale:
		box.add_child(_echo_row(p, monster))
	if for_sale.is_empty():
		box.add_child(UiKit.wrapped(tr("SHOP_NO_ECHO"), 14, UiKit.MUTED))
	box.add_child(UiKit.title(tr("SHOP_SECTION_CONSUMABLES"), 20, MenuSkin.PAPER))
	for item: ShopItemData in Shop.items_of(Shop.CONSUMABLE):
		box.add_child(_item_row(p, item))
	box.add_child(UiKit.title(tr("SHOP_SECTION_SURVIVAL"), 20, MenuSkin.PAPER))
	for item: ShopItemData in Shop.items_of(Shop.SURVIVAL):
		box.add_child(_item_row(p, item))
	box.add_child(UiKit.title(tr("SHOP_SECTION_LOOKS"), 20, MenuSkin.PAPER))
	box.add_child(UiKit.wrapped(tr("SHOP_LOOKS_SOON"), 14, UiKit.MUTED))


func _row(accent: Color) -> Array:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", MenuSkin.frame(Color(0.06, 0.045, 0.1, 0.9), Color(accent, 0.5)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	row.add_child(h)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(texts)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	h.add_child(actions)
	return [row, h, texts, actions]


func _echo_row(p: ProfileData, monster: MonsterData) -> PanelContainer:
	var parts: Array = _row(monster.visual.primary.lightened(0.3))
	var h: HBoxContainer = parts[1]
	var portrait := EchoPortrait.new()
	portrait.setup(monster, [])
	portrait.custom_minimum_size = Vector2(72, 72)
	h.add_child(portrait)
	h.move_child(portrait, 0)
	var texts: VBoxContainer = parts[2]
	texts.add_child(UiKit.label(tr(monster.name_key), 19, UiKit.TEXT))
	texts.add_child(UiKit.wrapped(tr(monster.desc_key), 14, UiKit.MUTED))
	var buy: Button = UiKit.button(tr("SHOP_BUY") % monster.shop_price, _buy_echo.bind(monster.id), 240)
	buy.name = "BuyEcho_" + String(monster.id)
	buy.disabled = not EchoCollection.is_for_sale(p, monster) or not p.can_afford("shards", monster.shop_price)
	(parts[3] as VBoxContainer).add_child(buy)
	if not EchoCollection.is_for_sale(p, monster):
		texts.add_child(UiKit.label(tr("SHOP_LOCKED_AFTER") % _arena_name(monster.discovery_arena), 13, UiKit.DANGER))
	return parts[0]


func _item_row(p: ProfileData, item: ShopItemData) -> PanelContainer:
	var parts: Array = _row(item.color)
	var texts: VBoxContainer = parts[2]
	var actions: VBoxContainer = parts[3]
	var owned: bool = item.kind == Shop.SURVIVAL and Shop.owns(p, item.id)
	texts.add_child(UiKit.label(("✓ " if owned else "") + tr(item.name_key), 19, UiKit.GOLD if owned else UiKit.TEXT))
	texts.add_child(UiKit.wrapped(tr(item.desc_key), 14, UiKit.MUTED))
	if not Shop.is_available(p, item):
		texts.add_child(UiKit.label(tr("SHOP_LOCKED_AFTER") % _arena_name(item.requires_arena), 13, UiKit.DANGER))
	var buy: Button = UiKit.button(tr("SHOP_OWNED") if owned else tr("SHOP_BUY") % item.price, _buy.bind(item.id), 240)
	buy.name = "Buy_" + String(item.id)
	buy.disabled = not Shop.can_buy(p, item)
	actions.add_child(buy)
	if item.kind == Shop.CONSUMABLE:
		var stock: int = Shop.stock(p, item.id)
		texts.add_child(UiKit.label(tr("SHOP_STOCK") % stock, 13, UiKit.GOLD))
		var packed: bool = Shop.is_packed(p, item.id)
		var pack: Button = HunterTreeSkin.button(tr("SHOP_PACKED") if packed else tr("SHOP_PACK"), _pack.bind(item.id), packed)
		pack.name = "Pack_" + String(item.id)
		pack.disabled = stock <= 0 and not packed
		actions.add_child(pack)
	return parts[0]


func _arena_name(arena_id: StringName) -> String:
	var arena: ArenaData = GameDB.arena(arena_id)
	return tr(arena.name_key) if arena else tr("ECHO_SOURCE_LATER")


func _buy(id: StringName) -> void:
	if Shop.buy(profile(), GameDB.shop_items[id]):
		refuge.commit()


func _buy_echo(id: StringName) -> void:
	if Shop.buy_echo(profile(), GameDB.monster(id)):
		refuge.commit()


func _pack(id: StringName) -> void:
	Shop.toggle_packed(profile(), id)
	refuge.commit()
