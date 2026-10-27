# Arbre du Chasseur v2 et sorts du Chasseur

Statut : **principes validés le 16 octobre 2026** (apprendre / activer, 4 voies, passifs transformants, rythme,
builds). Les 5 sorts « technique » et « défensif » ajoutés le même jour sont **à confirmer** ; noms, effets et chiffres
restent retouchables. Référence des lots C1 (visée, premiers sorts) et C2 (arbre v2, builds).
Cadre général : [COMPETENCES_ET_BUILDS.md](COMPETENCES_ET_BUILDS.md) ; difficultés : [LONGEVITE.md](LONGEVITE.md).

## 1. Principes

- **Identité du Chasseur** : un sabreur des Failles (sprite de samouraï). Il garde son attaque automatique, le
  **Trait de Faille**, et gagne des **sorts visés au curseur** qui mêlent lame et magie de Faille.
- **Le build se joue sur les sorts** : 12 sorts à apprendre, **4 équipés** (A, E, R, F). Ce choix, plus les variantes
  et les passifs, fait le build.
- **Apprendre ≠ activer** :
  - **apprendre** un nœud coûte des **Éclats**, une seule fois, pour toujours ;
  - **activer** un nœud dans un build coûte des **Points de Chasseur**, en nombre limité. Changer de build est
    **gratuit** au refuge : on expérimente librement (comme le Miroir de Hades), mais on ne peut pas tout activer.
- **Choix exclusifs** : chaque sort a deux **variantes** (A *ou* B) qui changent sa façon de jouer ; une seule
  **clé de voûte** (ultime passif) est active par build.
