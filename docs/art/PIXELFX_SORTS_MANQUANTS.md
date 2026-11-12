# Sorts : raccordements et compléments PixelFX

Livraison Codex du 12 novembre 2026, depuis `origin/main` (`5473c765`). Demande du propriétaire : couvrir le
Chasseur, les Échos, les monstres et les boss dont les sorts n'ont pas encore d'animation.

## Périmètre contrôlé

| Contenu chargé par GameDB | Résultat |
|---|---|
| 12 sorts du Chasseur | Scènes peintes déjà présentes et raccordées, conservées. |
| 16 Échos, 32 sorts | Les 32 vrais lancers créent leur animation ; 12 raccordements manquaient. |
| 78 entrées ennemies, dont le mannequin, 65 techniques déclarées | Effets existants conservés ; lancement ajouté aux deux techniques `web` sans animation propre. |
| 25 boss, 119 couples boss/motif distincts | Compléments ci-dessous ; les animations peintes et les anneaux PixelFX existants restent en place. |
| 10 familles de Corrompus | Corps animés et impacts de projectile de secours dans leur palette ; les corps peints restent prioritaires. |

### Échos

Les scènes existaient, mais ces sorts ne les lançaient pas : Danse des cendres, Puits de gravité, Embrasement,
Mur de ronces, Tempête ionique, Festin, Reflet, Rempart de mousse, Pluie d'étincelles, Floraison, Arc chaîné et
Éclats miroirs. Les positions secondaires viennent des cibles effectivement résolues. La Tempête frappe
visuellement au délai de ses dégâts ; les entailles gardent un rayon de 48 unités au plus, distinct du rayon de
sélection des ennemis. Reflet suit le Chasseur et finit avec sa durée. Les sorts temporaires ne bouclent plus
indéfiniment. Les attaques peintes de Mirelle et de Gueule-d'ombre sont également raccordées.

### Monstres et boss

- Veuve de cendre : lancement de Toile de suie et corps fumant du tir.
- Archère du givre : lancement glacé et lance de glace orientée sur le vrai projectile.
- Colosse de banquise : famille `silence`, balayage, charge, invocation et fracture de glace.
- Chimère des brumes : éclair au départ et tonnerre à l'arrivée de son saut.
- Chaman ancestral : stalactites aux impacts de la pluie de roches.
- Commandant déchu : rage et impact du Cri de guerre.
- Golem du sanctuaire : rune de lancement et sceaux d'impact.
- Gardienne du Panthéon : effet d'invocation du Réveil.
- Grand Héraldiste : drainage d'âmes et sceau d'impact.
- Abyssarque : portail et apparitions des Échos des mondes, chute, roches, pics de pierre, éclatement et rayons
  arcaniques, recolorés dans la palette `riftborn`.
- Nivorath : souffle glacé réellement déclenché par le rayon ; Nébulorax et Astravorn : rayon arcanique.

Les rayons commencent après leur annonce, suivent leur direction, finissent avec leur durée et s'arrêtent à la
portée libre donnée par les abris. Leur motif est conservé sur la zone, même si le boss prépare un autre sort.
Les tirs animés sont attachés au vrai projectile et suivent sa disparition et son recyclage. Le contour hostile
et son cœur rose clair restent visibles ; au-delà de 32 tirs animés, le dessin générique prend le relais.
Les plafonds PixelFX de 48 effets et de 12 états restent en vigueur.

Les entrées qui n'ont pas besoin d'une nouvelle attribution ont été vérifiées : ondes `shadow_wave` et `quake`
par les anneaux PixelFX ; `tide_wave`, `root_leash` et `source_orb` par leurs effets peints ; Grand gel par ses
moments de libération et de protection du brasero. Les animations de ces mécaniques restent celles déjà livrées.

## Sources et reproduction

Catalogue : `assets/vfx/pixelfx/techniques.json`. Palettes : `tools/art/pixelfx/families.json`.
PixelFX, licence MIT : <https://github.com/patch-gg/pixelfx>, commit
`5294518ce7c72e48b6100a744596e0acf57f2826`. Mentions dans `THIRD_PARTY_NOTICES.md`.

```sh
python3 tools/art/build_pixelfx.py /chemin/vers/pixelfx
godot --headless --import --path .
tools/run_tests.sh scripts
tools/run_tests.sh unit
tools/run_tests.sh assets
```

Le générateur ne refait pas les feuilles présentes. Quinze nouvelles feuilles sont retenues ; les sources
PixelFX et les PNG intermédiaires des captures restent hors dépôt.

Banc de capture, sans écriture du profil, sur les Ruines avec le Chasseur et les ennemis réels :

```sh
xvfb-run -a godot --path . tools/art/spell_vfx_preview.tscn -- --out=/tmp/spell-vfx
# Un ou plusieurs cas : --only=ash_dance,soot_web,frost_arrow
```

Neuf situations, à 12 images/s, avec un reçu `verification.json`. Les scènes sont figées et leurs effets sont
avancés à pas fixe pour pouvoir examiner aussi les animations courtes. Les dégâts, portées, recharges et statuts
proviennent des règles du jeu. Le banc retire ses obstacles locaux afin de stabiliser ses cibles ; le test unitaire
du rayon vérifie séparément l'arrêt devant un abri et le repli graphique au plafond.

## Aperçus et vérifications

- [Échos](../previews/pixelfx-sorts/echos.gif)
- [Monstres](../previews/pixelfx-sorts/monstres.gif)
- [Boss](../previews/pixelfx-sorts/boss.gif)

Import Godot 4.3 réussi ; 379 scripts sans échec ; suite complète : 521 tests réussis ;
puis 12 tests PixelFX ciblés réussis après le contrôle de priorité des rayons peints ;
510 ressources valides, zéro erreur ; lint GDScript (`src tests tools`) sans problème. Lot total : environ 8,89 Mio, dont les trois GIF
(0,99 / 0,66 / 2,08 Mio, chacun inférieur à 3 Mio).
Les tests supplémentaires vérifient les 32 lancers, le suivi et la fin de Reflet, l'absence d'effet si le lancer
échoue, les éléments permis, les projectiles recyclés, le déclenchement et l'orientation des rayons, leurs abris
et leurs plafonds. L'appréciation finale de la lisibilité en combat dense reste à faire en jouant.
