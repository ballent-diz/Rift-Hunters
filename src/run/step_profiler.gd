class_name StepProfiler
extends RefCounted
## Chronomètre de chaque système de la boucle de jeu, pour trouver ce qui coûte quand l'écran est chargé.
## Outil de mesure seulement : branché par l'autoplay (--perf), jamais actif en jeu normal.

const HITCH_MS := 30.0

var totals: Dictionary = {}
var peaks: Dictionary = {}
var frames: int = 0
## À-coups : système, instant de la partie et durée (ms) de chaque pas au-delà de HITCH_MS.
var hitches: PackedStringArray = []
var _last: int = 0
var _time: float = 0.0


func begin(time: float) -> void:
	frames += 1
	_time = time
	_last = Time.get_ticks_usec()


func mark(section: StringName) -> void:
	var now: int = Time.get_ticks_usec()
	var cost: int = now - _last
	totals[section] = int(totals.get(section, 0)) + cost
	peaks[section] = maxi(int(peaks.get(section, 0)), cost)
	if cost / 1000.0 > HITCH_MS:
		hitches.append("%s %.0f ms à t=%.1fs" % [section, cost / 1000.0, _time])
	_last = now


## Moyenne et pic par système (ms par pas de simulation), du plus coûteux au moins coûteux, puis remise à zéro.
func report() -> String:
	if frames == 0:
		return ""
	var sections: Array = totals.keys()
	sections.sort_custom(func(a: StringName, b: StringName) -> bool: return int(totals[a]) > int(totals[b]))
	var total: float = 0.0
	var parts: PackedStringArray = []
	for section: StringName in sections:
		var avg: float = float(totals[section]) / frames / 1000.0
		total += avg
		if avg >= 0.05:
			parts.append("%s %.2f (pic %.1f)" % [section, avg, int(peaks[section]) / 1000.0])
	var line: String = "simulation %.2f ms/pas : %s" % [total, " · ".join(parts)]
	if not hitches.is_empty():
		line += "\n    à-coups : " + ", ".join(hitches)
		hitches.clear()
	totals.clear()
	peaks.clear()
	frames = 0
	return line
