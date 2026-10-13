# Rift Hunters — Game Design Document (v0.1, prototype)

> Document vivant. Les valeurs chiffrées sont des points de départ : la source de vérité
> est dans `data/` (équilibrage centralisé).

## 1. Identité

**Pitch** : le monde est fissuré par des **Failles**. Elles vomissent des **Corrompus**,
des créatures dévorées par le vide. Le joueur est un **Chasseur de Failles** : il scelle des
pactes avec des **Échos**, créatures nées de la résonance entre les mondes. Il les combine
pour survivre aux vagues, puis affronte les **Dévoreurs**, les colosses qui gardent chaque Faille.

**Piliers**
1. *Lisibilité sous pression* : même à 300 ennemis, on voit son personnage, les projectiles
   dangereux et les télégraphes.
2. *Le build comme langage* : statuts (Fracture, Marque, Brûlure, Entrave) et techniques
   s'enchaînent ; les synergies sont des interactions, pas des +%.
3. *Commander, pas seulement survivre* : les Échos attaquent seuls, mais le joueur déclenche
   leurs Techniques (touches 1-2-3) et désigne un point de focus (clic droit).
4. *Progression de découverte* : on débloque des possibilités (évolutions, variantes,
   emplacements d'équipe, mutations) plus que des statistiques.

**Ce qui nous distingue du survivor-like classique** : techniques actives des alliés,
ordre de focus, langage de statuts partagé, évolutions à embranchements qui changent le
rôle, coffres à décision, boss à mécaniques (absorption, cœur exposé, arène qui change).

## 2. Direction artistique

- Vue de dessus (3/4 léger), sprites 2D animés. Fonds sombres et désaturés (bleu nuit, ardoise).
- **Code couleur fonctionnel** (non négociable pour la lisibilité) :
  - Vide / Corrompus / danger : violet → magenta. Les projectiles ennemis ont un cœur
    magenta clair et un contour sombre, au-dessus de tout le reste.
  - Joueur : blanc/cyan. Échos : couleurs vives propres à chacun (braise, lichen, prisme).
  - Effets alliés : opacité plafonnée (≤ 55 %) et dessinés sous les ennemis.
- Palette des Dévoreurs : celle de la fiche Nébulorax (`docs/concepts/bosses/nebulorax.md`).

## 3. Boucle de jeu

```
Refuge ──► Expédition (arène + Tension + Écho de départ)
   ▲            │
   │            ▼
   │      Partie (~7 min + boss) : vagues → XP → choix → coffres → événements → Dévoreur
   │            │
   └── Résultats : Éclats, Essence, maîtrise, objectifs, déblocages ◄┘
```

### Contrôles (clavier + souris, touches physiques : marche en AZERTY et QWERTY)
| Action | Touches |
|---|---|
| Déplacement | WASD (ZQSD en AZERTY) / flèches |
| Ruée (dash, invulnérable) | Espace / Maj |
| Techniques des Échos | 1 / 2 / 3 |
| Ordre de focus | Clic droit (les Échos priorisent la zone 5 s) |
| Pause | Échap / P |

## 4. Combat

- **Chasseur** : 100 PV, arme auto « Trait de Faille » (projectile vers l'ennemi le plus
  proche), Ruée avec i-frames, invulnérabilité de 0,5 s après un coup.
- **Défense** : dégâts reçus × 100 / (100 + défense). Les ennemis blindés exigent de la
  Fracture ou des dégâts massifs.
- **Statuts** (le langage commun du build) :
  | Statut | Effet |
  |---|---|
  | Fracture | Défense −60, dégâts subis +15 %, 4 s |
  | Marque prismatique | Cumulable (5), détonable par les Techniques/effets |
  | Brûlure | Dégâts sur la durée, cumulable (3) |
  | Entrave | Vitesse −40 % |
- **XP** : gemmes à ramasser ; à chaque niveau, choix parmi 3 cartes (4 avec l'arbre).
- **Coffres** (lâchés par les élites) : choisir 1 relique parmi 3 **ou** briser le coffre
  (Éclats + soin). C'est une décision, pas un bonus gratuit.

## 5. Échos (roster prototype)

Chaque Écho a un rôle, une attaque auto, une passive, une Technique, deux évolutions qui
changent son rôle (au rang 3 de la partie), et des affinités. Échos de départ : 2 emplacements
d'équipe (3 via l'arbre). Choisir qui emmener est déjà une décision.

### Cendrelame / Ashblade — Assassin (braise, prédateur)
Quadrupède d'obsidienne aux avant-bras-lames, veines de braise.
- Attaque : *Taille* (bond sur une cible proche, mono-cible).
- Passive : *Exécuteur* : +60 % de dégâts contre les ennemis Fracturés.
- Technique : *Danse des cendres* : enchaîne 6 frappes sur les ennemis autour du curseur.
- Évolutions :
  - **Lame-Éclipse** : la Taille rebondit sur 2 cibles supplémentaires. Bonus Fracture doublé.
  - **Brasier-Croc** : la Taille devient un coup de zone qui inflige Brûlure (rôle : bruiser).

### Mousseroc / Mossback — Gardien, contrôle (pierre, gardien)
Monolithe ambulant couvert de lichen luminescent.
- Attaque : *Fracas* (onde de choc de zone autour de lui) : inflige Fracture.
- Passive : *Rempart* : le Chasseur subit −10 % de dégâts près de Mousseroc.
- Technique : *Puits de gravité* : aspire les ennemis vers le curseur pendant 3 s puis implose.
- Évolutions :
  - **Monolithe** : provoque les ennemis proches (ils le ciblent), Fracas élargi.
  - **Tremblecroc** : le Fracas libère un anneau de choc qui s'étend loin (contrôle à distance).

### Lucivelle / Glimmerwing — Soutien arcanique (lumière, arcane)
Phalène de verre prismatique aux ailes de filaments lumineux.
- Attaque : *Éclat prismatique* (orbe à tête chercheuse qui applique une Marque).
- Passive : *Lumière apaisante* : toutes les 25 Marques posées, soigne le Chasseur.
- Technique : *Embrasement* : fait détoner toutes les Marques (dégâts × cumuls).
- Évolutions :
  - **Prismara** : l'orbe se divise au contact (marquage de masse).
  - **Aube-Garde** : les détonations soignent et donnent un bouclier ; l'orbe ralentit.
  - **Éclipse prismatique** (secrète) : apparaît si l'équipe compte les trois Échos et si la
    relique *Prisme fêlé* est possédée. Les Marques détonent seules à 5 cumuls.

### Synergies d'équipe (actives si les deux Échos sont présents)
| Synergie | Échos | Interaction |
|---|---|---|
| Brèche & Lame | Mousseroc + Cendrelame | Frapper un ennemi Fracturé déclenche une frappe supplémentaire (marquage → attaque) |
| Prisme gravitationnel | Mousseroc + Lucivelle | Les ennemis dans le Puits reçoivent des Marques (regroupement → explosion) |
| Braise prismatique | Cendrelame + Lucivelle | Un ennemi Marqué tué par Cendrelame propage ses Marques autour de lui |

## 6. Ennemis — les Corrompus

| Ennemi | Rôle | Particularité |
|---|---|---|
| Grouillard | Nuée | Rapide, fragile, arrive en masse |
| Carapace | Tank | Défense élevée : pousse à jouer la Fracture |
| Cracheur | Distance | Garde ses distances, tire des projectiles lents et lisibles |
| Bondisseur | Charge | Se télégraphie puis charge en ligne droite |

**Élites** : version plus grosse d'un ennemi avec un affixe (Hâtif, Blindé, Volatil
[explose à la mort après un télégraphe], Scissipare [se divise]). Elles lâchent un coffre.

