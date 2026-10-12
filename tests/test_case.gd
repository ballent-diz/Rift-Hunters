class_name TestCase
extends RefCounted
## Base des tests unitaires : chaque méthode test_* est exécutée par le lanceur.

## Nœud hôte dans l'arbre (pour instancier des scènes).
var host: Node
var failures: PackedStringArray = []
var current_test: String = ""


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s : %s" % [current_test, message])


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%s : %s (obtenu %s, attendu %s)" % [current_test, message, str(actual), str(expected)])


func check_near(actual: float, expected: float, tolerance: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s : %s (obtenu %.4f, attendu %.4f)" % [current_test, message, actual, expected])
