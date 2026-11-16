# Gameplay v2 : audit et architecture (arsenal, récompenses, combos)

Session « Gameplay », 16 novembre 2026. Consignes : issue #193 et `docs/design/GAMEPLAY_COMBOS_2P5D.md` (PR #194,
référence principale). Ce document relève l'état réel de `draft3d/`, les écarts avec ces décisions, l'architecture
retenue et l'ordre des lots. Il ne déclare rien comme fait : l'état de chaque lot est tenu dans la section 5.

## 1. État réel de `draft3d/` (main, 16 novembre)

| Sujet | Existant | Écart avec la référence 2,5D |
|---|---|---|
| Emplacements | `DraftSpells.slots` : 4 cases fixes, `learn()` refuse quand c'est plein | 4 + un 5e légendaire ; acquisition toujours possible avec remplacement |
| Recharges | `cooldowns` **par indice de case** | par **identifiant de sort**, conservées à l'échange |
| Réserve | aucune | réserve d'expédition, échange depuis la pause |
| Variantes | une seule par sort (`variants[id]`, groupe exclusif `variant_<sort>`), réglages `variant_params[id]` | **2 mutations** par sort, incompatibilités explicites, remplacement explicite quand les 2 cases sont prises |
| Rangs | cartes MODIFY (+20 % dégâts, −15 % recharge…) | hors du tirage normal (statistiques brutes) |
| Cartes de statistique | 12 cartes (`data/upgrades/` + `draft3d/upgrades/`) toujours tirées | retirées du tirage ; progression de base automatique avec le niveau |
| Raretés | aucune | Commun / Rare / Épique / Légendaire, poids et anti-frustration en données |
| Passifs | aucun en partie (l'arbre v1 n'est plus appliqué aux sorts, seulement lu pour ses statistiques) | passifs techniques sans plafond : Ruée tranchante, Sillage du vide, Contre-taille, Ancre |
| XP | courbe v1 (`BalanceConfig.xp_to_next`) : un niveau toutes les 20-40 s | 8 à 12 choix en 20-25 min, réglable |
| Choix de niveau | 3 cartes, touches 1/2/3, pause du combat ; pas de choix différé dans la v2 | inchangé ; ajout du choix de la case à remplacer |
| Départ | toujours Taille + Lance (`default_spells`) | 2 sorts choisis au menu parmi les débloqués |
| Déblocages | écran `draft3d/unlock_screen.gd` fusionné (session « Interface »), **mais `draft3d/unlocks.gd` absent** : bouton grisé | `DraftUnlocks` à écrire (API de `DEBLOCAGE_V2.md`, double `tools/draft3d_fake_unlocks.gd`) |
| Statuts | `Foe.slow` (ralenti / immobilisé), `Foe.expose` (dégâts subis augmentés) ; **ni Marques, ni Fracture, ni Brûlure** | les combos s'appuient sur des événements réels (cibles touchées, puits actif, traversée du cristal) |
| Combos | aucun ; la réfraction Cristal + Trait/Lance existe déjà (`DraftSpellWorld.refract`) | 3 combos MVP |
| Pause | Reprendre / Options / Recommencer / Menu / Quitter (`DraftHud.show_pause`) | + Arsenal (équipés, réserve, mutations) |
| 5e touche | actions `spell_1`…`spell_4` (InputSetup, partagé avec la v1) | action `spell_5` créée par la v2 sans toucher au code v1 |

## 2. Conflits et décisions de réalisation

1. **Rangs et cartes de statistique** : retirés du tirage (`tuning.stat_cards_in_pool = false`), données conservées.
   Les mutations gardent leurs réglages chiffrés internes.
2. **Groupe exclusif `variant_<sort>`** : remplacé par une liste d'incompatibilités par mutation (Tourbillon ⟂ Estoc,
   Éventail ⟂ Surcharge en attendant un essai de cumul). Les autres paires sont cumulables.
3. **Réglages de mutation** : `param(data, key)` lit aujourd'hui les réglages de LA variante ; avec deux mutations les
   clés se chevauchent (Réaction et Brasier ont tous deux `damage`) : les réglages sont lus **par mutation**.
4. **Arbre v1** : plus aucune lecture en v2 une fois `DraftUnlocks` en place (direction C) ; les statistiques de
   l'arbre cessent de s'appliquer, ce qui est conforme à « pas de réintroduction de l'arbre ».
