# Sorts actifs du Chasseur dans la version 3D (v2)

Session « Gameplay », 14 novembre 2026. Périmètre : les **sorts actifs** du Chasseur dans `draft3d/`, puis leurs
**améliorations**. Hors périmètre : Échos (décision en attente), sorts passifs, matières et rendu.

## 1. Inventaire de l'existant v1

Sources : `data/spells/*.tres` (`SpellData`), `src/entities/player/hunter_spells.gd` (lancement, variantes de Taille
et de Lance), `hunter_spell_world.gd` (sorts persistants et autres variantes), `hunter_spell_vfx.gd` (scènes peintes
`assets/vfx/hunter/`), nœuds de l'arbre `data/progression/skill_tree/` (sort, variantes A/B, transformants, clés de
voûte, `src/combat/effects/hunter_talent_effect.gd`), conception `ARBRE_DU_CHASSEUR.md`. Unités : la v1 compte en
pixels du monde 2D ; la v2 convertit avec `DraftHunter.UNIT` (0,03 m par unité).

| Sort (voie) | Effet v1 | Visée v1 | Recharge | VFX v1 → PixelFX v2 | Variantes v1 (A / B) | Verdict v2 |
|---|---|---|---|---|---|---|
| **Taille fendante** (Lame) | Arc de 60° devant, portée 150, 40 dégâts, recul, Fracture | curseur / devant | 4 s | scène peinte `cleaving_slash` → `heavy_cleave` | Tourbillon (cercle, portée ×0,85) / Estoc (ligne 320 qui perce) | **À adapter** : fait (arc 3D de plain-pied, décor qui arrête) ; Fracture non reprise |
| **Lance prismatique** (Prisme) | Trait lourd qui traverse tout, 30 dégâts, 2 Marques | curseur / devant | 6 s | scène peinte → `ice_lance` (palette Reflets) | Éventail (3 lances en cône, ×0,8) / Surcharge (maintenir : ×1 à ×2,5) | **À adapter** : fait (trait 3D à sa hauteur, arrêté par les murs) ; Marques non reprises |
| **Rupture** (Prisme) | Fait détoner les Marques dans une zone (rayon 220) | point visé | 10 s | `dark_explosion` | Réaction (chaîne de Marques) / Brasier (Brûlure au sol) | **À adapter** : fait, sans Marques la détonation frappe ×2 (`rupture_damage_mult`) |
| **Bond de faille** (Lame) | Bond au point visé (380), invulnérable, onde à l'arrivée | point visé | 9 s | `blink_out` + `ring_burst` | Retour (réutiliser dans 3 s ramène au départ) / Impact (onde ×2 qui Entrave) | **À adapter** : fait (saut en cloche, arrêté par le décor, posé sur la navigation, portée 9 m) |
| **Parade** (Lame) | Garde 0,4 s ; coup paré : aucun dégât, contre-attaque ×4, étourdit, recharge remise | sur soi | 7 s | scène peinte `parry` → `shield_block` | Miroir (renvoie les tirs) / Garde de meute (Échos) | **À adapter** (lot 4) ; *Garde de meute* abandonnée (Échos) |
| **Cristal réfracteur** (Prisme) | Cristal 8 s : un Trait ou une Lance qui le traverse se divise en 3 | point visé | 12 s | scène peinte → `rune_circle` / `ice_shatter` | Prisme double / Foyer (vers l'ennemi le plus résistant) | **À adapter** (lot 4) |
| **Singularité** (Abîme) | Sphère qui attire 3 s puis implose (45) | point visé | 14 s | → `black_hole` + `dark_explosion` | Horizon (rayon +40 %, +15 % de dégâts subis) / Effondrement (×2, 1,5 s) | **À adapter** (lot 4) |
| **Mur de faille** (Abîme) | Mur 4 s perpendiculaire à la visée, bloque ennemis et tirs | point visé | 13 s | → `rune_circle` en rangée | Chaînes (Racines 1,5 s) / Rempart ardent (Brûlure + Fracture) | **À adapter** (lot 4) : collision 3D temporaire, la navigation des ennemis doit le contourner |
| **Failles jumelles** (Abîme) | Deux portails : tirs, Échos et Chasseur en Ruée passent | 2 appuis | 16 s | → `portal` | Boucle (Traits ×2) / Exil (ennemis renvoyés loin) | **À adapter plus tard** : deux appuis et portails en relief, coût élevé ; repoussé après validation |
| **Appel de meute** (Lien) | Les Échos bondissent et frappent ensemble | point visé | 12 s | scène peinte `pack_call` | Ralliement / Curée | **Abandonné** en v2 (repose sur les Échos) |
| **Égide de faille** (Lien) | Bouclier 25 % des PV max (+5 % par Écho), 4 s | sur soi | 18 s | scène peinte `rift_aegis` → `shield_block` | Riposte (onde à la rupture) / Partage (moitié du bouclier, soin 15 %) | **À adapter** (lot 4), sans la part des Échos |
| **Permutation** (Lien) | Échange de place avec un Écho, provocation | point visé | 10 s | — | Relais / Sanctuaire | **Abandonné** en v2 (repose sur les Échos) |

**Autour des sorts (v1)** : transformants (*Ruée tranchante*, *Contre-taille*, *Propagation*, *Trait scindé*,
*Sillage du vide*, *Ancre*, *Garde rapprochée*, *Fusion*) et clés de voûte (*Maître-lame*, *Prisme vivant*,
*Maître du vide*, *Âme de meute*) sont des **passifs** : hors périmètre. Les statuts (Fracture, Marques, Brûlure,
Entrave, Racines) n'existent pas encore dans `draft3d/` : les effets qui en dépendent sont remplacés par des
dégâts ou repoussés. Les scènes peintes `assets/vfx/hunter/` sont des scènes 2D : en 3D, chaque sort joue un effet
PixelFX du catalogue (`assets/vfx/pixelfx/`) en billboard, comme les monstres.

**Réutilisé tel quel** : `SpellData` (dégâts, recharge, portée, largeur, recul, couleur, `params`), icônes de l'arbre
(`HunterTreeSkin.icon`), textes `SPELL_*`, actions `spell_1` à `spell_4` et touches reconfigurables (`InputSetup`,
`Settings.bindings`, `KeyBindButton`), mode de contrôle et option d'aperçu (`Settings`), statistiques
`spell_damage` / `spell_cooldown` de l'arbre et des cartes.

## 2. Système de sorts actifs en 3D (lot 2)

| Élément | Réalisation |
|---|---|
| Emplacements | 4 (`DraftSpells.SLOTS`). Départ : toujours Taille et Lance (`default_spells`, décision du propriétaire du 15 novembre 2026), quel que soit l'arbre du profil ; ses variantes activées s'appliquent. Les autres s'apprennent par le choix de niveau (cartes « Nouveau sort », `draft3d/spells/learn_*.tres`, effet `DraftSpellEffect`), seulement s'il reste une place |
| Touches | actions `spell_1`…`spell_4` : flèches au clavier seul, A E R F (Q E R F en QWERTY) et clic gauche avec la souris, gâchettes et croix à la manette. Reconfigurables dans Options → **Touches et visée** (`draft3d/controls.gd`). Le déplacement lit aussi les actions (`move_*`, `dash`) |
| Visée | souris : curseur projeté sur le sol à la hauteur du Chasseur ; manette : stick droit ; clavier seul : ennemi visible le plus proche dans un cône de ±37° devant le Chasseur (direction du dernier déplacement), sinon 6 m devant. Anneau au sol sur le point visé ; avec l'option « aperçu », maintenir la touche montre la zone du sort et la relâcher lance |
| Règles 3D | « on touche ce que l'on voit » : ennemis de plain-pied (1 m) et visibles ; Rupture et Bond s'arrêtent devant le décor et se posent sur la navigation ; la Lance touche à sa hauteur |
| Recharges | `SpellData.cooldown` × `spell_cooldown` (arbre, cartes) ; un sort appris en partie est prêt après 1 s |
| HUD | barre de 4 cases en bas au centre (`draft3d/spell_bar.gd`) : icône, touche, voile de recharge et secondes, nom ; case libre visible ; sous le Chasseur, une petite case par sort qui se remplit pendant la recharge et s'allume quand il est prêt (`draft3d/spell_pips.gd`, demande du 15 novembre) |
| Bot | `auto_cast` : Taille si un ennemi est à portée, Lance et Rupture sur la cible du Trait, Bond pour se dégager quand 3 ennemis serrent le Chasseur |
| Réglages | `draft3d/tuning.tres`, groupe « Sorts » : échelle des zones, multiplicateur de Rupture, portée du Bond et de la Lance, vitesse de la Lance, visée au clavier, recharge d'un sort appris |

Tester : `godot --path . res://draft3d/main.tscn` (flèches ou A E R F selon le mode, choisi dans Options → Touches
et visée), ou `-- --bot` pour voir le bot lancer ses sorts. Essais : `tests/unit/test_draft3d_spells.gd`.

## 3. Améliorations des sorts (lot 3)

Cartes du choix de niveau (`draft3d/spells/*.tres`, `UpgradeData` + effet `DraftSpellEffect`), proposées seulement
pour un sort connu. Valeurs dans les données (`params`, `pct`), jamais dans le code.

| Sort | Variante A (une seule par sort) | Variante B | Rangs (×3 chacun) |
|---|---|---|---|
| Taille | **Tourbillon** : cercle complet, portée ×0,85 | **Estoc** : ligne de 9,6 m, demi-largeur 0,66 m, perce tout | Fil aiguisé (dégâts +20 %), Allonge (portée +15 %) |
| Lance | **Éventail** : 3 lances à 15°, 80 % des dégâts | **Surcharge** : maintenir charge jusqu'à ×2,5 en 1,2 s, relâcher tire | Pointe lourde (dégâts +20 %), Tir rapide (recharge −15 %) |
| Rupture | **Réaction** (adaptée, sans Marques) : 2 rebonds sur l'ennemi visible le plus proche, zone ×0,6, 50 % des dégâts | **Brasier** (adapté, sans Brûlure) : sol ardent 3 s, 15 % des dégâts toutes les 0,5 s | Charge instable (dégâts +20 %), Onde large (zone +20 %) |
| Bond | **Retour** : dans les 3 s après l'arrivée, la touche ramène au départ | **Impact** : onde ×2, ennemis ralentis de moitié 2 s (Entrave simplifiée, `Foe.slow`) | Retombée lourde (dégâts +25 %), Élan (recharge −15 %) |

Une variante activée dans l'arbre du profil (campagne v1) est prise d'office au départ pour un sort de départ
(`DraftUpgrades.variant_card`). Le bot prend les cartes au hasard et lance la Surcharge sans la charger.
Essais : `tests/unit/test_draft3d_spells.gd` (rangs, exclusivité, chaque variante).

## 4. Reste du pool v1 (lot 4, fait)

| Sort | Réalisation 3D | Variante A | Variante B (adaptée si Échos) | Rang |
|---|---|---|---|---|
| **Parade** | garde 0,4 s ; coup paré : 0 dégât, contre-attaque ×4 (rayon 2,1 m), étourdit 1,5 s (pas les boss), recharge remise à zéro | **Miroir** : les tirs ennemis à moins de 4 m repartent comme traits du Chasseur | **Garde longue** (remplace *Garde de meute*) : fenêtre ×2 | Contre puissant (dégâts +20 %) |
| **Singularité** | puits au point visé : attire les ennemis de plain-pied (pas les boss) 3 s, puis implose | **Horizon** : rayon +40 % | **Effondrement** : implosion ×2 au bout de 1,5 s | Puits profond (rayon +20 %) |
| **Mur de faille** | mur translucide de 3,9 m perpendiculaire à la visée, 4 s : arrête les ennemis et leurs tirs, laisse passer ceux du Chasseur | **Chaînes** : immobilise 1,5 s qui le touche | **Rempart ardent** : le toucher brûle | Mur durable (durée +25 %) |
| **Égide de faille** | bouclier de 25 % des PV max, 4 s (sans la part par Écho) | **Riposte** : onde de choc quand il cède | **Second souffle** (remplace *Partage*) : bouclier ×0,5, soin de 15 % | Égide prompte (recharge −15 %) |
| **Cristal réfracteur** | cristal 8 s au point visé : un Trait ou une Lance qui le traverse se divise (2 éclats à 60 %) | **Prisme double** : deux cristaux côte à côte | **Foyer** : les éclats visent l'ennemi le plus résistant | Cristal tenace (durée +25 %) |

Objets persistants : `draft3d/spell_world.gd` (puits, murs, cristaux). Garde et bouclier dans `DraftHunter.take_damage`.
Réglages : `draft3d/tuning.tres` (étourdissement, attraction, cristal). **Non repris** : *Appel de meute* et
*Permutation* (Échos) ; *Failles jumelles* repoussé (deux appuis, portails en relief, à valider d'abord).

## 5. Nouveaux sorts propres à la v2 (validés par le propriétaire le 15 novembre 2026, implantés)

Manques du pool actuel : un seul sort de **mobilité** (Bond), aucun **mono-cible** franc (la Lance est une ligne),
pas de **zone sur la durée** à poser, pas de **contrôle** dur de groupe hors Mur et Singularité. Noms et effets
originaux, chiffres indicatifs.

| Rôle | Sort proposé | Effet | Améliorations proposées |
|---|---|---|---|
| Mono-cible | **Marque du traqueur** | Désigne l'ennemi visé (élites et boss d'abord) pour 6 s : il subit +30 % de dégâts et le Trait le vise en priorité | *Exécution* : sous 20 % de PV, la marque l'achève en explosant · *Traque* : à sa mort, la marque saute sur l'ennemi le plus proche · rang : dégâts subis +10 % |
| Mono-cible / mobilité | **Fente du vide** | Le Chasseur fend jusqu'à 6 m vers la visée et frappe fort la première cible traversée (invulnérable pendant la fente) | *Double fente* : relançable une fois dans les 2 s · *Fente perçante* : frappe tout sur la ligne · rang : dégâts +20 % |
| Mobilité | **Pas de faille** | Téléportation instantanée de 5 m vers la visée ; l'ombre laissée au départ éclate 1 s plus tard | *Deux charges* · *Ombre piégée* : l'éclat ralentit 2 s · rang : recharge −15 % |
| Contrôle | **Onde de stase** | Cône de 90° devant le Chasseur (5 m) qui fige les ennemis 1,5 s (boss : ralentis de moitié) | *Éclats de stase* : les ennemis figés subissent +20 % de dégâts · *Onde circulaire* : 360°, portée −30 % · rang : durée +20 % |
| Zone | **Pluie d'éclats** | Zone de 3 m au point visé où tombent des éclats pendant 3 s (dégâts réguliers) | *Orage* : la zone suit le Chasseur · *Concentration* : zone −40 %, dégâts ×1,6 · rang : zone +20 % |
| Défensif | **Voile de cendre** | Nuage de 3 m autour du Chasseur pendant 4 s : les tirs ennemis qui y entrent sont détruits, les ennemis dedans ralentis | *Voile mobile* : le nuage suit le Chasseur · *Contrecoup* : chaque tir détruit rend 2 PV · rang : durée +25 % |

**Réalisation** : données `draft3d/spells/data/*.tres` (`SpellData`, hors des données de la campagne, lues par
`DraftSpells.spell`), effets et état dans `draft3d/rift_spells.gd` (`DraftRiftSpells`), cartes `draft3d/spells/*.tres`
(un « Nouveau sort », deux variantes, un rang par sort ; 64 cartes de sort en tout), textes `SPELL3D_*` et
`UPGRADE3D_*`. Icône de la barre : image de leur effet PixelFX (`params.icon_fx`). Mécaniques ajoutées : exposition
des ennemis (`Foe.expose`, dégâts subis augmentés), fente sans saut (`DraftHunter.leap_to` à hauteur nulle),
charges (Deux charges), zones qui suivent le Chasseur (Orage). Ajustements de réalisation : Exécution inflige
3 × les dégâts du sort à un boss au lieu de l'achever ; Onde de stase utilise l'effet de givre (`frost_nova`).
Essayer : `godot --path . res://draft3d/main.tscn -- --spells=hunter_mark,void_rend,rift_step,stasis_wave`
(option `--spells=`, 4 sorts au plus). Capture : `docs/previews/sorts-actifs-v2/nouveaux_sorts.webp`.

## 6. Animations peintes de la v1 et icônes (15 novembre 2026)

Demande du propriétaire : les sorts gardent les animations de la v1 et leurs images.
- **Animations** : `draft3d/spell_vfx.gd` (`DraftSpellVfx`) joue les scènes 2D de Codex (`assets/vfx/hunter/`,
  manifeste `vfx.hunter.*`) à plat sur le sol 3D. Chaque scène est rendue dans une petite vue transparente, à
  l'échelle du monde (1 unité v1 = 0,03 m), orientée dans la direction du sort, avec la variante de la carte prise
  (Tourbillon, Estoc, Éventail, Surcharge, Réaction, Brasier → « inferno », Retour, Impact, Miroir, Horizon,
  Effondrement, Chaînes, Rempart ardent, Riposte, Second souffle → « sharing », Prisme double, Foyer).
  Neuf sorts en ont une : Taille, Lance (le trait de jeu devient invisible, l'animation dessine la lance), Bond,
  Parade (suit le Chasseur, éclat au coup paré), Rupture, Cristal, Singularité, Mur (le volume translucide reste,
  plus discret), Égide (suit le Chasseur). Les six sorts propres à la v2 gardent leurs effets PixelFX.
- **Icônes** : celles de l'arbre v1 (`icon.hunter.*`), sinon une image de l'effet PixelFX (sorts v2), dans la barre,
  dans les cases de recharge sous le Chasseur et sur les cartes de sort du choix de niveau (`DraftSpellBar.icon_for`).
- Vérification : option `--cast-at=T` (tous les sorts partent à T secondes). Capture :
  `docs/previews/sorts-actifs-v2/animations_v1.webp`.
