class_name PlatformServices
extends RefCounted
## Services de plateforme (succès, statistiques). Par défaut : aucun service externe (le jeu fonctionne hors ligne).
## Pour Steam : fournir un backend (ex. via GodotSteam) qui implémente unlock_achievement / set_stat.
## Chaque objectif du jeu correspond à un succès du même identifiant (voir docs/STEAM.md).

static var backend: Object = null
static var unlocked_this_session: PackedStringArray = []


static func unlock_achievement(id: String) -> void:
	unlocked_this_session.append(id)
	if backend and backend.has_method("unlock_achievement"):
		backend.call("unlock_achievement", id)


static func set_stat(stat_name: String, value: float) -> void:
	if backend and backend.has_method("set_stat"):
		backend.call("set_stat", stat_name, value)
