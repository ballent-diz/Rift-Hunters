# Cartes 3 et 4 — compositions proposées à l’échelle des Ruines

Étape A uniquement, 20 octobre 2026. Branche codex/cartes-3-4-echelle créée depuis main après la fusion de la PR #38 (f528ca1). Le protocole de [QUALITE_DES_CARTES.md](QUALITE_DES_CARTES.md) fait foi.

## Proposition à valider

Les deux compositions font 1536 × 1024 pixels pour un monde de 5016 × 3344 unités. Le générateur reçoit le plan approuvé en image 1, la référence issue de map_regions.py scale-reference en image 2 et le décor des Ruines en image 3. Les éléments individuels du décor sont demandés plus petits et plus nombreux dans les mêmes massifs, sans déplacer les chemins, clairières, ponts, rivières ou entrées.

| Carte | Plan de référence conservé | Nouvelle proposition | Fidélité au plan (seuil ≥ 0,85) |
|---|---|---|---|
| Bois des Lucioles | map.firefly_woods/source/map_source.png | map.firefly_woods/source/composition_echelle.png | 0,972 |
| Gué des Brumes | map.mist_ford/source/map_connected.png | map.mist_ford/source/composition_echelle.png | 0,986 |

Les chemins ci-dessus sont relatifs à assets/concepts/incoming/. Les empreintes des plans correspondent aux blobs du dépôt : Bois 15337b32d4645a7c9d534e7fde7e74b50060a050 ; Gué 6451ebe164e6aa8d545429fccf6af41297b2191a. Les anciennes recompositions et régions refusées n’ont pas été utilisées.

- [Comparaison du Bois : ancienne, proposition, référence](../previews/cartes-3-4-echelle/firefly_woods-comparaison.png).
- [Comparaison du Gué : ancienne, proposition, référence](../previews/cartes-3-4-echelle/mist_ford-comparaison.png).

Les trois panneaux utilisent la même échelle de composition : 3,265625 unités par pixel. Aucun redimensionnement différent entre panneaux. Ce sont des recadrages de composition pour juger l’échelle des décors ; les captures au zoom du jeu avec personnages appartiennent à l’étape B.

## Contrôle effectué

Commande officielle pour chaque carte : tools/art/check_map_quality.py --images <composition_echelle.png> --world 5016x3344 --composition <plan approuvé> --json <rapport>.

- [Rapport Bois](../previews/cartes-3-4-echelle/bois-composition-qualite.json).
- [Rapport Gué](../previews/cartes-3-4-echelle/gue-composition-qualite.json).

Seule la fidélité au plan est exigée à l’étape A : les deux résultats passent. Le verdict global est encore NON CONFORME, puisque ces compositions à 0,306 pixel par unité ne possèdent pas leur détail régional. Ce n’est pas une livraison de cartes finales et aucune qualité finale n’est déclarée conforme. Le score de corrélation contrôle les grandes formes ; il ne remplace pas la validation visuelle de chaque passage par le propriétaire.

Les sources sont générées par image_gen intégré. Les prompts exacts, références d’échelle et SHA256-composition-echelle.txt sont conservés à côté de chaque proposition. Aucun agrandissement de la composition n’est présenté comme carte finale.

## Arrêt avant le détail

**À valider par le propriétaire : plan et échelle des objets des deux propositions**, puis peinture des collisions sur les compositions retenues. La PR reste en brouillon.

L’étape B n’est pas lancée. Après validation : six régions (3 × 2) par carte avec map_regions.py split et son prompt inchangé, assemblage en trois tuiles de 3762 × 7524, contrôle final conforme obligatoire, puis raccordement et captures prévus par la mission.

Aucun changement aux images de jeu, au manifeste, à src/, data/, collision.png, painted.webp ou field.png. Ces nouveaux fichiers de composition restent dans incoming, ignoré par Godot ; les comparaisons sont sous .gdignore. La publication a utilisé le connecteur GitHub car la résolution réseau du Git local échouait, en conservant main actuel comme parent de la branche.
