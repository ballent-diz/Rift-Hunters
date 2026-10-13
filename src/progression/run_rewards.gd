class_name RunRewards
extends RefCounted
## Calcul pur des récompenses de fin de partie (testable).

static func compute(result: Dictionary, balance: BalanceConfig) -> Dictionary:
	var counters: Dictionary = result.get("stats", {}).get("counters", {})
	var victory: bool = result.get("victory", false)
	var minutes: float = float(result.get("time", 0.0)) / 60.0
	var mult: float = float(result.get("reward_mult", 1.0))
	var raw_shards: float = float(counters.get("shards_earned_raw", 0.0)) + minutes * balance.shards_per_minute
	if victory:
		raw_shards += float(result.get("boss_shards", 0))
	var shards: int = int(round(raw_shards * float(result.get("shard_gain", 1.0)) * mult))
	var raw_essence: float = float(counters.get("essence_earned_raw", 0.0))
	if victory:
		raw_essence += float(result.get("boss_essence", 0))
	var essence: int = int(round(raw_essence * mult))
	return {"shards": shards, "essence": essence, "lines": []}
