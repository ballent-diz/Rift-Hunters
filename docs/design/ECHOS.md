# Échos : équipe, roster et synergies

Statut : **validé le 14 octobre 2026**. Noms, rôles et mécaniques des nouveaux Échos : **proposition
à affiner** (le propriétaire valide chaque Écho au moment de sa création).

## Taille d'équipe

- **3 Échos maximum en jeu** (+ le Chasseur). Raison : lisibilité et difficulté. Avec 4 sorts du
  Chasseur (A, E, R, F) et 3 sorts d'Échos (1, 2, 3), on reste à 7 compétences actives.
- **Départ avec 1 Écho et 2 emplacements** : le 2e Écho se recrute pendant l'expédition (cartes
  « Pacte »), le **3e emplacement** se débloque par l'arbre.
- **Un sort actif équipé par Écho** : chaque Écho possède 2 à 3 sorts dans son arbre ; le build en
  équipe un seul (touche 1, 2 ou 3 selon sa place dans l'équipe).
- Équipes possibles avec 16 Échos et 3 places : **560**.

Réalisé (lot C6) : `max_team_slots` = 3 (`src/data/balance_config.gd`).

## Roster cible : 16 Échos

7 existants + **9 à créer**, recrutés au fil des chapitres (environ 2 à 3 nouveaux par chapitre ;
ce sont des récompenses de campagne).

## Synergies

### Affinités (automatiques)

8 affinités, chacune portée par **4 Échos** ; chaque Écho en a 2.

| Type | Affinités |
|---|---|
| Éléments | Braise, Foudre, Lumière, Vide, Pierre, Nature |
| Tempéraments | Prédateur, Gardien |

- **2 Échos** de la même affinité dans l'équipe → bonus.
- **3 Échos** (toute l'équipe) → bonus renforcé (build spécialisé).
- Les anciennes affinités « arcane » et « contrôle » disparaissent (remplacées ci-dessous).

**Bonus réalisés (lot C6, 17 octobre 2026 ; valeurs proposées, à ajuster à l'équilibrage)** — données
`data/synergies/affinity_<affinité>_<2|3>.tres` (Prédateur (2) garde l'identifiant `predators`). Les bonus à 3 Échos
s'ajoutent à ceux à 2.

| Affinité (identifiant) | 2 Échos | 3 Échos (en plus) |
|---|---|---|
| Braise (`ember`) | Attaques des Échos : 15 % de Brûlure | Brûlure +50 % |
| Foudre (`storm`) | Vitesse d'attaque des Échos +10 % | Attaques des Échos : 20 % d'électrisation (dégâts subis +20 %) |
| Lumière (`light`) | Marques : cumul max +1 | Attaques des Échos : 15 % de Marque |
| Vide (`void`) | Fracture +1 s | Ennemis Fracturés : +10 % de dégâts subis |
| Pierre (`stone`) | +20 PV max | Dégâts subis −10 % |
| Nature (`nature`) | Régénération +0,5 PV/s | Soins +25 %, régénération +0,5 PV/s |
| Prédateur (`predator`) | Échos +20 % contre les ennemis sous 50 % de PV | Dégâts contre élites et boss +20 % |
| Gardien (`guardian`) | Dégâts subis −8 % | Dégâts subis −7 % de plus, +20 PV max |

Affinités affichées au bestiaire (fiche de chaque Écho et condition des synergies).

### Duos nommés (faits à la main)

- Interaction spéciale entre deux Échos précis (équivalent des bienfaits duo de Hades).
- Objectif : **1 à 2 duos par Écho, soit 20 à 25 duos** pour 16 Échos.
- Les 6 duos existants sont conservés (Brèche & Lame, Racines profondes, Prisme de gravité, Miroir
  d'éclairs, Braise prismatique, Arc prismatique) ; « Prédateurs » devient la synergie d'affinité
  Prédateur.
- Les duos découverts s'affichent au bestiaire (objectif de collection, trophées).

## Répartition des affinités (16 Échos)

| # | Écho (FR / EN, identifiant) | Rôle | Affinités | Statut |
|---|---|---|---|---|
| 1 | Cendrelame / Ashblade (`ashblade`) | Assassin | Braise, Prédateur | Existant |
| 2 | Mousseroc / Mossback (`mossback`) | Gardien | Pierre, Gardien | Existant |
| 3 | Lucivelle / Glimmerwing (`glimmerwing`) | Soutien (marques) | Lumière, **Foudre** | Existant — « arcane » remplacé |
| 4 | Ronceline / Thornweave (`thornweave`) | Contrôle (ronces) | Nature, **Gardien** | Existant — « contrôle » remplacé |
| 5 | Fulgurine / Voltwisp (`voltwisp`) | Tireuse (chaînes) | Foudre, **Prédateur** | Existant — « arcane » remplacé |
| 6 | Gueule-d'ombre / Gloommaw (`gloommaw`) | Combattant (dévore) | Vide, Prédateur | Existant |
| 7 | Mirelle / Mirrorling (`mirrorling`) | Soutien (renvoi de projectiles) | Lumière, Gardien | Existant (sprite à faire) |
| 8 | Pyraile / Cinderwing (`cinderwing`) | Tireur aérien | Braise, Foudre | Nouveau |
| 9 | Scoriade / Magmander (`magmander`) | Contrôle de zone (lave) | Braise, Pierre | Nouveau |
| 10 | Spectrâtre / Hollowflame (`hollowflame`) | Dégâts de zone (implosions) | Braise, Vide | Nouveau |
| 11 | Sporelune / Moonspore (`moonspore`) | Affaiblisseur (dégâts sur la durée) | Vide, Nature | Nouveau |
| 12 | Gravelune / Gravishell (`gravishell`) | Contrôle (gravité) | Pierre, Vide | Nouveau |
| 13 | Sylvécaille / Grovestag (`grovestag`) | Soigneur | Nature, Pierre | Nouveau |
| 14 | Solgriffe / Sunclaw (`sunclaw`) | Assassin (aveuglement) | Lumière, Prédateur | Nouveau |
| 15 | Lueurine / Glowmoth (`glowmoth`) | Soutien (vitesse, lumière) | Lumière, Nature | Nouveau |
| 16 | Égidor / Stormshell (`stormshell`) | Gardien (bouclier conducteur) | Foudre, Gardien | Nouveau |

Contrôle : Braise 4 · Foudre 4 · Lumière 4 · Vide 4 · Pierre 4 · Nature 4 · Prédateur 4 · Gardien 4.

## Les 9 nouveaux Échos (proposition d'origine, réalisée ci-dessous)

Chaque Écho a **sa couleur vive propre** ; aucun n'utilise le **magenta** comme accent principal
(réservé aux Corrompus et au danger, voir `docs/ART_BIBLE.md`).

| Écho | Apparence | Couleurs | Mécanique | Idées de sorts (visés au curseur) |
|---|---|---|---|---|
| **Pyraile** | Oiseau de proie aux plumes de braise, crête d'éclairs, vole bas | Orange braise, jaune électrique | Pique sur les ennemis et laisse des traînées de feu | Pluie de cendres (zone), Piqué foudroyant (ligne) |
| **Scoriade** | Salamandre trapue à peau de roche refroidie, fissures de lave | Rouge lave, gris basalte | Laisse des flaques de lave qui ralentissent et brûlent | Coulée (ligne de lave), Geyser (zone) |
| **Spectrâtre** | Feu follet d'ombre enveloppé d'une flamme bleu pâle, sans jambes (flotte) | Bleu pâle, noir fumé | Marque des ennemis qui implosent à leur mort | Implosion (zone), Flamme errante (projectile rebondissant) |
| **Sporelune** | Champignon-créature à chapeau lumineux, petites pattes, spores qui flottent | Bleu-vert luminescent, beige | Répand des spores : poison qui se propage entre ennemis | Nuée de spores (zone), Bourgeon (piège) |
| **Gravelune** | Tortue-astéroïde, carapace de roche lunaire, petit anneau orbital | Gris-bleu, anneau doré | Attire les ennemis vers un point | Singularité (zone d'attraction), Météore (impact) |
| **Sylvécaille** | Cerf de mousse et d'écorce, bois ornés de cristaux ambrés | Vert mousse, ambre | Soigne le Chasseur et les Échos, plante des bosquets | Bosquet (zone de soin), Ronces protectrices (bouclier) |
| **Solgriffe** | Lynx svelte au pelage doré, crinière en rayons de soleil | Or, blanc solaire | Bonds rapides ; aveugle les ennemis (ratent leurs attaques) | Éclat solaire (cône), Bond lumineux (déplacement) |
| **Lueurine** | Grand papillon de nuit aux ailes translucides et lucioles en orbite | Jaune-vert, blanc | Accélère l'équipe ; révèle et affaiblit les ennemis | Essaim de lucioles (zone), Poudre d'ailes (ralentissement) |
| **Égidor** | Scarabée massif à carapace bleu acier parcourue d'arcs électriques | Bleu acier, jaune électrique | Encaisse et renvoie les dégâts en foudre | Dôme conducteur (bouclier), Décharge (onde) |

Propositions de duos à creuser lors de la conception : Pyraile + Fulgurine (orage de braise),
Scoriade + Mousseroc (coulée de pierre), Sporelune + Gueule-d'ombre (festin putride),
Gravelune + Spectrâtre (effondrement), Sylvécaille + Ronceline (forêt vivante),
Solgriffe + Cendrelame (chasse à l'aube), Lueurine + Lucivelle (constellation),
Égidor + Mirelle (réflexion totale).

## Réalisation (lot C7, 18 octobre 2026)

Les 9 Échos sont jouables. **Proposition à valider par le propriétaire** : noms, effets et chiffres sont en données
(`data/monsters/<écho>.tres`, `data/techniques/`, `data/progression/echo_tree/`, `data/synergies/`), retouchables
sans code. Ils se débloquent comme Mirelle ou Gueule-d'ombre : **Rite de lien** (capture d'un Écho errant à la mort
d'une élite), puis recrutement en expédition.

| Écho | Attaque (comportement) | Passif | Sort d'origine | Second sort | Signature |
|---|---|---|---|---|---|
| Pyraile | Piqué de braise : traverse sa cible, traînée de feu (`dive`) | Équipe +10 % contre les Brûlés | Pluie de cendres (8 impacts, Brûlure) | Piqué foudroyant (ligne + impact, Électrise) | 30 % d'Électriser |
| Scoriade | Crachat de lave : flaque 4 s, Brûlure + ralenti (`zone`) | Chasseur −6 % de dégâts près d'elle | Coulée (ligne de lave 4 s) | Geyser (éruption retardée, bouillonne 2,5 s) | Brûlure +25 % |
| Spectrâtre | Flamme creuse : Marque creuse (`orb`) | Les marqués implosent à leur mort | Implosion (aspire puis implose, Fracture) | Flamme errante (rebondit sur 6 ennemis) | Équipe +12 % contre les marqués |
| Sporelune | Bouffée de spores : 2 Poisons (`orb`) | Le Poison se propage à la mort | Nuée de spores (zone 5 s) | Bourgeon (piège : 3 Poisons, Racines, spores) | Équipe +10 % contre les empoisonnés |
| Gravelune | Choc gravitationnel : attire et ralentit (`slam`, recul négatif) | 25 % de Fracture | Singularité (puits 2,5 s, Fracture) | Météore (impact retardé 0,7 s) | +25 PV max |
| Sylvécaille | Ramure : charge au contact (`striker`) | Chaque coup soigne 1 PV (0,6 s) | Bosquet (zone 5 s qui soigne 12 % et ralentit) | Ronces protectrices (bouclier 20 %, Racines) | Soins +20 % |
| Solgriffe | Griffes solaires : 2 cibles, Aveuglement (`striker`) | +25 % contre les aveuglés | Éclat solaire (cône, Aveuglement) | Bond lumineux (bond + impact) | 30 % de Marque |
| Lueurine | Poudre lumineuse : Révèle (`orb`) | Cadence des Échos +8 %, vitesse +5 % | Essaim de lucioles (zone 5 s, équipe +15 % de vitesse) | Poudre d'ailes (cône : ralentit, révèle) | Ruée −15 % de recharge |
| Égidor | Carapace foudroyante : provoque, Électrise (`slam`) | Riposte : quand le Chasseur est touché, foudre sur 3 ennemis | Dôme conducteur (bouclier 25 %, zone qui Électrise) | Décharge (onde depuis Égidor) | −6 % de dégâts près de lui |

- **Nouveaux statuts** : Poison (3 dégâts/s par cumul, 6 cumuls), Aveuglé (rate 50 % de ses attaques, contact et
  tirs), Marque creuse (implose à la mort avec le passif de Spectrâtre), Révélé (dégâts subis +12 %).
- **Deux évolutions par Écho** (rang 3) et une **variante** de maîtrise, comme les Échos existants. Les évolutions
  n'ont pas encore de sprite propre : le sprite de base est teinté.
- **Duos nommés** (8 nouveaux, 14 au total) : Orage de braise (Pyraile + Fulgurine), Coulée de pierre (Scoriade +
  Mousseroc), Festin putride (Sporelune + Gueule-d'ombre), Effondrement (Gravelune + Spectrâtre), Forêt vivante
  (Sylvécaille + Ronceline), Chasse à l'aube (Solgriffe + Cendrelame), Constellation (Lueurine + Lucivelle),
  Réflexion totale (Égidor + Mirelle).
- **Effets peints** (Codex, `docs/art/ECHOS_C7_EFFETS.md`) raccordés par `src/entities/allies/echo_vfx.gd` :
  attaques, sorts, statuts et indicateurs de visée. Avec l'option « aperçu », maintenir la touche d'un Écho affiche
  l'indicateur, relâcher lance le sort.
- Code : comportement `dive` (Pyraile), sorts `barrage`, `delayed_strike`, `field`, `field_line`, `bouncing_bolt`,
  `heal_field`, `guard_field`, `cone`, `shock_ring` (`techniques.gd`), effets `HealOnHitEffect` et
  `RetaliateOnHurtEffect`, zones de soin et bonus temporaires.

## Sprites des nouveaux Échos

- Direction artistique : celle des Échos existants (planche de référence :
  `assets/concepts/incoming/planches_communes/sprite_monsters.png`, et les dossiers
  `assets/concepts/incoming/monster.*`) et `docs/ART_BIBLE.md`.
- Une planche par Écho, fond vert uni, vue de côté tournée vers la droite (légère plongée 3/4),
  lignes : repos, déplacement, attaque, sort, mort. Import : `tools/art/import_sheet.py`
  (`anchor_mode: mass`, `scale: 0.75`, hauteur en jeu ≈ celle des Échos existants).
- Réalisation : propriétaire (génération) + Codex (préparation des prompts, import, contrôle).

## Questions ouvertes

- Validation Écho par Écho (nom, apparence, mécanique) au moment de la création.
- Ordre d'arrivée des nouveaux Échos dans les chapitres.
- Valeurs des bonus d'affinité : proposées (tableau ci-dessus), à ajuster à l'équilibrage.
