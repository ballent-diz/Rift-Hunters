class_name DraftBossTest
extends RefCounted
## Raccourcis de test pour vérifier un combat de boss (demande du propriétaire, 17 novembre 2026) :
## - touche F9 ou bouton « Aller au boss (test) » de la pause : la vague en cours est retirée et le boss de la carte
##   arrive tout de suite (sommet de la tour compris) ;
## - `--boss-test --chapter=N [--boss-level=15]` : la partie démarre directement sur le boss du chapitre, avec un
##   Chasseur monté de niveaux (améliorations tirées comme au choix de niveau).
## Réservé aux versions de développement (`OS.is_debug_build`) : invisible dans une version exportée. Une partie où le
## raccourci a servi ne compte pas : ni victoire de chapitre ni gain de Fragments enregistrés (`DraftRun.test_run`).


static func enabled() -> bool:
	return OS.is_debug_build()


## « Aller au boss » : vague retirée, gardien sauté, boss tout de suite. Sans effet si le boss est déjà là.
static func skip_to_boss(run: DraftRun) -> void:
	if run.state != DraftRun.State.PLAYING or run._boss_spawned:
		return
	run.test_run = true
	run._guardian_spawned = true
	run._swarm_at = INF
	run.enemies.clear_all()
	run.hazards.clear()
	if run.tower != null:
		while not run.tower.summit():
			await run.tower.climb()
		run.tower.arrived_at = run.time - run.tuning.tower_boss_delay
	run.boss_time = run.time
	run.hud.banner(run.tr("DRAFT_TEST_BOSS"), 3.0)


## Chasseur monté de `levels` niveaux ; les mutations qui demandent de choisir un emplacement sont laissées de côté.
static func prepare_hunter(run: DraftRun, levels: int) -> void:
	for i: int in levels:
		# Quelques tirages au besoin : un tirage peut n'offrir que des mutations à emplacement.
		var applied: bool = false
		for attempt: int in 8:
			for card: UpgradeData in run.upgrades.roll(run.rng, run.balance.upgrade_choices):
				var mutation := card.effects[0] as DraftSpellEffect if not card.effects.is_empty() else null
				if (mutation == null or mutation.kind != DraftSpellEffect.Kind.VARIANT) \
						and run.upgrades.apply(card, run.hunter.stats):
					applied = true
					break
			if applied:
				break
		if not applied:
			break
		run.hunter.level += 1
	run.hunter.heal(run.hunter.max_hp())
	run.hud.show_build(run.upgrades)
