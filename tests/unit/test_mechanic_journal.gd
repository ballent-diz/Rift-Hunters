extends TestCase
## Journal des mécaniques (MechanicJournal) : fiche à la première rencontre, simple rappel ensuite, relecture au
## refuge ; bandeaux d'annonce qui restent dans l'écran.

var run: RunController
var _original: ProfileData


func before_each() -> void:
	_original = Profile.profile
	Profile.profile = ProfileData.new()


func after_each() -> void:
	if run:
		RunFixture.dispose(run)
		run = null
	Profile.profile = _original


func test_every_entry_has_texts() -> void:
	for key: String in MechanicJournal.ENTRIES:
		check(tr(key) != key, "%s : explication traduite" % key)
		check(tr(MechanicJournal.title_key(key)) != MechanicJournal.title_key(key), "%s : titre traduit" % key)


func test_first_encounter_shows_a_card_then_a_reminder() -> void:
	run = RunFixture.create(host, &"ashblade")
	var hud: Hud = run.hud
	run.ctx.events.event_started.emit("MUD_INTRO")
	check_eq(hud._card_key, "MUD_INTRO", "première rencontre : la fiche s'affiche")
	check(MechanicJournal.has_seen(Profile.profile, "MUD_INTRO"), "notée au Journal")
	hud._card_time = 0.0
	run.ctx.events.event_started.emit("MUD_INTRO")
	check_eq(hud._card_time, 0.0, "ensuite, pas de nouvelle fiche")
	check(hud._banner_time > 0.0, "mais un rappel en bandeau")
	run.ctx.events.event_started.emit("FINALE_CLEAR")
	check_eq(MechanicJournal.seen(Profile.profile).size(), 1, "une annonce qui n'est pas une mécanique n'y entre pas")


## Retour de test : les objectifs en bandeau restent le temps d'être lus et ne s'effacent plus l'un l'autre.
func test_banners_stay_readable_and_queue() -> void:
	run = RunFixture.create(host, &"ashblade")
	var hud: Hud = run.hud
	hud._banner_time = 0.0
	hud._banner_queue.clear()
	hud.banner("Premier objectif à lire tranquillement")
	check(hud._banner_time >= Hud.BANNER_MIN, "au moins %.1f s à l'écran" % Hud.BANNER_MIN)
	hud.banner("Second objectif")
	check_eq(hud._banner_text, "Premier objectif à lire tranquillement", "le premier reste affiché")
	check_eq(hud._banner_queue.size(), 1, "le second attend son tour")
	hud._process(Hud.BANNER_MAX + 0.1)
	check_eq(hud._banner_text, "Second objectif", "puis le second s'affiche")


func test_card_text_does_not_repeat_the_title() -> void:
	var body: String = MechanicJournal.body("BOSS_MIRROR_INTRO")
	check(not body.begins_with(tr("JOURNAL_MIRROR")), "le titre n'est pas répété")
	check(body.length() > 10, "l'explication reste")
