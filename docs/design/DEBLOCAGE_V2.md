# Déblocage des sorts entre les parties (version 3D)

Décision du propriétaire du 15 novembre 2026, **direction C (mixte)** :
- **entre les parties**, un **écran de déblocage simple** (pas l'arbre v1 : ni apprendre/activer, ni points, ni
  paliers) dépense **une seule monnaie, nouvelle**, pour débloquer ce qui **peut apparaître** en partie, et choisir
  les **2 sorts de départ** parmi les sorts débloqués ;
- **en partie**, rien ne change : les choix de niveau proposent nouveaux sorts, variantes et rangs, **tirés
  seulement parmi le contenu débloqué** ;
- **passifs** : laissés de côté pour l'instant ;
- l'arbre v1 ne s'applique plus à la v2 une fois ce système en place (il reste à la campagne 2D archivée).

Répartition : **session « Gameplay »** = monnaie, règles de déblocage, sauvegarde, filtre des cartes, sorts de départ
(code dans `draft3d/`, sans interface). **Session « Interface »** = l'écran de déblocage, le choix des sorts de
départ et l'affichage de la monnaie (menu principal, fin de partie), en lisant l'API ci-dessous.

## Monnaie

Nom proposé, **à valider** : **Fragments de faille** (EN *Rift Fragments*), clés `CURRENCY3D_NAME` / `_DESC`.
Gains indicatifs, réglables dans `draft3d/tuning.tres` : 0,1 par Corrompu tué, 6 par minute tenue, 25 pour un
gardien, 60 pour le Dévoreur ; gardés en cas de défaite comme de victoire. Ordre de grandeur : 60 à 120 par partie.

## Ce qui se débloque

| Contenu | Coût indicatif | Condition | Effet en partie |
|---|---|---|---|
| Taille fendante, Lance prismatique | offerts | — | sorts de départ par défaut |
| Chacun des 13 autres sorts | 150 | — | sa carte « Nouveau sort » peut sortir au choix de niveau |
| Chaque variante (2 par sort) | 80 | sort débloqué | sa carte de variante peut sortir |
| Rangs | — | sort débloqué | toujours dans le tirage, rien à acheter |

Choix des **2 sorts de départ** : parmi les sorts débloqués, gratuit et modifiable à chaque partie. Total pour tout
débloquer ≈ 13 × 150 + 30 × 80 = 4 350 Fragments, soit ≈ 40 à 60 parties.

## API fournie par la session « Gameplay » (classe `DraftUnlocks`, `draft3d/unlocks.gd`)

| Appel | Rôle |
|---|---|
| `DraftUnlocks.load()` → `DraftUnlocks` | état sauvegardé (`user://draft3d_progress.json`, avec les chapitres vaincus) |
| `currency() -> int` | Fragments disponibles |
| `entries() -> Array[Dictionary]` | ce qui se débloque : `{id, kind: "spell"/"variant", spell_id, name_key, desc_key, cost, unlocked, available}` (`available` : conditions remplies) |
| `unlock(id) -> bool` | dépense et débloque ; faux si trop cher, déjà fait ou condition manquante |
| `starting_spells() -> Array[StringName]` / `set_starting_spells(ids) -> bool` | les 2 sorts de départ (parmi les débloqués) |
| `last_gain() -> int` | Fragments gagnés à la dernière partie (écran de fin) |
| signal `changed` | après un déblocage ou un changement de départ |

## Attendu de la session « Interface »

- Entrée **« Déblocages »** dans le menu principal v2 (`draft3d/menu.gd`), à côté de Jouer / Options.
- Écran simple : monnaie en haut ; une ligne ou une carte par sort (icône de la barre de sorts, nom, coût, état),
  ses deux variantes dessous ; achat au clic, au clavier ou à la manette ; textes FR/EN.
- Choix des **2 sorts de départ** sur le même écran (ou juste avant Jouer).
- Écran de fin de partie : « + N Fragments de faille ».
- Aucune règle de jeu dans l'interface : tout passe par `DraftUnlocks`.
