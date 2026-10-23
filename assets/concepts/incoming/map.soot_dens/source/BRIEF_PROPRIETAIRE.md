Tâche : carte 8 du chapitre 2 « Les Terres dévastées » — « Tanières de suie » (id `soot_dens`), plus deux sprites
d'objets pour ses mécaniques. Trois livrables indépendants : A. la carte, B. le nid de cendre, C. l'œuf de cendre.

Lis d'abord : AGENTS.md, docs/maps/GENERER_UNE_CARTE.md (§ 1 bis « Variété » : obligatoire),
docs/maps/QUALITE_DES_CARTES.md, docs/design/DIFFICULTE.md, docs/design/MONSTRES.md, docs/ART_BIBLE.md, et la fiche
de la carte 7 (Évents de cendre) pour ne pas en reprendre le plan. Branche dédiée depuis main à jour, pull request
vers main, aucun changement dans src/ ni data/.

## Règles de variété

- Les cartes déjà faites sont des références de **style**, jamais de **plan**.
- Différences imposées avec la carte 7 : format **1:1** (et non 3:2), parcours **du haut vers le bas en zigzag**
  (et non en U), passages **en escaliers et en ponts de pierre** (et non brèche et rampe), et une **arène** cette fois.
- **Arène** : une **nef de temple effondrée**, longue et étroite (environ 3 fois plus longue que large, au moins
  900 unités de long et 450 de large), orientée en diagonale, toit écroulé, sol dallé fissuré, une entrée large à un
  bout. Ni ronde, ni carrée, ni trapèze.
- **Abris (demande du propriétaire)** : 3 à 5 gros blocs de roche ou de maçonnerie effondrée répartis **dans les
  zones** (pas sur les routes, pas en ligne), assez gros pour cacher le Chasseur (≥ 120 unités), espacés d'au moins
  350 unités. Dans l'arène : 2 tronçons de colonnes tombées, couchés, décalés (pas debout, pas symétriques).
- **Ne peins ni nids ni œufs** : ce sont des sprites séparés, placés par le jeu.

## A. La carte

### Identité (montée en puissance du chapitre)

Plus dense et plus fermée que les cartes 6 et 7 : ruines d'un monastère calciné accroché à une pente, terrasses de
pierre noircie, cendre épaisse, roche nue gris-brun, fumée qui sort des failles, toiles grises accrochées aux ruines
(les Veuves de cendre nichent ici). Fissures rouge sombre, violet discret de la Faille. **Pas de lave, pas d'orange
vif.** Espaces un peu plus étroits qu'aux cartes précédentes, mais chaque zone garde une grande clairière.

### Plan (coordonnées en % depuis le haut-gauche, monde 5016 × 5016, composition 1536 × 1536)

| Repère | X,Y % | Intention |
|---|---|---|
| Départ | 15,10 | parvis dégagé en haut à gauche |
| Zone 1 | 35,20 | terrasse haute du monastère, cour large (x 8..62, y 5..34) |
| Passage 1 | 66,28 | **escalier** large qui descend vers l'est, court |
| Zone 2 | 72,48 | terrasse médiane, jardins calcinés (x 52..95, y 34..64) |
| Passage 2 | 46,62 | **pont de pierre** solide au-dessus d'une faille fumante, court, vers l'ouest |
| Zone 3 | 28,74 | terrasse basse, réfectoire effondré (x 5..50, y 60..92) |
| Accès arène | 56,82 | large porche |
| Arène | 76,84 | nef effondrée en diagonale (voir plus haut) |

Les zones sont séparées par des murs de soutènement et des failles infranchissables : aucun raccourci entre elles.

### Prompt de composition (anglais, gabarit de GENERER_UNE_CARTE.md § 4)

