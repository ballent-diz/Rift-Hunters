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

- **Campagne de survie** (lot 2) : un chapitre de 5 étapes sur les cartes existantes, des vagues à la suite, de plus
  en plus longues et dures ; choix « Campagne / Survie » au refuge ; progression, objectifs et records à part.
- **Carte bonus** débloquée à la fin de la campagne de survie : très grande, vagues infinies (score = vague
  atteinte).

## Boutique (lot 3)

Une seule boutique et une seule monnaie (les éclats, gagnés dans les deux modes), en onglets :
- Consommables (potion, relique de départ, relance d'un choix), utilisables dans les deux modes ;
- Survie (commencer au niveau 3, un choix de plus à la première montée de niveau…), débloqués en avançant dans la
  campagne de survie ;
- Apparences (plus tard, images de Codex).
