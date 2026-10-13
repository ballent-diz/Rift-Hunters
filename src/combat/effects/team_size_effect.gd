class_name TeamSizeEffect
extends GameplayEffect
## Modificateurs du Chasseur qui dépendent de la taille de l'équipe.
## per_ally = true : appliqués une fois par Écho. Sinon : appliqués si min_team <= taille <= max_team.

@export var per_ally: bool = false
@export var min_team: int = 0
@export var max_team: int = 99
@export var stats: Array[StringName] = []
@export var flats: Array[float] = []
@export var pcts: Array[float] = []


func install(ctx: RunContext, _owner_id: StringName) -> void:
	var applied: Array[int] = [0]
	var refresh := func() -> void:
		var size: int = ctx.allies.team_size()
		var wanted: int = size if per_ally else (1 if size >= min_team and size <= max_team else 0)
		var diff: int = wanted - applied[0]
		if diff == 0:
			return
		for i: int in stats.size():
			var flat: float = flats[i] if i < flats.size() else 0.0
			var pct: float = pcts[i] if i < pcts.size() else 0.0
			ctx.player.stats.add_modifier(stats[i], flat * diff, pct * diff)
		applied[0] = wanted
	ctx.events.team_changed.connect(refresh)
	refresh.call()
