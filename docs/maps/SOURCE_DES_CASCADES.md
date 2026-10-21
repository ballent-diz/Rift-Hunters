# Source des Cascades — carte 5 du Val des Cascades

**Composition seulement, en attente de validation du propriétaire.** Deux propositions sont conservées ; le propriétaire a choisi la base A pour corriger les connexions. Aucune région détaillée, collision, donnée de niveau ou intégration jouable n'est produite.

## Images

- [A corrigée, entière](../previews/source-des-cascades/variante_A.png).
- [B initiale, entière](../previews/source-des-cascades/variante_B.png).
- [Comparaison A/B](../previews/source-des-cascades/comparaison_A_B.png).
- [Plan A annoté](../previews/source-des-cascades/plan_A_annote.png).

Les compositions de travail sont au format **1536 × 1536**, pour un monde projeté de **5016 × 5016 unités**.
Les sorties natives du générateur font 1254 × 1254 ; la normalisation du canevas n'ajoute pas de détail et ne prétend pas remplacer la future passe de régions.
Sources, prompts exacts, références allégées et empreintes : `assets/concepts/incoming/map.cascade_source/source/`.
Les références complètes des Ruines, Hautes Terres et du Bois ont été conservées ; des copies réduites, non recadrées, ont été jointes aux appels réussis après deux erreurs serveur sur les fichiers lourds.

## Variante A — connexions demandées par le propriétaire

Origine en haut à gauche ; coordonnées approximatives en % de l'image.
La numérotation suit son annotation : partie1 au sud, partie2 à l'est, partie3 à l'ouest, partie4 au nord.
Le graphe visuel est **P1 → P2 → P3 → P4** ; il comporte exactement trois ponts.

| Repère | Position X,Y % | Rôle |
|---|---|---|
| Départ | 49,91 | Parvis sud, espace dégagé |
| P1 | 49,79 | Grande prairie et lit peu profond |
| P2 | 78,44 | Terrasse orientale |
| P3 | 24,36 | Terrasse occidentale |
| P4 | 62,15 | Arène vide sous la grande cascade |
| Pont P1–P2 | 69,59 | Pont sud-est conservé |
| Pont P2–P3 | 57,37 | Nouveau pont horizontal, unique connexion entre ces parties |
| Pont P3–P4 | 40,19 | Nouveau pont diagonal, unique entrée dans l'arène ; extrémités vers (34,25) et (47,11) |

L'escalier cerclé par le propriétaire vers (35,5 ; 51,5), qui reliait P1 et P3, est remplacé par une falaise végétalisée.
L'ancienne approche centrale directe de P2 vers P4, avec son escalier frontal, est supprimée au profit d'une falaise et de cascades.
L'annotation originale est conservée dans `annotation_proprietaire.png` ; les traits et nombres n'apparaissent pas dans la composition propre.
Le propriétaire a imposé ces trois ponts uniques après le prompt initial : un futur courant ne doit pas recréer un raccourci inter-parties.

## B3 — lits de crue observables sur A

Rectangles enveloppes approximatifs, pas des données de gameplay :

| Lit | X,Y,largeur,hauteur % | Sens proposé du flot | Lecture |
|---|---|---|---|
| F1 sud | 14,66,72,10 | Est / sud-est, vers l'aval | Large lit à galets et eau basse au sein de P1 |
| F2 nord-ouest | 13,18,19,9 | Sud-est | Lit peu profond à galets dans P3 |

La largeur locale utile est estimée à environ 5–7 % pour F1 et 5–6 % pour F2 ; à relever précisément sur la variante validée.
Un troisième lit n'est pas suffisamment distinct pour être déclaré présent.

## B6 — courants, point restant à valider

Les rivières centrales sont en contrebas avec des cascades : elles se lisent comme des gorges bloquées, pas comme des raccourcis praticables.
Aucun courant optionnel indépendant n'est donc déclaré validé sur A.
Deux **emplacements de travail**, internes aux parties pour respecter les ponts uniques, peuvent être étudiés dans les lits :
(33,69,20,5), direction est/sud-est, et (13,20,16,6), direction sud-est.
Ces rectangles sont des intentions et ne doivent pas être raccordés tels quels par Claude sans validation du propriétaire.
La préparation B6 reste décochée.

## Variante B — alternative initiale

Progression en arc parmi les vasques, arène au nord-ouest ; le plateau est est une branche secondaire et une approche centrale rejoint directement l'arène.
Le parcours strict à quatre parties demandé ensuite par le propriétaire n'y est pas appliqué.
B est conservée pour la comparaison initialement demandée ; la base retouchée est A.

## Mesures de composition

Relevé visuel approximatif, sans masque de collisions et sans simulation de navigation.
Les pixels du canevas servent à établir les proportions, pas à garantir la netteté finale.

| Élément | Minimum du guide | A corrigée | État |
|---|---|---|---|
| Format | Grand, 5016 × 5016 | Canevas 1536 × 1536 | Vérifié |
| Route principale | 200 u / 4 % | Prairies et approches largement ouvertes | Lecture visuelle favorable, mesure finale à confirmer |
| Pont / passage | 120 u / 2,5 % | P1–P2 ~4–5 %, P2–P3 ~2,5–3 %, P3–P4 ~3–4 % | Central proche du minimum |
| Clairière | 750 u / 15 % | Trois grandes surfaces libres | Lecture favorable, relevé précis après choix |
| Arène | 900 u / 18 % | Environ 38 % de largeur projetée, 14–17 % de profondeur projetée | Profondeur et cercle de combat à confirmer |
| Sol praticable | ≥ 50 % | Non certifié sur composition, inclut les deux lits | À confirmer par le propriétaire |
| Lits de crue | 2–3, largeur ≥ 5 % | Deux lits identifiables | Relevé final attendu |
| Courants | 1–2 praticables avec route sèche | Non confirmés | Préparation incomplète |

## Checklist — GENERER_UNE_CARTE §5

- [x] Format 1:1, image entière, aucun texte, personnage ou interface dans les compositions.
- [x] Trois grands espaces de combat ; ponts courts et lisibles.
- [x] A : quatre parties dans l'ordre demandé, trois ponts, anciens raccourcis fermés.
- [x] Arène vide et grande en largeur ; pierres et ruines en bordure.
- [x] Aucune pièce de pont flottante repérée ; appuis et tabliers continus.
- [ ] Confirmer la largeur libre du pont central, la profondeur d'arène et le pourcentage de sol praticable.
- [ ] Fermer ou valider l'ouverture visuelle du départ au bord sud.
- [ ] Confirmer les rectangles et le sens des crues ; rendre les courants praticables plus explicites si retenus.
- [ ] Validation du plan par le propriétaire, puis peinture de ses collisions.
- [ ] Après validation seulement : régions, planche d'échelle, contrôle qualité conforme et contrôle de netteté.

Arrêt à cette étape. Aucun manifeste runtime, `src/`, `data/`, masque ou collision n'est modifié.
