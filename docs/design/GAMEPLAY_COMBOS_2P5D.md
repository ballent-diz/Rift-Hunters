# Rift Hunters — Référence commune Gameplay & Visuels (2,5D)

**Version :** 0.1 — 16 novembre 2026  
**Statut :** décisions du propriétaire validées en discussion ; implémentation et équilibrage **non réalisés par ce document**.  
**Références existantes :** [SORTS_ACTIFS_V2.md](SORTS_ACTIFS_V2.md), [DEBLOCAGE_V2.md](DEBLOCAGE_V2.md), [ARBRE_DU_CHASSEUR.md](ARBRE_DU_CHASSEUR.md), [COMPETENCES_ET_BUILDS.md](COMPETENCES_ET_BUILDS.md), [issue #193](https://github.com/ballent-diz/Rift-Hunters/issues/193).

> **Priorité des décisions :** cette référence (16/11/2026) prime sur les anciennes propositions **uniquement pour le gameplay de la nouvelle campagne `draft3d/`**. Ne pas altérer la campagne 2D archivée. Les paramètres chiffrés marqués *prototype* sont à tester et non à considérer définitifs.

## 1. Vision

Rift Hunters est un **Action-Survivor / Roguelite en 2,5D** : environnements 3D, personnages et ennemis en sprites 2D, compétences déclenchées manuellement, attaque de base automatique. Le plaisir central réside dans le **choix de sorts**, leurs **mutations**, leurs **passifs transformants** et la découverte puis l'exécution de **combos techniques**. Une montée de niveau doit changer concrètement ce que le joueur peut faire, et non offrir des bonus numériques génériques.

### Invariants validés
- Monstres → XP → niveau → **un choix parmi trois propositions**, avec système de choix différé si conservé dans `draft3d/`.
- Attaque principale automatique ; Ruée/esquive manuelle ; sorts équipés déclenchés manuellement, avec visée existante.
- Le joueur **choisit deux sorts de départ**, avant la partie, parmi ceux débloqués de façon permanente dans le menu. Ces deux sorts de départ n'ont **pas de rareté**.
- **4 emplacements de sorts actifs** au départ ; **5e emplacement** accessible **uniquement par récompense légendaire**, jusqu'à la fin de l'expédition.
- Un sort acquis quand tous les slots sont pleins peut **remplacer un équipé**. Le sort remplacé reste dans la **réserve de l'expédition, accessible en pause** et rééquipable ; garder les mutations individuelles lors des changements. Les sorts en réserve **ne déclenchent pas leurs combos**.
- **2 mutations maximum par sort** ; une mutation change la façon de jouer. Incompatibilités explicites entre mutations si leurs comportements se contredisent. Quand les deux cases sont pleines, remplacement explicite possible, jamais écrasement silencieux.
- Passifs techniques **plus libres**, sans limite initiale : ils modifient attaque, déplacement, timings, effets, combos. Pas de cartes de bonus de stats ordinaires.
- PV/dégâts de base peuvent évoluer automatiquement avec le niveau afin d'assurer l'équilibrage, sans choix de « +X % ».
- Rareté des **récompenses trouvées** : **Commun, Rare, Épique, Légendaire**. Rareté = importance/mécanique, pas seulement multiplicateur de dégâts.
- Niveau plus lent : cible *prototype* de **8 à 12 choix majeurs par expédition de 20–25 min** ; ajuster aux durées réelles des cartes. Trois cartes proposées, toutes éligibles et utiles.
- Combos **disponibles immédiatement** lorsque les conditions de sorts équipés et d'exécution sont réunies ; **ne pas faire acheter une carte pour débloquer le combo**.
- Les Échos sont **hors système pour l'instant** ; un éventuel compagnon automatique sur drop rare sera traité plus tard, sans bloquer la conception actuelle.

## 2. Boucle joueur, deux temporalités

**Entre les parties :** gagner une monnaie permanente via les runs ; menu « Déblocages » v2 pour ouvrir des sorts et leurs mutations possibles ; sélectionner **2 sorts de départ**. Respecter la direction C de `DEBLOCAGE_V2.md` : **pas de réintroduction de l'arbre v1 et de ses points**. Les profils/builds antérieurs restent à préserver si nécessaire pour compatibilité, mais ne doivent pas imposer l'arbre à `draft3d/`.

**Pendant la partie :** éliminer → récupérer XP → niveau ; consulter trois propositions de récompense ; obtenir sort, mutation, passif ou changement exceptionnel de règle ; équiper/remplacer depuis un choix, reconfigurer ensuite depuis **Pause → Arsenal / Réserve**. Tout ce qui est acquis **pendant le run** est remis à zéro au run suivant, sauf déblocages permanents et mémoire des recettes de combos si une encyclopédie est ajoutée plus tard.

**Remplacement :** réserve d'inventaire par ID de sort, mutations liées à cet ID, pas au slot. Cooldown conservé par **ID du sort** à travers tout swap, y compris pendant une pause. Ne pas permettre de reset de recharge ou duplication de sort. Une entité déjà placée (cristal, mur, etc.) suit les règles normales de durée ; aucun nouvel effet n'est créé par swap. Aucun effet d'un sort en réserve ne sert d'ingrédient de combo après déséquipement ; trancher explicitement le traitement des effets persistants déjà lancés avant remplacement (recommandation : ils s'achèvent, mais ne créent pas de nouvelles fusions avec un sort désormais absent).

## 3. Familles de choix au level-up

| Famille | Exemple | Critère d'intérêt |
|---|---|---|
| **Nouveau sort** | Lance prismatique / Onde de stase | Nouveau bouton de combat et nouvelles associations |
| **Mutation** | Éventail, Surcharge, Prisme double | Transformation visible d'un sort possédé ; **2 par sort** |
| **Passif technique** | Ruée tranchante, Sillage du vide | Modifie une action, une interaction ou une réaction |
| **Altération de règle** | Surcharge d'arsenal | Change durablement le fonctionnement du run (jusqu'à sa fin) |

Exclure les simples cartes *+20 % dégâts, +15 % zone, −15 % cooldown, +PV* du pool normal `draft3d/`. Elles peuvent subsister dans les ressources anciennes de la v1, mais ne doivent plus être tirées en v2. Conserver éventuellement des ajustements numériques *à l'intérieur* d'une mutation fonctionnelle pour l'équilibrage.

**Raretés :** Commun = décision simple à impact direct ; Rare = changement comportemental important ; Épique = mutation structurante ; Légendaire = exceptionnel (ex. 5e slot). Les chances de tirage, seuils et anti-frustration doivent être **configurables**, sans garantie implicite. Pas de rareté sur les deux sorts de départ ; les nouveaux sorts obtenus en run sont récompenses de rareté déterminée par la carte.

**Rythme proposé, non figé :** ~8–12 choix en 20–25 min. Éviter de retarder excessivement le premier choix. Le choix différé existant doit rester utilisable si cela améliore la nervosité.

## 4. Sorts existants : audit à respecter

**IMPORTANT :** la v2 contient **15 sorts déjà conçus/implantés** selon `SORTS_ACTIFS_V2.md`, pas seulement neuf. **Ne rien supprimer** sans validation. Le tableau ci-dessous désigne **les neufs sort historiques les plus exploitables**, pas une exclusivité de pool.

| ID historique | Sort | Fonction actuelle en v2 | Mutations existantes proposées comme socle |
|---|---|---|---|
| `cleaving_slash` | Taille fendante | Coup de mêlée / arc | **Tourbillon** (360°) / **Estoc** (ligne) — incompatibles sur la forme |
| `prismatic_lance` | Lance prismatique | Tir perçant | **Éventail** / **Surcharge** — tester cumul avec charge prolongée |
| `rupture` | Rupture | Explosion de zone ; **Marques v1 absentes en v2** | **Réaction** (rebonds adaptés v2) / **Brasier** (zone brûlante) |
| `refracting_crystal` | Cristal réfracteur | Multiplie Trait/Lance qui traversent | **Prisme double** / **Foyer** |
| `singularity` | Singularité | Attraction + implosion | **Horizon** / **Effondrement** |
| `rift_leap` | Bond de faille | Mobilité et onde à l'arrivée | **Retour** / **Impact** |
| `parry` | Parade | Fenêtre de contre-attaque | **Miroir** / **Garde longue** (v2, pas Garde de meute) |
| `rift_wall` | Mur de faille | Coupe l'espace et les tirs | **Chaînes** / **Rempart ardent** |
| `aegis` | Égide de faille | Défense personnelle | **Riposte** / **Second souffle** (v2 sans Échos) |

**Six sorts propres à la v2 à conserver**, déjà documentés et à considérer pour les synergies : **Marque du traqueur** (`hunter_mark`), **Fente du vide** (`void_rend`), **Pas de faille** (`rift_step`), **Onde de stase** (`stasis_wave`), **Pluie d'éclats** (`shard_rain`), **Voile de cendre** (`veil`). Reprendre leurs IDs/variantes exactes depuis `draft3d/spells/data/`, `draft3d/rift_spells.gd`.

**Hors pool actuel :** `pack_call` Appel de meute, `swap` Permutation (dépendent des Échos) ; `twin_rifts` Failles jumelles (reporté explicitement en v2 pour complexité 3D). Conserver les ressources historiques, ne pas les retirer.

**Mutations :** commencer par les variantes qui modifient vraiment les actions. Certaines variantes v2 restent **exclusives** (Tourbillon vs Estoc) même si le personnage dispose de deux cases de mutation ; les deux cases **ne garantissent pas** qu'une paire incompatible fonctionne ensemble. Quand deux variantes ont une compatibilité incertaine (notamment Éventail + Surcharge), instrumenter et tester, ne pas promettre un cumul sans résultat.

## 5. Combos techniques : principes et première sélection

Trois familles à terme : **réaction** (statuts/ordre), **technique** (placement et timing), **fusion** (combo très spécial). **Pour le MVP : combos à 2 sorts**, observables, déclenchés par actions réelles, et surtout pas simplement `damage *= 1.2`.

**Garde-fous communs :**
- Ingrédients tous **équipés au moment de l'enchaînement**, y compris après swaps.
- Fenêtre indicative de **2 secondes** (par combo, donnée éditable) ; combo exige la bonne séquence/position/contact.
- Aucun trigger si sort manquant, en réserve, échec de condition, fenêtre expirée ; ne pas réinitialiser l'historique de casts par swap pour fabriquer un combo.
- Réactions et effets visuels plafonnés pour éviter explosions combinatoires ; bosses, élites et hordes fonctionnent avec adaptations explicites.
- Interface et feedback distinctifs : nom du combo, signature VFX, son/retour d'impact, sans écran qui masque le combat.

| Priorité | Combo de travail | Pré-requis | Effet technique proposé et état |
|---|---|---|---|
| **MVP 1** | **Exécution prismatique** | Lance prismatique puis Rupture, cible touchée, fenêtre | Rupture supplémentaire localisée sur cible affectée ; **Marques v1 absentes**. Utiliser historique de cible touchée ou réintroduire un statut simple, mais pas prétendre que la marque existe déjà |
| **MVP 2** | **Déluge prismatique** | Cristal réfracteur puis tir de Lance qui traverse le cristal | Réfraction déjà existante, la rendre identifiable comme combo (feedback, variation contrôlée, seuil de projectiles) |
| **MVP 3** | **Lame gravitationnelle** | Singularité active + Taille fendante dans sa zone | Onde secondaire de choc / Fracture appliquée aux ennemis réellement présents |
| Après MVP | **Contre-faille** | Parade réussie puis Taille fendante ou Bond ≤2 s | Riposte transformée ; choisir le meilleur couple selon tests |
| Après MVP | **Traversée entravante** | Mur de faille + Bond de faille, interaction spatiale | Onde / effet de contrôle à l'arrivée, sans traversée des collisions |
| Plus tard | **Stase d'éclats** | Onde de stase + Pluie d'éclats (sorts v2) | Éclats réagissent aux ennemis immobilisés |
| Plus tard | **Traque du vide** | Marque du traqueur + Fente du vide (sorts v2) | Fente spéciale sur cible exposée |

**Lot 6 (implémenté, 17 novembre 2026)** : les propositions « après MVP » et « plus tard » sont devenues Contre-faille
(Parade → Taille), Rempart fracassant (Bond près d'un Mur), Tempête immobile (Stase + Pluie) et Chasse dimensionnelle
(Marque + Fente), plus Rupture du traqueur, Rebond spectral, Prison de faille, Égide vengeresse et Convergence
prismatique (premier combo à 3 sorts). Détail et valeurs : `GAMEPLAY_V2_ARCHITECTURE.md`, lot 6.

**Les combos sont automatiquement *possibles* lorsque le joueur possède les deux sorts équipés. Ils ne sont pas automatiquement *déclenchés* : timing, ordre et placement font partie du gameplay.** Les combos à 3 sorts / ultime restent une extension future, pas une obligation du MVP.

## 6. Passifs techniques à prototyper

Réutiliser en priorité les concepts historiques documentés dans `ARBRE_DU_CHASSEUR.md`, en évitant tout dépendance Écho : **Ruée tranchante** (Ruée blesse les cibles traversées), **Contre-taille** (esquive au bon moment transforme le prochain sort), **Sillage du vide** (Ruée laisse une traînée entravante), **Ancre** (mort sous contrôle crée petite Singularité). **Propagation** uniquement si statut Marques effectivement ajouté à la v2. Passifs cumulables sans plafond initial, mais chaque offre doit être pertinente pour le build actuel et ses actions.

## 7. Responsabilités — propriétaire, ChatGPT, Claude Code

| Responsable | Produit / décision |
|---|---|
| **Propriétaire** | Valide le ressenti, le design final, la rareté, la lisibilité et les assets ; demande les changements |
| **ChatGPT : direction artistique / production d'images** | Fiche visuelle de chaque sort/mutation/combo ; icônes, textures, effets 2D, planches d'animation si nécessaires ; référence couleurs/lumière, dimensions et transparence selon pipeline ; revoir les assets à partir des captures de Godot |
| **Claude Code : implémentation Gameplay & intégration** | Inventaire des mécaniques existantes ; ressources, états, progression XP, draft de choix, swaps/réserve, mutations, passifs, raretés, combo engine, triggers, cooldowns, HUD/pause, intégration des images/VFX et tests 2,5D |
| **Codex (optionnel si besoin)** | Travail graphique sur scènes Godot, validation/pipeline art, *sans* modifier le gameplay ; coordination explicite par PR |

**Contrat de livraison visuelle ChatGPT → Claude** (une fiche par sort/effet) : ID stable existant ; rôle ; déclencheur d'effet (cast, travel, hit, impact, persistent, end, combo) ; découpage des frames si sprite sheet ; taille cellule, nombre de frames, vitesse, point d'ancrage, direction de lecture ; PNG alpha transparent sauf consigne contraire ; palette/lumière conformes à `docs/ART_BIBLE.md` ; fichiers source + aperçu ; aucun effet de gameplay déduit du visuel. **Ne jamais inventer une image déjà présente** : vérifier l'existant et demander une validation esthétique avant de la remplacer. En 2,5D, vérifier plan au sol, billboarding, profondeur, taille réelle et occultation par le décor lors du raccord Godot.

**Contrat Claude → ChatGPT/propriétaire** : pour chaque effet nécessaire, fournir un ID technique, nom, durée réelle, forme spatiale (point, cône, arc, sol, projectile), états cast/hit/end, dimensions 3D, points de contact, contraintes de visibilité/collision, variante/mutation, palette et nombre de frames souhaité ; ne pas demander « une animation complète » sans format précis. Tester les VFX avec le gameplay effectif, pas uniquement dans un aperçu isolé.

## 8. Règles d'implémentation et conflits connus

- La v2 est dans **`draft3d/`** ; éviter de suivre par erreur les anciennes valeurs/branches du jeu 2D.
- `draft3d/spells.gd` a un état `SLOTS=4`, recharges **par indice de slot**, acquisition refusée quand plein, **une variante exclusive par sort**, rangs numériques. Toutes ces limites sont **à revoir explicitement** pour le nouveau gameplay.
- `docs/design/DEBLOCAGE_V2.md` indique encore « passifs laissés de côté » : décision antérieure à ce document. Cette refonte **réintroduit des passifs techniques en partie**, pas nécessairement dans les achats permanents. S'aligner sur l'évolution du code en cours plutôt qu'écraser le travail d'autres sessions.
- Le code et la documentation v2 indiquent que **Marques/Fracture/Brûlure/Racines** du système v1 ne sont pas entièrement portés en v2. **Ne jamais décrire leurs interactions comme déjà actives**. Implémenter un équivalent minimal si requis, avec tests, sinon adapter les combos aux événements réellement disponibles.
- Ne pas créer de raccourci clavier 5e slot sans vérifier les contrôles reconfigurables et la manette ; prévoir son HUD et sa réinitialisation de fin de run.
- Les règles se codent sur **branche Claude dédiée, PR vers main, CI verte, validation par le propriétaire**, conformément à `AGENTS.md`. Documentation seule ne prouve pas une fonctionnalité réalisée.

## 9. Parcours de développement conseillé

1. **Audit état courant / interfaces** des sessions Gameplay, Interface, DraftUnlocks et tests ; relevé des conflits de design. Aucun changement sauvage de main.
2. **Arsenal/réserve et remplacement**, avec sauvegarde d'état de run (pas de permanence), mutations/cooldowns attachés à l'ID et interface Pause.
3. **Nouvelles cartes et progression** : pool sans stats, raretés, mutations (maximum deux), passifs, cinquième slot, cadence XP ajustable.
4. **Trois combos MVP** : Exécution prismatique, Déluge prismatique, Lame gravitationnelle, avec vrai déclenchement et feedback.
5. **Couverture** : tests d'acquisition avec slots pleins, remplacement/reprise, deux mutations, exclusions, éligibilité/recharges, 5e slot, expiration des fenêtres et non-déclenchement avec sort en réserve.
6. **Échanges visuels et raccord** : fiches assets de ChatGPT puis intégration des fichiers fournis/validés ; captures en contexte 2,5D ; logs et validation utilisateur.

**Tests** : `godot --headless --import --path .` après modifications pertinentes, `tools/run_tests.sh` ciblé et suite complète pour les PR de code, exécution du vrai `draft3d/main.tscn`. Tous les textes UI ont des clés FR/EN dans `i18n/strings.csv`. Pas de fusion automatique avant CI verte et revue.

## 10. Critères de réussite vérifiables

- Le joueur part avec **2 sorts choisis** dans son menu, attaque auto et esquive opérationnelles.
- En run, un nouveau sort **s'obtient même lorsque les 4 slots sont pleins**, via un choix explicite de remplacement ; ancien dans la réserve ; **swap pause** réversible, pas de cooldown reset ni de duplications.
- Une mutation transforme réellement le sort, il est impossible de dépasser **2 mutations**, et une mutation incompatible ne peut être équipée simultanément sans explication.
- Les cartes ordinaires de +stats sont absentes du tirage v2 ; les quatre raretés affichées et utiles ; 5e slot **légendaire, temporaire, une seule fois**, manette incluse.
- **Trois combos en jeu réellement activables**, impossibles avec un ingrédient en réserve, vérifiés à l'intérieur et à l'extérieur des fenêtres.
- Les Échos sont absents ; le Chasseur reste viable sans combo ; les combats de boss et les hordes restent lisibles et performants.
- Chaque PR précise **fait / non fait / données/contrats / tests réels / captures** ; tout paramètre de cadence est réglable en données.

## 11. Fiche standard pour créer un visuel de compétence

```yaml
id: existing_spell_or_combo_id
nom_fr: ""
nom_en: ""
type: cast | projectile | impact | persistent | combo | icon
sorts_sources: []
condition_gameplay: ""
animation:
  format: PNG alpha / sprite sheet
  frame_width: à déterminer avec Claude
  frame_height: à déterminer avec Claude
  frames: à déterminer avec Claude
  fps: à déterminer avec Claude
  looping: false
  anchor: à déterminer avec Claude
palette_et_lumiere: docs/ART_BIBLE.md
usage_2p5d: billboard / sol / particule / UI
notes_collisions: les visuels ne portent aucune collision ni règle de dégâts
etat_validation: a_produire | a_valider | valide
```

## 12. Points ouverts, à tester sans en faire des décisions définitives

- Durée exacte des runs, quantité d'XP et rythme des level-ups selon les cartes.
- Taux de rareté, poids selon le build, fréquence des légendaires.
- Compatibilité exacte de chaque paire de mutations, dont Éventail+Surcharge.
- Limites de passifs en cas de builds abusifs et budget d'effets 3D.
- Si les sorts persistants déjà lancés peuvent terminer leur durée après déséquipement (recommandation oui, sans activer de combos inéligibles).
- Ordre, ratio et amplitude des combos contre boss.
- Nom final des combos et de la monnaie permanente.
- Réintroduction éventuelle d'Échos **uniquement sur nouvelle décision du propriétaire**.
