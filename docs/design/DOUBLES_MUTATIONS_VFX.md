# Rendu des doubles mutations des sorts historiques (v2)

Les neuf sorts historiques (`draft3d/spells.gd`) acceptent deux mutations compatibles. Leurs animations peintes de la
v1 (`assets/vfx/hunter/spell_vfx.gd`, `cleaving_slash.gd`, `prismatic_lance.gd`) ne dessinent **qu'une variante par
scène**. Avant ce correctif, `DraftSpells.variant_of` prenait la **première mutation obtenue** : selon l'ordre
d'acquisition, la seconde disparaissait à l'écran.

## Règle retenue

- **Une variante peinte par sort, choisie par priorité et non par ordre d'obtention** :
  `DraftSpellVfx.PAINTED_PRIORITY` et `DraftSpellVfx.painted_variant`. La priorité va à la mutation qui n'a **aucun
  autre rendu**.
- **L'autre mutation passe par une couche ou un effet événementiel** déjà présent dans le jeu (planches PixelFX
  existantes, aucune nouvelle ressource).
- Les scènes de la v1 ne sont pas modifiées. Les dégâts, PV, recharges, zones de touche et incompatibilités ne
  changent pas.
- Zéro mutation : version de base. Une mutation : sa variante, comme avant, sauf pour Horizon, Prisme double et
  Garde longue (voir les correctifs annexes).

## Audit : 9 sorts, 18 mutations

| Sort | Mutations | Avant (deuxième mutation) | Après | État |
|---|---|---|---|---|
| Taille fendante | Tourbillon / Estoc | Incompatibles : une seule à la fois | Inchangé (remplacement explicite) | déjà fonctionnel |
| Lance prismatique | Éventail / Surcharge | Incompatibles : une seule à la fois | Inchangé (remplacement explicite) | déjà fonctionnel |
| Rupture | Brasier + Réaction | Réaction obtenue d'abord : **pas de flammes**. Le repli `fire_ring` est coupé quand la scène existe, donc la zone de brasier était invisible | Brasier peint (`inferno`) ; Réaction rendue par les détonations de rebond (une animation par rebond, indépendante) | **corrigé** |
| Bond de faille | Impact + Retour | Retour obtenu d'abord : onde d'atterrissage de taille normale (75 au lieu de 150), alors que la zone ralentit plus large | Impact peint ; Retour : **portail au point de départ** (`portal`, riftborn) pendant toute la fenêtre de retour, retiré au retour ou à la fin de la fenêtre | **corrigé** |
| Parade | Garde longue + Miroir | Garde longue obtenue d'abord : **pas de trait renvoyé** à la parade | Miroir peint ; Garde longue n'a pas de dessin propre (fenêtre plus longue) | **corrigé** |
| Singularité | Effondrement + Horizon | Horizon obtenu d'abord : rotation rapide de l'Effondrement absente, et dessin agrandi deux fois (1,96×, rogné par la vue) | Effondrement peint ; Horizon rendu par le vrai rayon passé à la scène | **corrigé** |
| Mur de faille | Rempart ardent + Chaînes | Chaînes obtenues d'abord : **pas de flammes**. Le dessin peint des chaînes demande des cibles que la v2 ne fournit pas : rien même avec les Chaînes seules | Rempart ardent peint (`burning_wall`) ; Chaînes : **entrave `root_snare`** (enlisés) sur chaque ennemi nouvellement immobilisé | **corrigé** |
| Égide de faille | Second souffle + Riposte | Riposte obtenue d'abord : bouclier réduit du Second souffle non montré, soin invisible | Second souffle peint (`sharing`) + **`healing_bloom`** au soin ; Riposte : onde `ring_burst` à la rupture du bouclier (indépendante, déjà en place) | **corrigé** |
| Cristal réfracteur | Prisme double + Foyer | Les deux mutations se voient (deux cristaux posés, éclats de Foyer dirigés), mais avec Prisme double chaque animation dessinait aussi un **cristal fantôme** : 4 cristaux à l'écran pour 2 réels | Priorité fixée (Foyer) pour un rendu stable ; Prisme double joue la base sur chaque cristal réel : 2 cristaux à l'écran | **corrigé** (cristaux fantômes) |

## Correctifs annexes, une seule mutation

- **Horizon seule** : la scène reçoit déjà le rayon agrandi (`area_of`). La variante peinte `horizon` le
  multipliait une seconde fois (×1,4), au-delà de la zone réelle et hors de la vue, donc rognée. Elle joue
  maintenant la base, à la taille réelle.
- **Prisme double seule** : chaque cristal a sa propre animation. La variante `double_prism` ajoutait à chacune un
  second cristal décalé, sans réalité en jeu (4 cristaux affichés pour 2). Elle joue maintenant la base.
- **Retour seul** : le portail de repère s'ajoute au dessin peint du Retour, qui ne dure que l'animation du saut.
- **Chaînes seules** : l'entrave `root_snare` rend enfin la mutation visible.
- **Second souffle seul** : `healing_bloom` au soin.

## Ressources manquantes

Aucune ressource n'est nécessaire pour rendre les deux mutations perceptibles. Améliorations possibles, non
demandées, à commander si le propriétaire le souhaite :

| Besoin | Où | Remarque |
|---|---|---|
| Chaînes dessinées sur le mur peint | `spell_vfx.gd` (`_wall`, `secondary_offsets`) | Il faudrait transmettre les positions des ennemis entravés **et** dessiner chaînes et flammes dans la même scène, donc modifier la scène v1 (archivée, non modifiée ici) |
| Garde longue visible | scène `parry` | L'animation peinte dure 0,70 s quelle que soit la fenêtre ; un dessin de garde prolongée demanderait une variante peinte |
| Riposte peinte | scène `rift_aegis` (`trigger_pulse`) | La v2 joue `ring_burst` à la rupture ; la vague peinte de la Riposte exigerait la variante `riposte` sur l'animation, en concurrence avec `sharing` |

## Vérification

- Test : `tests/unit/test_draft3d_double_mutations_vfx.gd` (zéro, une ou deux mutations, ordre inversé,
  incompatibilités refusées, remplacement, passage en réserve puis rééquipement, couches événementielles).
- Captures : `tools/double_mutation_showcase.tscn` → `docs/previews/doubles_mutations/`. La planche
  `comparaison.png` montre, par ligne, `main` (B puis A), ce correctif (B puis A), A seule et B seule ;
  `rapport_main.txt` et `rapport_correctif.txt` indiquent la variante transmise à chaque scène peinte.
