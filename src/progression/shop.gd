class_name Shop
extends RefCounted
## Boutique du refuge (lot M3) : achats en éclats, stock des consommables, objets emportés, Échos en vente.
## État dans profile.data["shop"] : {"stock": {id: n}, "owned": [ids], "packed": [ids]}.

const CONSUMABLE := &"consumable"
const SURVIVAL := &"survival"
const LOOK := &"look"


static func items_of(kind: StringName) -> Array[ShopItemData]:
	var list: Array[ShopItemData] = []
	for id: StringName in GameDB.sorted_ids(GameDB.shop_items):
		var item: ShopItemData = GameDB.shop_items[id]
		if item.kind == kind and GameDB.balance.feature_enabled(item.feature):
			list.append(item)
	list.sort_custom(func(a: ShopItemData, b: ShopItemData) -> bool: return a.order < b.order)
	return list


static func _state(profile: ProfileData) -> Dictionary:
	return profile.data["shop"]


static func is_available(profile: ProfileData, item: ShopItemData) -> bool:
	return item.requires_arena == &"" or Campaign.wins(profile, item.requires_arena) > 0


static func stock(profile: ProfileData, id: StringName) -> int:
	return int((_state(profile)["stock"] as Dictionary).get(String(id), 0))


static func owns(profile: ProfileData, id: StringName) -> bool:
	return (_state(profile)["owned"] as Array).has(String(id))


static func can_buy(profile: ProfileData, item: ShopItemData) -> bool:
	if not is_available(profile, item) or not profile.can_afford("shards", item.price):
		return false
	return item.kind == CONSUMABLE or not owns(profile, item.id)


static func buy(profile: ProfileData, item: ShopItemData) -> bool:
	if not can_buy(profile, item):
		return false
	profile.add_currency("shards", -item.price)
	var state: Dictionary = _state(profile)
	if item.kind == CONSUMABLE:
		state["stock"][String(item.id)] = stock(profile, item.id) + 1
	else:
		(state["owned"] as Array).append(String(item.id))
	return true


static func buy_echo(profile: ProfileData, monster: MonsterData) -> bool:
	if not EchoCollection.is_for_sale(profile, monster) or not profile.can_afford("shards", monster.shop_price):
		return false
	profile.add_currency("shards", -monster.shop_price)
	profile.unlock("monster:" + String(monster.id))
	profile.discover("monsters", String(monster.id))
	return true


static func is_packed(profile: ProfileData, id: StringName) -> bool:
	return (_state(profile)["packed"] as Array).has(String(id))


## Emporter (ou non) un consommable à la prochaine expédition.
static func toggle_packed(profile: ProfileData, id: StringName) -> void:
	var packed: Array = _state(profile)["packed"]
	if packed.has(String(id)):
		packed.erase(String(id))
	elif stock(profile, id) > 0:
		packed.append(String(id))


## Départ d'une expédition : consomme une unité de chaque consommable emporté et ajoute les objets de survie acquis
## (seulement sur une carte à montées de niveau). Retourne {"effects": Array[GameplayEffect], "start_levels": int,
## "items": Array[StringName]}.
static func prepare_run(profile: ProfileData, arena: ArenaData) -> Dictionary:
	var effects: Array[GameplayEffect] = []
	var items: Array[StringName] = []
	var start_levels: int = 0
	var state: Dictionary = _state(profile)
	var survival: bool = arena != null and arena.progression == &"levels"
	for raw: Variant in (state["packed"] as Array).duplicate():
		var item: ShopItemData = GameDB.shop_items.get(StringName(str(raw)))
		if item == null or stock(profile, item.id) <= 0:
			(state["packed"] as Array).erase(raw)
			continue
		if item.survival_only and not survival:
			continue
		state["stock"][String(item.id)] = stock(profile, item.id) - 1
		if stock(profile, item.id) <= 0:
			(state["packed"] as Array).erase(raw)
		effects.append_array(item.effects)
		items.append(item.id)
	if survival:
		for item: ShopItemData in items_of(SURVIVAL):
			if owns(profile, item.id):
				effects.append_array(item.effects)
				start_levels += item.start_levels
				items.append(item.id)
	return {"effects": effects, "start_levels": start_levels, "items": items}