5. **Effets persistants à l'échange** (cristal, mur, puits, brasier) : ils vont au bout de leur durée ; un sort en
   réserve n'est jamais ingrédient d'un combo (contrôle à l'instant du déclenchement).
6. **Marques** : pas de statut réintroduit. Exécution prismatique utilise les cibles **réellement touchées par la
   Lance** dans la fenêtre (`Foe.prism_hit_until`).
7. **Textes** : nouvelles clés `REWARD3D_*`, `MUTATION3D_*` réutilisant les noms de variantes existants, `PASSIVE3D_*`,
   `COMBO3D_*`, `ARSENAL3D_*`, `CURRENCY3D_*`.

## 3. Architecture

| Élément | Fichier | Rôle |
|---|---|---|
| `DraftArsenal` | `draft3d/arsenal.gd` | état d'expédition : sorts possédés (id → mutations), équipés par case (4, 5 avec le légendaire), réserve, recharges **par id** ; `acquire`, `equip(id, case)`, `stash`, `add_mutation(id, mut, remplace)` |
| `DraftSpells` | `draft3d/spells.gd` | exécution des sorts ; lit l'arsenal (cases, mutations) ; `has_mutation(data, m)`, `mutation_param(data, m, clé)` |
| `DraftCard` | `draft3d/card.gd` (hérite de `UpgradeData`) | carte de récompense : famille (sort, mutation, passif, règle), rareté, incompatibilités |
| `DraftRewards` | `draft3d/rewards.gd` | tirage de 3 cartes éligibles : raretés pondérées (`tuning`), anti-frustration, filtre (sort non possédé, mutation utile, passif non pris, 5e case unique) |
| `DraftPassives` | `draft3d/passives.gd` | passifs techniques branchés sur la Ruée, les coups esquivés et les morts d'ennemis |
| `DraftCombos` | `draft3d/combos.gd` | journal des lancers et des contacts, détection des 3 combos MVP, fenêtres et plafonds en données, retour visuel et sonore |
| `DraftUnlocks` | `draft3d/unlocks.gd` | déblocages permanents (API de `DEBLOCAGE_V2.md`), monnaie, sorts de départ, filtre du tirage |
| Interface | `draft3d/hud.gd`, `draft3d/arsenal_panel.gd` | choix de la case à remplacer, Pause → Arsenal, raretés sur les cartes, bandeau de combo |

Réglages (`draft3d/tuning.tres`) : multiplicateur d'XP, croissance automatique par niveau (PV, dégâts), poids des
raretés, anti-frustration, fenêtres et plafonds des combos, effets des passifs.

## 4. Ordre des lots (une branche et une PR par lot, sans fusion automatique)

1. **Audit et architecture** (ce document).
2. **Arsenal et réserve** : `DraftArsenal`, recharges par id, acquisition avec remplacement, Pause → Arsenal,
   `DraftUnlocks` et 2 sorts de départ choisis au menu.
3. **Récompenses et progression** : `DraftCard`, raretés, 2 mutations par sort et incompatibilités, passifs, 5e case
   légendaire (`spell_5`), cartes de statistique retirées, XP ralentie, croissance automatique.
4. **Combos MVP** : Exécution prismatique, Déluge prismatique, Lame gravitationnelle.
5. **VFX et validation** : fiches visuelles pour ChatGPT (section 6 de ce document), intégration des fichiers fournis,
   captures en jeu.

Les lots s'empilent (chacun part de la branche du précédent) tant que les PR ne sont pas fusionnées.

## 5. État des lots

| Lot | État |
|---|---|
| 1 | Fait : ce document |
| 2 | Fait (PR à valider) : arsenal dans `DraftSpells` (`owned`, `reserve()`, `equip`, `stash`, `add_slot`, recharges des sorts en réserve par id, aucune remise à zéro ni doublon), acquisition toujours possible (case libre, sinon choix de la case à remplacer ou réserve : `draft3d/arsenal_panel.gd`), Pause → Arsenal, action `spell_5` (Entrée, G, croix bas), `DraftUnlocks` (`draft3d/unlocks.gd`, sauvegarde `user://draft3d_unlocks.json`, gain en fin de partie, filtre du tirage, 2 sorts de départ), arbre v1 plus appliqué. Essais `tests/unit/test_draft3d_arsenal.gd`. Capture `docs/previews/gameplay-v2/arsenal.webp`. **Reste** : touche du 5e sort non reconfigurable (les touches personnalisées passent par `InputSetup.REBINDABLE`, partagé avec la v1) |
| 3 à 5 | À faire |
