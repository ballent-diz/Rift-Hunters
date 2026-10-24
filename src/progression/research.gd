class_name Research
extends RefCounted
## Laboratoire : recherches payées en Essence qui débloquent du contenu.

static func is_done(profile: ProfileData, id: StringName) -> bool:
	return (profile.data["research"] as Array).has(String(id))


static func can_research(profile: ProfileData, item: ResearchData) -> bool:
	if is_done(profile, item.id) or not profile.can_afford("essence", item.cost_essence):
		return false
	for prereq: StringName in item.prerequisites:
		if not is_done(profile, prereq):
			return false
	return true


static func prerequisites_met(profile: ProfileData, item: ResearchData) -> bool:
	for prereq: StringName in item.prerequisites:
		if not is_done(profile, prereq):
			return false
	return true


static func perform(profile: ProfileData, item: ResearchData) -> bool:
	if not can_research(profile, item):
		return false
	profile.add_currency("essence", -item.cost_essence)
	(profile.data["research"] as Array).append(String(item.id))
	for entry: String in item.unlocks:
		profile.unlock(entry)
	return true


static func sorted() -> Array[ResearchData]:
	var list: Array[ResearchData] = []
	for id: StringName in GameDB.research:
		if GameDB.balance.feature_enabled((GameDB.research[id] as ResearchData).feature):
			list.append(GameDB.research[id])
	list.sort_custom(func(a: ResearchData, b: ResearchData) -> bool: return a.order < b.order)
	return list
