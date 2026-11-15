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
| Emplacements | 4 (`DraftSpells.SLOTS`). Départ : sorts équipés dans l'arbre du profil et raccordés, sinon Taille et Lance (`default_spells`). Les autres s'apprennent par le choix de niveau (cartes « Nouveau sort », `draft3d/spells/learn_*.tres`, effet `DraftSpellEffect`), seulement s'il reste une place |
| Touches | actions `spell_1`…`spell_4` : flèches au clavier seul, A E R F (Q E R F en QWERTY) et clic gauche avec la souris, gâchettes et croix à la manette. Reconfigurables dans Options → **Touches et visée** (`draft3d/controls.gd`). Le déplacement lit aussi les actions (`move_*`, `dash`) |
| Visée | souris : curseur projeté sur le sol à la hauteur du Chasseur ; manette : stick droit ; clavier seul : ennemi visible le plus proche dans un cône de ±37° devant le Chasseur (direction du dernier déplacement), sinon 6 m devant. Anneau au sol sur le point visé ; avec l'option « aperçu », maintenir la touche montre la zone du sort et la relâcher lance |
| Règles 3D | « on touche ce que l'on voit » : ennemis de plain-pied (1 m) et visibles ; Rupture et Bond s'arrêtent devant le décor et se posent sur la navigation ; la Lance touche à sa hauteur |
| Recharges | `SpellData.cooldown` × `spell_cooldown` (arbre, cartes) ; un sort appris en partie est prêt après 1 s |
| HUD | barre de 4 cases en bas au centre (`draft3d/spell_bar.gd`) : icône, touche, voile de recharge et secondes, nom ; case libre visible |
| Bot | `auto_cast` : Taille si un ennemi est à portée, Lance et Rupture sur la cible du Trait, Bond pour se dégager quand 3 ennemis serrent le Chasseur |
| Réglages | `draft3d/tuning.tres`, groupe « Sorts » : échelle des zones, multiplicateur de Rupture, portée du Bond et de la Lance, vitesse de la Lance, visée au clavier, recharge d'un sort appris |

Tester : `godot --path . res://draft3d/main.tscn` (flèches ou A E R F selon le mode, choisi dans Options → Touches
et visée), ou `-- --bot` pour voir le bot lancer ses sorts. Essais : `tests/unit/test_draft3d_spells.gd`.
