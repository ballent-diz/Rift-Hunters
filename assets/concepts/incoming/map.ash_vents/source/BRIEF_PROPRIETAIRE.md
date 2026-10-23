Tâche : carte 7 du chapitre 2 « Les Terres dévastées » — « Évents de cendre » (id `ash_vents`). Ce prompt
remplace entièrement la version « Gorges de cendre » (ponts fragiles abandonnés : ne rien en reprendre).
Deux livrables indépendants : A. la carte, B. le sprite des bulbes de braise (mécanique de la carte).

Lis d'abord : AGENTS.md, docs/maps/GENERER_UNE_CARTE.md — **surtout le § 1 bis « Variété », nouveau** —,
docs/maps/QUALITE_DES_CARTES.md (fait foi pour la finesse), docs/maps/LISIERE_CALCINEE.md (identité du chapitre),
docs/ART_BIBLE.md et docs/design/MONSTRES.md. Branche dédiée depuis main à jour, pull request vers main, aucun
changement dans src/ ni data/ (Claude code la mécanique et le niveau).

## Règles de variété (à respecter strictement)

- Les cartes déjà faites (Ruines, Hautes Terres, Bois, Gué, Source, Lisière) sont des références de **style**, jamais
  de **plan**. Ne réutilise aucune de leurs dispositions.
- **Pas d'arène** sur cette carte : le gardien apparaît dans la dernière zone, et le jeu dessine lui-même le cercle
  d'énergie du combat. Ne dessine ni place ronde, ni cour carrée ou en trapèze, ni piliers, ni rochers-abris.
- **Ne peins aucun bulbe** dans la carte : ce sont des sprites séparés, placés par le jeu.

## A. La carte

### Identité et montée en puissance