**Dévoreur du prototype : Nébulorax** (fiche : `docs/concepts/bosses/nebulorax.md`).
- Phase 1 : *Griffe du vide* (frappe télégraphiée), *Vague d'ombres* (anneau avec brèches
  sûres), *Invocation*, *Absorption* (absorbe les projectiles puis les recrache en salve,
  et expose son **cœur** : dégâts ×2 pendant 3 s).
- Phase 2 (50 % PV) : transformation, *Rayon du vide* (laser télégraphié), vagues doublées.

## 7. Builds

Sources du build en partie : arme du Chasseur, équipe d'Échos, cartes de stats, **mutations**
(transforment l'arme : *Éclatement*, *Trait marqueur*, *Trait brisant* ; exclusives entre elles),
**reliques** (souvent avec contrepartie), **évolutions**, **synergies**.
Cartes dynamiques : *Pacte* (recruter un Écho si un emplacement est libre), *Éveil* (rang +1),
*Évolution* (au rang requis, une carte par branche disponible).

## 8. Progression permanente

- **Monnaies** : Éclats de faille (arbre), Essence (laboratoire), XP de maîtrise (par Écho).
- **Arbre du Chasseur** : 5 branches (Combat, Échos, Recherche, Exploration, Spécialisation),
  avec paliers, prérequis et **nœuds exclusifs** (ex. *Chef de meute* contre *Chasseur solitaire*).
  Réinitialisation : rembourse 100 % des Éclats. La 1re est gratuite, les suivantes coûtent de
  l'Essence (2 × nombre de réinitialisations, plafonné à 10).
- **Maîtrise des Échos** : l'XP vient de la façon de jouer (Techniques utilisées, synergies
  déclenchées, défis de style). Paliers : bonus, palette alternative, **variante de
  gameplay**, rang de départ, titre.
- **Laboratoire** : recherches payées en Essence (reliques, mutations, informations).
- **Objectifs** : missions, succès, défis de build, avec condition et récompense explicites.
- **Tension** (difficulté) : niveaux débloqués en battant le Dévoreur au niveau précédent ;
  chaque niveau ajoute des règles (élites plus fréquentes, double affixe, phase 2 plus tôt),
  pas seulement des PV.

## 9. Contenu après la phase 4

| Échos (7) | Rôle | Mécanique propre |
|---|---|---|
| Cendrelame | Assassin | Exécute les Fracturés, frappes en chaîne |
| Mousseroc | Gardien | Fracture, Puits de gravité, provocation |
| Lucivelle | Soutien | Marques + détonation |
| Ronceline | Contrôleuse | Zones de ronces, Racines (immobilisation) |
| Fulgurine | Tireuse | Foudre en chaîne, Électrisé (+20 % dégâts subis) |
| Gueule-d'ombre | Combattant | Dévore les affaiblis : soin + dégâts croissants |
| Mirelle | Soutien | Renvoie les projectiles ennemis |

- Synergies : 7 (dont « Prédateurs », activée par deux Échos d'affinité prédateur).
- Corrompus : Grouillard, Carapace, Cracheur, Bondisseur, Nuée-mère, Rôdeur d'ombre, Gardien de cristal.
- Dévoreurs : Nébulorax (Plaine fracturée), Vorgranite (Abysse cristallin, carapace brisée en phase 2).
- **Rite de lien** : une élite peut laisser un Écho errant ; rester à son contact le capture
  (il rejoint l'équipe et, s'il était verrouillé, il est débloqué définitivement).
- **Pactes de risque** : 5 modificateurs cumulables qui augmentent les récompenses.
- Tension 0 à V, objectifs (18), recherches (6), arbre (27 nœuds).

Équilibrage et méthode de simulation : `docs/BALANCE.md`.
