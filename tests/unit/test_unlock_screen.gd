extends TestCase
## Écran « Déblocages » de la version 3D (draft3d/unlock_screen.gd) branché sur un double de `DraftUnlocks`
## (tools/draft3d_fake_unlocks.gd, même API que docs/design/DEBLOCAGE_V2.md) : monnaie, achat d'un sort puis d'une
## variante, refus faute de sort, choix des sorts de départ, navigation, fermeture, gain en fin de partie, FR/EN.

var screen: DraftUnlockScreen
var unlocks: Object
var _locale: String


func before_each() -> void:
	_locale = Settings.locale
	Settings.set_locale("fr")
	unlocks = (load("res://tools/draft3d_fake_unlocks.gd") as GDScript).new()
	screen = DraftUnlockScreen.new()
	screen.setup(unlocks)
	host.add_child(screen)
	await host.get_tree().process_frame


func after_each() -> void:
	if screen != null:
		screen.free()
		screen = null
	Settings.set_locale(_locale)


func _button(id: String) -> Button:
	return screen.find_child(id, true, false) as Button


func test_shows_currency_and_every_entry() -> void:
	check_eq((screen.find_child("Currency", true, false) as Label).text, "Fragments de faille : 420")
	var entries: Array[Dictionary] = unlocks.call(&"entries")
	check(entries.size() > 10, "sorts et variantes listés")
	for entry: Dictionary in entries:
		check(screen.find_child("Row_" + str(entry["id"]), true, false) != null, "ligne : %s" % entry["id"])
		check(tr(str(entry["name_key"])) != str(entry["name_key"]), "%s : nom traduit" % entry["id"])
	check(DraftUnlockScreen.spell_icon(&"prismatic_lance") != null, "icône de la barre de sorts")


func test_buy_spell_then_variant() -> void:
	var variant: String = ""
	for entry: Dictionary in unlocks.call(&"entries"):
		if entry["kind"] == "variant" and entry["spell_id"] == &"rupture":
			variant = str(entry["id"])
			break
	check(variant != "", "la Rupture a des variantes")
	check(_button("Buy_" + variant).disabled, "variante verrouillée tant que le sort ne l'est pas")
	check_eq(_button("Buy_" + variant).text, "Sort requis")
	_button("Buy_rupture").pressed.emit()
	await host.get_tree().process_frame
	check_eq(int(unlocks.call(&"currency")), 270, "150 Fragments dépensés")
	check(_button("Start_rupture") != null, "le sort débloqué peut être pris au départ")
	check(_button("Start_rupture").has_focus(), "le focus reste sur la ligne achetée (clavier, manette)")
	check(not _button("Buy_" + variant).disabled, "variante disponible")
	_button("Buy_" + variant).pressed.emit()
	await host.get_tree().process_frame
	check_eq(int(unlocks.call(&"currency")), 190, "80 Fragments dépensés")
	check(_button("Buy_" + variant) == null, "variante débloquée")


func test_too_expensive_is_disabled() -> void:
	unlocks.set(&"fragments", 100)
	screen.refresh()
	await host.get_tree().process_frame
	check(_button("Buy_rupture").disabled, "150 > 100 : achat impossible")


func test_choose_starting_spells() -> void:
	check(_button("Start_cleaving_slash").button_pressed and _button("Start_prismatic_lance").button_pressed,
		"départ par défaut")
	_button("Buy_rupture").pressed.emit()
	await host.get_tree().process_frame
	_button("Start_rupture").pressed.emit()
	await host.get_tree().process_frame
	check_eq(unlocks.call(&"starting_spells"), [&"prismatic_lance", &"rupture"] as Array[StringName],
		"le nouveau sort remplace le plus ancien")
	check(not _button("Start_cleaving_slash").button_pressed, "Taille fendante n'est plus au départ")
	check((screen.find_child("Starting", true, false) as Label).text.contains("Rupture"), "rappel des sorts de départ")


func test_navigation_and_close() -> void:
	await host.get_tree().process_frame
	var focused: Control = host.get_viewport().gui_get_focus_owner()
	check(focused != null and focused != screen.back_button, "le premier bouton de la liste a le focus")
	check(not focused.focus_neighbor_bottom.is_empty(), "bas : élément suivant")
	var closed: Array[bool] = []
	screen.closed.connect(func() -> void: closed.append(true))
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	host.get_viewport().push_input(event)
	await host.get_tree().process_frame
	check_eq(closed, [true] as Array[bool], "Échap / B ferme l'écran")


func test_without_unlocks_system() -> void:
	var empty := DraftUnlockScreen.new()
	host.add_child(empty)
	await host.get_tree().process_frame
	check(empty.find_child("List", true, false).get_child_count() == 1, "message d'attente")
	empty.free()


func test_end_screen_shows_gain_in_both_languages() -> void:
	var hud := DraftHud.new()
	host.add_child(hud)
	hud.show_end(true, "", 87)
	check_eq((hud.find_child("Gain", true, false) as Label).text, "+ 87 Fragments de faille")
	hud.free()
	Settings.set_locale("en")
	hud = DraftHud.new()
	host.add_child(hud)
	hud.show_end(false, "", 0)
	check_eq((hud.find_child("Gain", true, false) as Label).text, "+ 0 Rift Fragments")
	hud.free()