Un cran plus ravagé que la Lisière calcinée : presque plus d'herbe, de vastes **plaines de cendre et de roche nue
grise-brune**, des **évents** (petites cheminées de roche d'où monte une fumée grise) sur les bords des espaces
ouverts, des fissures rouge sombre, quelques arbres morts isolés. Palette gris cendre, basalte brun, charbon, ocre
brûlé, violet discret de la Faille. **Pas de lave, pas d'orange vif** (réservés aux dangers et aux cartes 9 et 10).
Même caméra, lumière haut-gauche, même finesse que les cartes 1 à 6.

### Format et plan : un parcours en U

Format **3:2**, monde 5016 × 3344, composition 1536 × 1024. Le parcours fait **un U** : il part en bas à droite, file
vers la gauche par le bas, remonte à gauche, puis revient vers la droite par le haut. Coordonnées en % depuis le
haut-gauche :

| Repère | X,Y % | Intention |
|---|---|---|
| Départ | 88,84 | replat dégagé dans un renfoncement rocheux, au bord droit |
| Zone 1 | 70,74 | **plaine d'ash basse**, large et plate (x 52..95, y 58..92), évents sur les bords |
| Passage 1 | 46,74 | **brèche** dans une haute côte rocheuse : ouverture nette de 4 % de large, courte |
| Zone 2 | 22,62 | **longue vallée** orientée nord-sud (x 6..40, y 40..92), plus étroite que la zone 1 mais avec une grande clairière au centre |
| Passage 2 | 18,32 | **rampe** taillée dans la roche qui monte vers le nord, large de 4 %, courte |
| Zone 3 | 55,20 | **corniche en croissant** qui s'étire vers l'est le long du bord haut (x 25..92, y 6..40), creusée en son milieu d'une large cuvette libre (x 45..75) où aura lieu le combat contre le gardien |

- Entre le U du bas et la corniche du haut : une **arête rocheuse infranchissable** (falaises, cheminées fumantes) qui
  sépare nettement les zones 1 et 3. Aucun raccourci entre elles.
- Chaque zone a au moins une **très grande étendue libre** (≥ 750 unités) ; évents, rochers et arbres morts restent
  sur les bords, jamais au milieu.
- Bords de carte fermés par des falaises et des pentes de cendre ; aucune route ne sort de l'image.

### Prompt de composition (anglais, gabarit de GENERER_UNE_CARTE.md § 4)

```
Top-down video game map for Rift Hunters, a 2D survivor-like. ONE complete continuous full-bleed 3:2 landscape
composition, 1536 x 1024 pixels, no borders, no text, no UI, no characters. COMPOSITION ONLY.
STYLE REFERENCES ONLY (art language, NOT layout): image1 Waterfall Ruins, image2 Storm Highlands, image3 Scorched
Verge. Match their crisp hand-painted fantasy game materials, camera and relative object scale.
Theme: ASH VENTS, chapter 2 THE DEVASTATED LANDS, one step more ravaged than Scorched Verge: vast flats of grey ash
and bare grey-brown basalt, small rock chimneys (vents) releasing grey smoke along the edges of open areas, dark-red
fissures, a few isolated dead trees. Ash grey, basalt brown, charcoal, burnt ochre, restrained violet.
NO lava, NO bright orange, NO green, NO photorealism. Uniform steep overhead game camera, top-left light.
LAYOUT: a U-shaped route, percentages from top-left.
Start: clear safe flat ledge in a rocky recess at (88,84), right edge.
Zone1: very wide flat low ash plain, x52..95, y58..92, vents only on its edges.
P1: a short clean BREACH through a tall rock ridge at (46,74), opening 4% of image width.
Zone2: a long north-south valley, x6..40, y40..92, with a huge open clearing in its middle.
P2: a short broad ROCK RAMP climbing north at (18,32), 4% wide.
Zone3: a crescent-shaped high ledge stretching east along the top edge, x25..92, y6..40, widening in its middle
into a broad open hollow (x45..75) with NO structure in it.
An impassable rock spine with smoking chimneys separates Zone1 (bottom) from Zone3 (top): no shortcut between them.
NO arena, NO round or square plaza, NO pillars, NO cover rocks, NO glowing pods or bulbs anywhere.
At least 50% of the image is flat open walkable ground. Each zone has a HUGE open clearing. Clear sharp boundary
between walkable ash/rock and blocking cliffs. Map border closed by cliffs and ash slopes.
```

### Livraison de la carte (comme les cartes 5 et 6)

- Étape 1 : composition + fiche `docs/maps/EVENTS_DE_CENDRE.md` (plan, mesures, liste de 12 emplacements libres
  proposés pour les bulbes : 4 par zone, sur sol plat dégagé, à plus de 400 unités du départ et des passages),
  puis **arrêt pour validation du propriétaire**.
- Étape 2, après validation : régions, `check_map_quality.py` conforme, contrôle de netteté, tuiles finales.
- Le propriétaire peint les collisions ; Claude intègre le niveau, les bulbes, les Calcinés de la carte (Chevalier
  calciné et Chien de suie y entrent, cf. MONSTRES.md) et le gardien.

## B. Sprite des bulbes de braise (`object.ember_pod`)

Mécanique (codée par Claude) : des bulbes de braise poussent sur les plaines. Une attaque du Chasseur ou d'un Écho
les **amorce** : ils gonflent et rougeoient (alerte de 1,5 s), puis **éclatent** en une gerbe de braises qui ravage
les Corrompus autour (le Chasseur trop proche est touché aussi). La coque vide repousse au bout d'un moment.
Occasion tactique : attirer les hordes autour d'un bulbe, puis le faire éclater.

- Objet original : bulbe végétal-minéral de la Faille, gros comme un Écho moyen (hauteur cible 28 unités, ~56 px
  d'art), coque de basalte fendue, cœur de braise rouge sombre visible par les fentes, quelques racines calcinées.
- Planche **6 colonnes × 3 rangées**, même gabarit que les sprites d'objets (`object.altar_seal`) :
  ROW1 `idle` : pulsation lente du cœur (boucle) ; ROW2 `primed` : la coque gonfle, les fentes s'ouvrent, le cœur
  devient orange vif (boucle rapide) ; ROW3 `burst` : éclatement (2 poses), puis coque vide qui retombe, fumante
  (la dernière pose sert d'état « vide » en attendant la repousse).
- Les gerbes, cercles d'alerte et zones de dégâts sont dessinés par le jeu : pas de cercle au sol ni de halo dans
  la planche. Fond transparent, lumière haut-gauche, liseré bas-droite (ART_BIBLE).
- Import avec `tools/art/import_sheet.py` (statut `final` après validation), aperçus GIF dans
  `docs/previews/ember-pod/` avec un `.gdignore`.
