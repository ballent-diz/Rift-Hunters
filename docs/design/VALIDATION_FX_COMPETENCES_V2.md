# Validation visuelle du système de compétences v2 — 18 novembre 2026

Validation finale après la livraison Codex des huit FX de mutations (PR #227). Fiches de référence :
`docs/design/FICHES_VFX_MUTATIONS_V2.md`. Outil de contrôle en partie réelle : `tools/mutation_fx_showcase.tscn`.

```bash
# captures + mesures des 8 FX (largeur, ancrage, priorité, sol, suivi, disparition)
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --fixed-fps 60 --resolution 1280x720 \
  res://tools/mutation_fx_showcase.tscn -- --bot --passive --out=docs/previews/mutations_v2/en_jeu
# balayage des 15 sorts (sans mutation, chaque mutation, les deux) : lancers et effets restants après expiration
godot --headless --fixed-fps 60 --path . res://tools/mutation_fx_showcase.tscn -- --bot --passive --sweep
```

`--fixed-fps 60` est indispensable aux captures : sans lui, le rendu logiciel lent fait avancer les animations
(horloge de `_process`) bien plus vite que les images de physique, et les effets brefs sont finis avant la capture.

## 1. Ressources (8 planches)

Contrôle : `tools/art/check_v2_vfx.py` (8 « livré ») et mesure des planches contre les fiches.

| FX | Image | Images · fps · boucle | Transparence | Rouge/orange ennemi | Fiche |
|---|---|---|---|---|---|
| `mutation_mark_execute` | 140 px | 12 · 24 · non | coins à 0, aucune image vide | aucun | conforme |
| `mutation_mark_hunt` | 104 px | 8 · 20 · non | idem | aucun | conforme |
| `mutation_rend_pierce` | 104 px | 6 · 24 · non | idem | aucun | conforme |
| `mutation_step_trap` | 176 px | 12 · 20 · non | ellipse à bord net, centre vide | aucun | conforme |
| `mutation_stasis_shards` | 80 px | 8 · 16 · non | idem | aucun | conforme |
| `mutation_rain_storm` | 384 px | 8 · 10 · **oui** | centre ≤ 50 % (1 % des pixels intérieurs au-delà) | aucun | conforme |
| `mutation_rain_focus` | 104 px | 8 · 24 · non | idem | aucun | conforme |
| `mutation_veil_recoil` | 80 px | 8 · 20 · non | idem (effet très fin : 6 % de couverture au plus) | aucun | conforme |

## 2. Contrôles en jeu des 8 FX (automatiques, `tools/mutation_fx_showcase.tscn`)

Chaque FX est déclenché par le vrai sort et sa vraie mutation, ennemis immobiles. Résultat final : 0 échec.

| FX | Déclencheur vérifié | Largeur (fiche) | Ancrage (fiche) | Priorité | Sol | Suivi | Retiré |
|---|---|---|---|---|---|---|---|
| Exécution | cible marquée sous 20 % PV | 2,20 m (2,2) | cible, 0,60 m | devant la cible | non coupé | — | oui |
| Traque | mort du porteur → nouvel ennemi | 1,60 m (1,6) | nouvel ennemi, 1,00 m | devant la cible | non coupé | — | oui |
| Fente perçante | chacun des 3 ennemis traversés | 1,60 m (1,6) | ennemi, 0,60 m | devant la cible | non coupé | — | oui |
| Ombre piégée | éclatement de l'ombre (1 s) | 2,70 m (2 × rayon) | point de départ | sous les télégraphes | non coupé | — | oui |
| Éclats de stase | chacun des 3 ennemis figés | 1,20 m (1,2) | ennemi, 0,90 m | devant la cible | non coupé | — | oui |
| Orage | lancer, toute la durée | 6,00 m (2 × rayon) | Chasseur | sous les télégraphes | non coupé | suit le Chasseur | avec la zone |
| Concentration | chaque éclat | 1,60 m (1,6) | point d'impact | devant la cible | non coupé | — | oui |
| Contrecoup | tir ennemi détruit par le voile | 1,20 m (1,2) | position du tir | devant la cible | non coupé | — | oui |

Captures : `docs/previews/mutations_v2/en_jeu/<fx>.png`, prises au pic de chaque animation.

## 3. Corrections apportées (rendu uniquement)

1. **Effets ancrés sur un ennemi invisibles** (Éclats de stase, Fente perçante, Exécution, Traque, Concentration,
   Contrecoup ; et les combos et passifs ancrés sur un ennemi ou sur le Chasseur). En rendu pixel (réglage par
   défaut), les personnages sont dessinés en transparence mélangée à la priorité 0 : les effets dédiés, dessinés
   avant eux (priorité −1), étaient entièrement recouverts par leur propre cible. Ces effets, petits et brefs
   (`DraftPixelFx.OVER_TARGET`), partagent maintenant la priorité des personnages et sont triés par profondeur.
2. **Effets au sol coupés par le sol** (Orage : moitié basse de l'ellipse absente ; Ombre piégée, Exécution) :
   l'image face caméra descend sous son ancrage. Les effets dédiés sont avancés vers la caméra
   (`DraftPixelFx._clear_ground`) : la caméra étant orthographique, ni leur place ni leur taille à l'écran ne
   changent. Le suivi de l'Orage passe par `DraftPixelFx.place` (point d'ancrage `anchor` conservé).

Les effets au sol (Orage, Ombre piégée, zones des combos) restent sous les zones annoncées des ennemis. Un petit
effet sur un ennemi peut désormais passer devant un télégraphe au sol pendant sa durée (≤ 0,5 s) : c'est le prix
pour qu'il soit visible sur sa cible. Aucun dégât, recharge, PV, hitbox, récompense ni réglage modifié.

## 4. Les 15 sorts et leurs 30 mutations (balayage automatique `--sweep`)

Chaque configuration : 3 lancers sur 4 ennemis, puis attente de l'expiration. « Restants » = sprites d'effets et
effets peints encore affichés 9 s après (0 partout). Les deux mutations d'un sort sont combinées quand elles sont
compatibles (Estoc ⟂ Tourbillon, Éventail ⟂ Surcharge ne se combinent pas).

| Sort | Sans mutation | Mutation A | Mutation B | A + B | Rendu des doubles |
|---|---|---|---|---|---|
| Taille (`cleaving_slash`) | ok | Estoc ok | Tourbillon ok | incompatibles | — |
| Lance prismatique | ok | Éventail ok | Surcharge ok | incompatibles | — |
| Rupture | ok | Brasier ok | Réaction ok | ok | peinte : inferno (deux ordres) |
| Bond de faille | ok | Impact ok | Retour ok | ok | peinte : impact (deux ordres) |
| Parade | ok | Miroir ok | Longue garde ok | ok | peinte : mirror (deux ordres) |
| Singularité | ok | Effondrement ok | Horizon ok | ok | peinte : collapse (deux ordres) |
| Mur de faille | ok | Rempart ardent ok | Chaînes ok | ok | peinte : burning_wall (deux ordres) |
| Égide | ok | Second souffle ok | Riposte ok | ok | peinte : sharing (deux ordres) |
| Cristal réfracteur | ok | Foyer ok | Prisme double ok | ok | base sur chaque cristal réel |
| Marque du traqueur | ok | Exécution ok (FX dédié) | Traque ok (FX dédié) | ok | effets indépendants |
| Fente du vide | ok | Double fente ok | Fente perçante ok (FX dédié) | ok | effets indépendants |
| Pas de faille | ok | Deux charges ok | Ombre piégée ok (FX dédié) | ok | effets indépendants |
| Onde de stase | ok | Onde circulaire ok | Éclats de stase ok (FX dédié) | ok | effets indépendants |
| Pluie d'éclats | ok | Concentration ok (FX dédié) | Orage ok (FX dédié) | ok | zone réduite + orage à sa taille |
| Voile de cendre | ok | Voile mobile ok | Contrecoup ok (FX dédié) | ok | effets indépendants |

Doubles mutations des sorts historiques : `tools/double_mutation_showcase.tscn` (rapport identique dans les deux
ordres) et `tests/unit/test_draft3d_double_mutations_vfx.gd`.

## 5. Les 12 combos (`tools/combo_showcase.tscn`)

Tous déclenchés dans une vraie partie : Exécution prismatique, Déluge prismatique, Lame gravitationnelle, Chasse
dimensionnelle, Rupture du traqueur, Convergence prismatique, Contre-faille, Rebond spectral, Égide vengeresse,
Prison de faille, Rempart éclatant, Tempête figée (1 déclenchement chacun, 2 pour Tempête figée). Captures relues :
aucun effet coupé ni masqué ; les éclats de Tempête figée et l'éclair de Convergence sont désormais visibles devant
les ennemis. Tests `test_draft3d_combos.gd` et `test_draft3d_combos_lot6.gd` verts (dont
`test_spell_and_combo_effects_exist_in_their_palette`).

## 6. Testé automatiquement / à vérifier à la main

Automatique : présence et format des planches ; déclencheur, largeur, ancrage, priorité, non-coupure par le sol,
suivi et disparition des 8 FX ; lancers des 15 sorts × mutations sans effet résiduel ; déclenchement des 12 combos ;
ordre des doubles mutations ; repli sans planche.

À vérifier en jeu (manette en main) :
- lisibilité en plein combat, avec beaucoup d'ennemis et de télégraphes de boss : un petit FX sur un ennemi peut
  passer devant une zone annoncée sous lui pendant ≤ 0,5 s ;
- Contrecoup : effet très fin (1,2 m, peu de pixels), à juger en vrai — si trop discret, commander une planche plus
  marquée plutôt qu'agrandir (la fiche fixe 1,2 m) ;
- Ombre piégée : effet au sol, donc sous les ennemis qui s'y tiennent (choix voulu) ;
- rendu avec le rendu pixel désactivé (touche de bascule) : non capturé ici ;
- sensation de timing (Exécution au moment du coup, Traque au saut de marque) et cadence de l'Orage en mouvement.