```
Top-down video game map for Rift Hunters, a 2D survivor-like. ONE complete continuous full-bleed SQUARE composition,
1536 x 1536 pixels, no borders, no text, no UI, no characters. COMPOSITION ONLY.
STYLE REFERENCES ONLY (art language, NOT layout): image1 Waterfall Ruins, image2 Scorched Verge, image3 Ash Vents.
Theme: SOOT DENS, chapter 2 THE DEVASTATED LANDS: the scorched ruins of a monastery clinging to a slope, terraces of
blackened stone, thick ash, bare grey-brown rock, smoke rising from fissures, grey webs hanging on ruined walls.
Dark-red fissures, restrained violet. NO lava, NO bright orange, NO green, NO photorealism.
Uniform steep overhead game camera, top-left light.
LAYOUT zigzag from top to bottom, percentages from top-left:
Start: clear forecourt at (15,10). Zone1: upper monastery terrace, wide courtyard, x8..62, y5..34.
P1: short broad STAIRCASE going down east at (66,28). Zone2: middle terrace with burnt gardens, x52..95, y34..64.
P2: short sturdy STONE BRIDGE over a smoking rift at (46,62), going west. Zone3: lower terrace with a collapsed
refectory, x5..50, y60..92. Wide porch at (56,82) leading to the ARENA: a long narrow collapsed temple NAVE set
diagonally around (76,84), about three times longer than wide, cracked flagstones, roof fallen in, one broad
entrance; two fallen column segments lying on the floor, offset, not symmetrical. NOT round, NOT square.
Inside the three zones: 3 to 5 large fallen masonry blocks or boulders big enough to hide behind, spread apart,
never on roads. Retaining walls and rifts separate the zones: no shortcut between them.
Each zone keeps a huge open clearing. At least 50% flat walkable ground. Clear sharp walkable/blocked boundaries.
Map border closed by cliffs and ruins. NO nests, NO eggs, NO glowing objects painted on the ground.
```

### Livraison

Comme les cartes précédentes : étape 1 composition + fiche `docs/maps/TANIERES_DE_SUIE.md` (plan, mesures, liste de
6 à 8 emplacements libres proposés pour les nids, 2 à 3 par zone, sur sol plat, loin du départ et des passages),
**arrêt pour validation du propriétaire** ; étape 2 régions, contrôle qualité conforme, tuiles finales.

## B. Nid de cendre (`object.ash_nest`)

Mécanique (codée par Claude, brique B8 « nids qui pondent ») : des nids parsèment les zones ; tant qu'un nid est
debout, il libère périodiquement des Rampe-cendres ; le détruire coupe la source. Cibles prioritaires.

- Objet original : amas de cendre durcie et de soie grise en forme de cocon ouvert, posé au sol, œufs pâles à
  moitié enfouis, braises rouge sombre au fond. Taille au sol ~90 unités de large (cellule 256 px, scale 0,5).
- Planche **6 colonnes × 3 rangées** : ROW1 `idle` (pulsation lente, boucle) ; ROW2 `spawn` (le nid s'ouvre et
  libère, 6 poses) ; ROW3 `death` (s'effondre en cendres, la dernière pose est un tas de cendre plat).
- Pas de cercle au sol ni de halo ; fond transparent, lumière haut-gauche, liseré bas-droite (ART_BIBLE).

## C. Œuf de cendre (`object.ash_egg`)

Remplace le sprite provisoire dessiné par script (`assets/concepts/incoming/object.ash_egg/`, statut `wip`) : œufs
pondus par la Veuve de cendre, à casser avant l'éclosion.

- Objet original : œuf ovale de cendre durcie, gros comme un petit Corrompu (hauteur cible 22 unités), coque grise
  fendue, lueur pâle qui palpite dans les fentes.
- Planche **6 × 2** : ROW1 `idle` (pulsation, boucle) ; ROW2 `hatch` (la coque se fend et s'ouvre, dernière pose :
  coque vide). Même import que l'objet actuel (`job.json` existant à mettre à jour, statut `final`).

Import avec `tools/art/import_sheet.py`, aperçus GIF dans `docs/previews/ash-nest-egg/` avec un `.gdignore`.