- **Trois familles de sorts** : *offensifs* (fiables), *défensifs* (survivre, protéger l'équipe) et *techniques*
  (placement ou timing exigeants, **très rentables quand ils sont réussis**, peu ou pas punitifs quand ils sont ratés,
  pour encourager à les tenter).
- Les statuts existants restent le langage commun : Fracture, Marques, Brûlure, Entrave, Racines.

## 2. Les 12 sorts (3 par voie)

Valeurs indicatives, à régler à l'équilibrage. Portée et zone affichées au sol pendant la visée.

| Voie | Sort | Famille | Effet de base | Recharge | Variante A | Variante B |
|---|---|---|---|---|---|---|
| Lame | **Taille fendante** | Offensif | Arc de lame vers le curseur (portée 150) : gros dégâts + Fracture | 4 s | *Tourbillon* : cercle complet autour du Chasseur | *Estoc* : ligne longue et étroite (portée 320) qui perce tout |
| Lame | **Bond de faille** | Offensif | Bond jusqu'au curseur (portée 380), invulnérable pendant le saut, onde de choc à l'arrivée | 9 s | *Retour* : réutiliser dans les 3 s ramène au point de départ | *Impact* : onde 2× plus large qui Entrave 2 s |
| Lame | **Parade** | Défensif · technique | Garde de 0,4 s. Un coup paré : aucun dégât, **contre-attaque** ×4 autour du Chasseur, ennemis étourdis 1,5 s, recharge remise à zéro. Rien de paré : recharge normale | 7 s | *Miroir* : les projectiles parés repartent vers le curseur | *Garde de meute* : la parade protège aussi les Échos proches |
| Prisme | **Lance prismatique** | Offensif | Trait lourd en ligne vers le curseur, traverse tout, pose 2 Marques | 6 s | *Éventail* : 3 lances en cône | *Surcharge* : maintenir la touche charge la lance (dégâts ×2,5) |
| Prisme | **Rupture** | Offensif | Fait détoner toutes les Marques dans une zone au curseur (rayon 220) | 10 s | *Réaction* : chaque détonation pose 1 Marque à côté (chaîne) | *Brasier* : les détonations laissent de la Brûlure au sol 3 s |
| Prisme | **Cristal réfracteur** | Technique | Pose un cristal au curseur (8 s). Chaque Trait ou Lance qui le traverse **se divise en 3** et pose une Marque. Bien placé entre le Chasseur et la horde : dégâts triplés | 12 s | *Prisme double* : 2 cristaux ; un tir qui traverse les deux se divise en 9 | *Foyer* : les tirs convergent sur l'ennemi le plus résistant (élite, boss) |
| Abîme | **Singularité** | Offensif · contrôle | Sphère posée au curseur qui attire les ennemis 3 s puis implose | 14 s | *Horizon* : rayon +40 %, les ennemis attirés subissent +15 % de dégâts | *Effondrement* : implosion 2× plus forte, durée 1,5 s |
| Abîme | **Mur de faille** | Défensif · technique | Mur d'énergie posé au curseur, **orienté selon le mouvement de la souris** (largeur 260, 4 s) : bloque les ennemis et les projectiles. Bien placé dans un passage, il coupe la horde en deux | 13 s | *Chaînes* : les ennemis qui le touchent sont enracinés 1,5 s | *Rempart ardent* : traverser le mur inflige Brûlure et Fracture |
| Abîme | **Failles jumelles** | Technique | Deux portails : le premier appui pose l'entrée, le second (≤ 4 s) la sortie. Projectiles, Échos et Chasseur (en Ruée) passent de l'un à l'autre ; les ennemis qui les traversent sont Fracturés | 16 s | *Boucle* : les Traits qui entrent ressortent ×2 | *Exil* : les ennemis non élites aspirés par l'entrée ressortent loin, Entravés 3 s |
| Lien | **Appel de meute** | Offensif | Les Échos bondissent vers le curseur et frappent ensemble (dégâts selon leur nombre) | 12 s | *Ralliement* : +25 % de vitesse d'attaque aux Échos 4 s | *Curée* : dégâts ×2 sur les élites et le boss |
| Lien | **Égide de faille** | Défensif | Bouclier sur le Chasseur et ses Échos (absorbe 25 % des PV max, 4 s) | 18 s | *Riposte* : quand il se brise, onde de choc | *Partage* : le Chasseur reçoit 50 % du bouclier mais se soigne de 15 % |
| Lien | **Permutation** | Défensif · technique | Échange instantané de place avec l'Écho le plus proche du curseur ; l'Écho est invulnérable 1 s et **provoque** les ennemis proches 2 s. Utilisé à l'instant d'un coup : le coup est esquivé et le prochain sort recharge 50 % plus vite | 10 s | *Relais* : l'Écho échangé lance aussitôt son propre sort | *Sanctuaire* : les deux positions soignent les alliés de 8 % des PV max |

**Départ** : *Taille fendante* (A) et *Lance prismatique* (E) sont connues dès le début (lot C1, **réalisé** : données
`data/spells/`, code `src/entities/player/hunter_spells.gd`, tests `tests/unit/test_hunter_spells.gd` ; variantes au lot C2). Les 10 autres
s'apprennent dans l'arbre. Idées en réserve (pour les variantes, les Échos ou plus tard) : *Écho temporel*
(rejouer sa position et ses PV d'il y a 3 s), *Lame suspendue* (piège à déclencher au bon moment), *Contre-sort*.

## 3. Plan de l'arbre

Un **tronc** commun, puis **4 voies** de 5 niveaux. Coûts : Éclats pour apprendre / Points pour activer.

```
                         TRONC (toujours accessible)
        Vigueur (PV)  ·  Entraînement (dégâts)  ·  Pas fantôme (Ruée)  ·  Dernier souffle
   ┌─────────────────┬──────────────────┬──────────────────┬──────────────────┐
 LAME              PRISME              ABÎME              LIEN
 (corps à corps,   (distance,          (contrôle,         (Échos,
  Fracture)         Marques)            zones)             protection)
 I   passifs
 II  sort 1 + transformant 1
 III variantes du sort 1 + sort 2                                        ← après le chapitre 1
 IV  variantes du sort 2 + sort 3 + transformant 2                       ← après le chapitre 2
 V   variantes du sort 3 + CLÉ DE VOÛTE (une seule active par build)     ← après le chapitre 2
```

Ordre des sorts dans chaque voie : Lame = Taille, Bond, Parade ; Prisme = Lance, Rupture, Cristal ;
Abîme = Singularité, Mur, Failles jumelles ; Lien = Appel, Égide, Permutation.

### Passifs et clés de voûte (reprise de l'arbre actuel en gras)

| Voie | Passifs (niveau I) | Clé de voûte (niveau V) |
|---|---|---|
| Tronc | Vigueur (+10 PV/rang), **Entraînement** (+5 % dégâts/rang), **Pas fantôme**, **Dernier souffle** | — |
| Lame | **Ruée fracturante** ; dégâts au corps à corps +8 %/rang ; **Cogneur de faille** | *Maître-lame* : chaque sort de Lame réduit de 1 s la recharge des autres sorts |
| Prisme | **Tireur des Failles** ; **Résonance prismatique** ; **Pyromancien** ; **Détonation en chaîne** | *Prisme vivant* : le Trait de Faille pose une Marque tous les 3 tirs |
| Abîme | **Brèche profonde** ; **Gravitationniste** ; durée des contrôles +15 %/rang | *Maître du vide* : les ennemis sous Racines ou Entrave subissent +25 % de dégâts |
| Lien | **Liens solides** ; **Techniques affûtées** ; **Chasseur solitaire** *ou* **Chef de meute** | *Âme de meute* : chaque sort du Chasseur réduit de 1 s la recharge des sorts d'Échos |

### Passifs transformants (2 par voie)

Ils changent la façon de jouer, pas seulement les chiffres (le cœur du plaisir façon Hades).

| Voie | Transformant 1 (niveau II) | Transformant 2 (niveau IV) |
|---|---|---|
| Lame | *Ruée tranchante* : la Ruée blesse les ennemis traversés | *Contre-taille* : une Ruée juste avant un coup (0,3 s) recharge le prochain sort de Lame et lui donne +50 % de dégâts |
| Prisme | *Propagation* : un ennemi marqué qui meurt transmet ses Marques au plus proche | *Trait scindé* : le Trait de Faille se divise en 2 en touchant un ennemi marqué |
| Abîme | *Sillage du vide* : la Ruée laisse une traînée qui Entrave 2 s | *Ancre* : un ennemi tué sous Racines s'effondre en petite Singularité |
| Lien | *Garde rapprochée* : quand le Chasseur est touché, l'Écho le plus proche bondit sur l'agresseur | *Fusion* : 4 s après un sort de Lien, les attaques des Échos appliquent les statuts du Chasseur |

**Troisième sceau** (+1 emplacement d'équipe, 3e Écho) reste un nœud à part du tronc, débloqué par la progression de la
campagne, comme prévu dans [ECHOS.md](ECHOS.md).

### Ce qui sort de l'arbre

Les nœuds d'**Exploration** et de **Recherche** (Prospecteur, Aimant, Coffres scellés, Relique de départ, Flair de
l'Essence, Bannissement, Quatrième choix, Étude des Failles, Mutations instables, Évolution précoce, Recrues aguerries)
ne font pas un style de jeu : ce sont des **conforts de partie**. Ils deviennent des **améliorations du refuge**,
achetées une fois et toujours actives (Laboratoire, payées en Essence ou en Éclats), hors du budget de points.
L'arbre ne contient plus que le build de combat.

## 4. Rythme de déblocage (Éclats)

Objectif : **≈ 70 % de l'arbre appris en finissant la campagne (3-6 h), tout l'arbre vers 7 h**, en commençant le
mode Cauchemar.

**Coûts pour apprendre** (Éclats, une fois) :

| Niveau | Nœud | Coût |
|---|---|---|
| Tronc | Vigueur et Entraînement (3 rangs chacun) ; Pas fantôme ; Dernier souffle | 40 / 70 / 110 ; 100 ; 250 |
| I | Passif à 3 rangs + passif simple | 40 / 70 / 110 + 80 |
| II | Sort 1 + transformant 1 | 150 + 200 |
| III | Sort 2 ; chaque variante du sort 1 | 200 ; 120 |
| IV | Sort 3 ; chaque variante du sort 2 ; transformant 2 | 250 ; 150 ; 250 |
| V | Chaque variante du sort 3 ; clé de voûte | 150 ; 400 |

Total ≈ **10 500 Éclats** (≈ 800 pour le tronc, ≈ 2 600 par voie ; les 2 sorts de départ sont offerts).

**Gains d'Éclats réduits d'environ 30 %** (à appliquer avec le lot C2, dans `data/balance/balance_config.tres` et les
boss) : par minute 12 → 8, par Corrompu 0,15 → 0,10, par élite 8 → 6, coffre brisé 25 → 20, boss 150 → 100.
Une victoire de 10 min rapporte alors ≈ 290 Éclats, une défaite ≈ 150-200 ; moyenne ≈ 240, soit ≈ 44 expéditions
(≈ 7 h) pour tout apprendre. Le mode Cauchemar rapporte +25 % d'Éclats.

**Paliers de campagne** : niveau III après le chapitre 1, niveaux IV et V après le chapitre 2. On ne peut pas foncer
au bout d'une voie dès la première heure. En attendant la campagne (lot B1), le palier provisoire est le nombre de
victoires contre un boss (1 pour le niveau III, 3 pour les niveaux IV et V).

## 5. Points de Chasseur

- Départ : **6 points** (les 2 sorts de départ en coûtent 4 : il en reste 2 pour un premier passif). **+1** à la première victoire sur chaque carte en Normal, **+1** tous les 3 objectifs réussis,
  **+1** à la première victoire sur chaque carte en Cauchemar. Ordre de grandeur : ≈ 20 points en fin de campagne,
  ≈ 35 au maximum.
- Coûts d'activation : passif 1 point/rang, sort 2 points, variante 1 point (une seule par sort), transformant
  2 points, clé de voûte 4 points (une seule). Activer tout l'arbre coûterait ≈ 80 points : même au maximum, on active
  **un peu moins de la moitié** de l'arbre et on choisit.
- Les 4 sorts équipés doivent être activés ; les sorts de départ coûtent quand même leurs points, mais le joueur
  commence avec de quoi les activer.

## 6. Builds enregistrés

- **3 emplacements de build** nommables (un 4e et un 5e plus tard par la progression).
- Un build = nœuds activés + 4 sorts équipés sur A, E, R, F + (lot C3) le sort équipé de chaque Écho.
- Choix du build dans le menu de départ d'expédition ; modification au refuge, gratuite.

## 7. En partie : les montées de niveau

Les cartes de niveau restent et renforcent le build (lot C4, avec raretés) : par exemple *Taille fendante : +1 coup*,
*Singularité : recharge −20 %*, *Parade : fenêtre +0,1 s*. Seuls les sorts **équipés** reçoivent des cartes.

## 8. Sauvegarde

Migration de la version de sauvegarde : les Éclats dépensés dans l'arbre actuel sont **remboursés** ; les nœuds
d'exploration et de recherche déjà achetés sont **conservés** comme améliorations du refuge.

## 9. Réalisation

- **Lot C2a (16 octobre 2026)** : `SkillNodeData` (types, points, variantes, paliers, « à venir »), règles
  `src/progression/hunter_tree.gd`, données `data/progression/skill_tree/` et `branches/`, onglet
  `src/ui/refuge/tree_tab.gd` (habillage provisoire, remplacé par le lot C5), sauvegarde v2 (les rangs appris sont
  conservés ; le premier build active les passifs déjà appris), variantes Tourbillon, Estoc, Éventail et Surcharge
  (`hunter_spells.gd`), gains d'Éclats réduits. Palier provisoire : victoires contre un boss (`runs.won`).
- **Lot C2b (16 octobre 2026)** : les 10 autres sorts (`data/spells/`, code `src/entities/player/hunter_spell_world.gd`
  pour les sorts persistants : cristaux, murs, portails, Égide, Parade), leurs 20 variantes, les 8 passifs
  transformants et les 4 clés de voûte (`src/combat/effects/hunter_talent_effect.gd`). Tests :
  `tests/unit/test_hunter_spells_c2b.gd` (chaque sort, chaque variante et chaque talent en mêlée).
- **Animations de Codex raccordées (16 octobre 2026)** : `src/entities/player/hunter_spell_vfx.gd` joue les scènes
  `assets/vfx/hunter/` (manifeste `vfx.hunter.*`) pour les 12 sorts et leurs variantes ; les dessins provisoires ne
  servent plus qu'en secours. Bouton **Test dev** (Refuge → Options, visible seulement depuis Godot) : tout l'arbre
  appris, paliers ouverts, 200 Points de Chasseur, tous les Échos, toutes les cartes et le Cauchemar ouverts.
- **Écran lisible d'un coup d'œil (26 octobre 2026)**, onglet `src/ui/refuge/tree_tab.gd` :
  - en-tête : voies, améliorations du refuge, **Éclats · apprendre** et **Points libres · activer** (avec leur
    rôle en infobulle), builds 1 à 3, bouton **Guide** ;
  - bandeau permanent des trois étapes : ① apprendre (Éclats, pour toujours) › ② activer (Points, dans le build) ›
    ③ équiper (sorts sur les touches) ;
  - plateau `hunter_tree_board.gd` lu de gauche à droite : tronc commun, passifs, sort 1, 2 et 3 avec leurs
    variantes A/B juste dessous, clé de voûte ; talents transformants en bas. Chaque colonne dit si elle est ouverte
    ou combien de boss vaincre (« Boss vaincus 1/3 ») ; cases scellées voilées, sceau sur l'embranchement quand
    les variantes s'ouvrent plus tard que leur sort ; coût en Éclats sur les nœuds à apprendre (rouge s'il manque
    des Éclats) ; halo cyan (apprenable) ou doré (actif) ; légende des états dans une case libre ;
  - fiche : effet, puis « Pour l'utiliser » en 3 étapes cochées (fait, à faire maintenant, bloqué et pourquoi,
    plus tard) ; l'action conseillée vient en premier (apprendre → activer → équiper) ;
  - guide de première visite `tree_guide.gd` (5 pages illustrées par les vrais éléments de l'écran), mémorisé dans
    le profil (`preferences.tree_guide_seen`), rouvert par le bouton Guide. Captures : `docs/previews/c5/tree/`.
- Ajustements de réalisation : les Échos n'ont pas de points de vie, donc *Égide* renforce le bouclier du Chasseur
  (+5 % par Écho), *Garde de meute* fait contre-attaquer les Échos proches, *Sanctuaire* soigne le Chasseur (12 %) ;
  *Contre-taille* se déclenche en esquivant un coup pendant la Ruée ; *Mur de faille* est perpendiculaire à la
  visée ; le *Bond* ne franchit ni l'eau, ni les falaises, ni les barrières ; les portails se posent sur un sol
  praticable.

## 10. Reste à confirmer

1. Les 5 sorts ajoutés : *Parade*, *Cristal réfracteur*, *Mur de faille* (qui reprend les anciennes *Chaînes de
   faille* en variante), *Failles jumelles* et *Permutation*.
2. Noms et effets de l'ensemble, retouchables à tout moment.
