# Deux modes de jeu : campagne et survie

Décisions du propriétaire (21 octobre 2026).

## Constat

Les montées de niveau à la survivor (XP, trois cartes au choix à chaque niveau, une quinzaine par partie) faisaient
double emploi avec l'arbre du Chasseur et les arbres des Échos, et tout repartait de zéro à chaque carte. Elles
deviennent un **mode à part**, le mode survie ; la campagne principale progresse autrement.

## Règle commune : la puissance vient des jalons, pas du farm

- Arbre du Chasseur : apprendre avec des éclats, activer avec des Points de Chasseur gagnés aux **jalons** (première
  victoire d'une carte, objectifs). Arbres des Échos : points donnés par la maîtrise.
- Pas de niveau permanent du Chasseur à l'XP (un compteur qu'on remplit de toute façon n'apporte aucun choix).
- Équipement (plus tard) : des choix avec contrepartie, plafonnés par chapitre et obtenus aux jalons ; jamais des
  « +20 % » qui s'empilent.

## Campagne principale : choix aux jalons

Réglage `ArenaData.progression = &"milestones"` (cartes du chapitre 1).

- **Pas d'XP** : les Corrompus n'en laissent plus ; la barre d'XP disparaît du HUD (« Jalons : n »).
- **Un choix à chaque jalon** : fin de vague (mode zones), faille fermée (mode failles), vague d'autel tenue ; sur
  les cartes à peu de jalons (`milestone_on_elite`), une élite tuée en est un aussi. Environ 5 à 10 par carte.
- **Contenu des choix** : mutations, recruter / renforcer / faire évoluer un Écho, **reliques** ; plus de petites
  caractéristiques (+10 % de dégâts…), déjà données par l'arbre du Chasseur.
- **Jalon renforcé** : chaque jalon soigne (`milestone_heal_ratio`, 30 %) et donne des dégâts acquis jusqu'à la fin
  de la partie (`milestone_damage_pct`, +6 %), dans `data/balance/balance_config.tres`.
- Bot (bonus d'arbre « veteran », Mousseroc et Cendrelame) : Ruines et Bois 11 sur 11, Gué 4 sur 4, Hautes Terres
  7 sur 8 — comme avant le changement (7 sur 7, 4 sur 4, 3 sur 4).

## Mode survie : montées de niveau d'origine

Réglage `ArenaData.progression = &"levels"` (par défaut) : XP, niveaux, trois cartes au choix, réserve de choix ;
on refait un build complet à chaque partie.

- **Épreuves de survie** (lot M2, `data/chapters/survival_trials.tres`, `ChapterData.track = &"survival"`) : une
  piste à part, qui se débloque carte après carte sans toucher à la campagne principale. Refuge → Expédition :
  boutons « Campagne / Survie ».

  | Étape | Carte (décor) | Boss | Arrivée | Force des Corrompus | Famille |
  |---|---|---|---|---|---|
  | 1 | Plaine fracturée | Nébulorax | 7 min | ×1 | violette |
  | 2 | Épreuve des Ruines | Sentinelle des Racines | 7 min 30 | PV ×1,1 | violette |
  | 3 | Épreuve des Hautes Terres | Astravorn | 8 min | PV ×1,2, dégâts ×1,05 | violette |
  | 4 | Épreuve du Bois (nuit) | Chimère des Brumes | 8 min 30 | PV ×0,8, dégâts ×0,75 | Hautes Terres |
  | 5 | Épreuve du Gué (gués) | Nébulorax | 9 min | PV ×0,9, dégâts ×0,8 | Hautes Terres |

  Toute la carte est ouverte (ni zones ni barrières) ; `ArenaData.enemy_hp_mult` / `enemy_damage_mult` règlent la
  force par carte. La famille des Hautes Terres est bien plus forte de base (PV ×2, dégâts ×1,5 pour le monstre de
  base) : ses deux épreuves sont compensées sous ×1 ; la difficulté monte par la famille, la nuit, les gués et la
  durée. Bot (bonus d'arbre « veteran ») : Plaine 2/4, Ruines 3/4, Hautes Terres 2/4, Bois 5/6, Gué 4/6 ; Faille
  sans fin : vague 7 vers 6 min. Objectifs : terminer, peu de dégâts, élites. Première victoire : éclats et Point de Chasseur, comme
  en campagne.
- **Faille sans fin** (carte bonus, `endless_rift`), ouverte en finissant les cinq épreuves : décor des Hautes Terres
  (le plus grand, 5016 × 5016, en attendant une carte géante dessinée), familles mêlées, **pas de boss** ; une vague
  par minute (`endless_wave_duration`), +12 % d'apparitions par vague (`endless_spawn_growth`) en plus de la
  croissance normale des PV. Score = vague atteinte, record au profil (`records.endless_best_wave`), affiché en jeu.

## Boutique (lot M3, réalisé le 21 octobre 2026)

Refuge → onglet Boutique (`src/ui/refuge/shop_tab.gd`, règles dans `src/progression/shop.gd`, objets dans
`data/shop/*.tres`, état dans `profile.data["shop"]`) :
- **Échos en vente** (MonsterData `discovery = &"shop"`, docs/design/COLLECTION_ECHOS.md), triés par prix ;
- **consommables** (stock ; « Emporter » : une unité consommée à chaque départ tant qu'il en reste) : Fiole de
  vigueur (PV max +30 %, 120), Pierre de relance (+2 relances, 90), Coffret de relique (relique au départ, 220, après
  les Hautes Terres) ; le résumé de l'Expédition affiche ce qui est emporté ;
- **avantages des épreuves de survie** (acquis une fois, actifs seulement sur les cartes à montées de niveau) :
  Entraînement de survie (niveau 2 au départ, 400, après la Plaine), Aimant de faille (ramassage +40 %, 600, après
  l'Épreuve des Ruines), Instinct du survivant (une carte de plus à chaque niveau, 900, après l'Épreuve des Hautes
  Terres) ;
- **apparences** : à venir (images de Codex).

### Proposition d'origine

Une seule boutique et une seule monnaie (les éclats, gagnés dans les deux modes), en onglets :
- Consommables (potion, relique de départ, relance d'un choix), utilisables dans les deux modes ;
- Survie (commencer au niveau 3, un choix de plus à la première montée de niveau…), débloqués en avançant dans la
  campagne de survie ;
- Apparences (plus tard, images de Codex).
