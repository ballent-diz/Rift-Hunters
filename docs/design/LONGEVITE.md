# Longévité et rejouabilité

Statut : **validé dans le principe le 14 octobre 2026** ; le détail de chaque système reste à concevoir
avec le propriétaire. Objectif : un jeu qui tient **plusieurs heures**, avec un **platine** à aller chercher.

## Modes de jeu

Le système de niveau est décrit en données : chaque map choisit son mode. Répartition dans la campagne
(~70 % vagues par zone, ~30 % variantes, au moins une par chapitre) : [CAMPAGNE.md](CAMPAGNE.md).

| Mode | Statut | Description |
|---|---|---|
| Survie au chrono | Existant ; **hors campagne** (Plaine fracturée) | Vagues continues pendant ~7 min, puis le Dévoreur ; épreuve d'endurance pour le score |
| Vagues par zone | Validé (Ruines des Cascades) | Voir [MODE_VAGUES_PAR_ZONE.md](MODE_VAGUES_PAR_ZONE.md) |
| Défense d'autel | Idée | Protéger un autel pendant X vagues |
| Fermeture de failles | Idée | Détruire des portails qui crachent des monstres tant qu'ils sont ouverts |
| Zone qui se resserre | Idée | L'espace jouable rétrécit avec le temps |
| Ruée de boss | Idée | Enchaîner les boss |

Le propriétaire proposera d'autres modes au fil de l'eau ; les ajouter à ce tableau.

## Difficultés (décision du 16 octobre 2026)

La **Tension** (choix de 0 à V avant l'expédition) est **supprimée**. Modèle inspiré de Hades : une campagne courte
à difficulté fixe, puis une rejouabilité que le joueur compose lui-même.

| Difficulté | Déblocage | Contenu |
|---|---|---|
| **Normal** | Dès le départ | La campagne (3 à 6 h), difficulté fixe, sans réglage |
| **Cauchemar** (le New Game+) | En **finissant le jeu** (dernier boss de la campagne) ; ensuite disponible sur **chaque carte** | Ennemis renforcés et surtout **nouvelles règles** : élites à double modificateur, boss enragés avec une phase de plus, vagues plus denses. Arbre, builds et Échos conservés. +25 % d'Éclats, +1 point de Chasseur à la première victoire sur chaque carte |
| **Le Pacte** (notre « Chaleur » de Hades) | Avec le Cauchemar | Les 5 pactes de risque actuels, étendus à ≈ 10 malus au choix (ennemis plus rapides, moins de soins, boss plus résistants…). Chaque malus vaut des points ; **chaque carte retient son meilleur score de Pacte**. Paliers de récompenses et trophées par score |

Technique : les fichiers `data/difficulties/tension_*.tres` servent de base au Normal, au Cauchemar et aux paliers du
Pacte ; le sélecteur de Tension du refuge disparaît (lots B1 et D3).

## Objectifs de carte et « prophéties »

Deux sortes de défis, qui donnent une raison de rejouer et d'essayer d'autres builds :

- **Objectifs de carte** : 3 par carte en Normal, 3 autres en Cauchemar, comme des étoiles. Exemples : finir la carte ;
  la finir en subissant moins de 300 dégâts ; vaincre le boss en moins de 2 min. Ils donnent des Éclats et des points
  de Chasseur.
- **Prophéties** (nom repris des « Prophéties du destin » de Hades) : une liste de défis **à long terme**, valables sur
  tout le jeu, qui poussent à varier : gagner une fois avec chaque voie, utiliser chaque clé de voûte, recruter les
  16 Échos, réussir 100 Parades, atteindre un score de Pacte de 20… Chacune rapporte une récompense (Éclats, cosmétique,
  emplacement de build) et la plupart deviennent des **trophées**. Les 18 objectifs actuels du jeu y sont reversés.

## Trophées

- **Système interne** de trophées dès maintenant (progression, défis de build, exploits, secrets),
  affiché dans le jeu.
- Relié aux **succès Steam** lors de la publication (voir [../STEAM.md](../STEAM.md)).
- **Platine** : débloqué quand tous les autres trophées sont obtenus.
- Les objectifs actuels (18) servent de point de départ.

## Questions ouvertes

- Liste des trophées et répartition (bronze / argent / or ?).
- Liste des malus du Pacte et des prophéties.
- Ordre de réalisation de ces systèmes après les chantiers de gameplay.
