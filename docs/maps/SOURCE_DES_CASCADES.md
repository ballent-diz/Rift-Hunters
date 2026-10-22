# Source des Cascades — carte 5 du Val des Cascades

**Carte détaillée à partir de A, demandée par le propriétaire le 21 octobre.** Deux propositions sont conservées ; le propriétaire a choisi la base A pour corriger les connexions. Les collisions, données de niveau et intégration jouable restent à produire par le propriétaire et Claude.

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
| P4 | 62,15 | Cour polygonale avec deux rochers-abris sous la grande cascade |
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
| Arène | 900 u / 18 % | Environ 38 % de largeur projetée, 14–17 % de profondeur projetée | Profondeur et espace de combat à confirmer |
| Sol praticable | ≥ 50 % | Non certifié sur composition, inclut les deux lits | À confirmer par le propriétaire |
| Lits de crue | 2–3, largeur ≥ 5 % | Deux lits identifiables | Relevé final attendu |
| Courants | 1–2 praticables avec route sèche | Non confirmés | Préparation incomplète |

## Checklist — GENERER_UNE_CARTE §5

- [x] Format 1:1, image entière, aucun texte, personnage ou interface dans les compositions.
- [x] Trois grands espaces de combat ; ponts courts et lisibles.
- [x] A : quatre parties dans l'ordre demandé, trois ponts, anciens raccourcis fermés.
- [x] Arène polygonale irrégulière, sans cercle, avec exactement deux grands rochers-abris ; entrée et voies de circulation dégagées.
- [x] Aucune pièce de pont flottante repérée ; appuis et tabliers continus.
- [ ] Confirmer la largeur libre du pont central, la profondeur d'arène et le pourcentage de sol praticable.
- [ ] Fermer ou valider l'ouverture visuelle du départ au bord sud.
- [ ] Confirmer les rectangles et le sens des crues ; rendre les courants praticables plus explicites si retenus.
- [ ] Validation du plan par le propriétaire, puis peinture de ses collisions.
- [ ] Après validation seulement : régions, planche d'échelle, contrôle qualité conforme et contrôle de netteté.

Aucun manifeste runtime, `src/`, `data/`, masque ou collision n’est modifié. La passe de détail a ensuite été autorisée par le propriétaire.

## Retouche de l’arène — 21 octobre

À la demande du propriétaire, A remplace la place circulaire par une cour polygonale irrégulière, pavée sans anneaux concentriques. Deux gros rochers moussus, vers (55 %, 14 %) et (71 %, 18 %), fournissent les futurs abris contre les attaques du boss. Ils sont décalés et séparés par une large voie libre. Les quatre parties, les trois ponts et les accès fermés sont conservés visuellement.

Source native : `variant_A_arena_cover_native.png` ; prompt exact : `PROMPT_ARENE_ABRIS.txt`, générateur intégré imagegen. Cette livraison reste une composition : les collisions des rochers et leur blocage des projectiles ne sont pas implémentés ; le propriétaire puis Claude les raccorderont.

## Passe de détail — 21 octobre

16 régions générées (4 × 4), source et référence d’échelle des Ruines jointes à chaque appel. Deux rochers-abris restent deux obstacles uniques. Les premiers bruts restent archivés dans source/regions_v1/trials/. Les prompts de retouche sont conservés intégralement, sans remplacer le prompt officiel.

| Essai | Lisse | Fins | Moyens | Secteurs conformes | Fidélité |
|---|---:|---:|---:|---:|---:|
| Régions initiales | 0,234 | 295,086 | 95,401 | 83,7 % | 0,995 |
| Retouche des quatre régions r3 | 0,226 | 295,086 | 95,787 | 91,8 % | 0,990 |
| Calibrage après rééchantillonnage | 0,211 | 303,583 | 96,173 | 95,9 % | 0,991 |
| Microdétails r0, r1, r2 | 0,192 | 333,710 | 103,126 | 95,9 % | 0,987 |

Les deux dernières lignes sont des contrôles de l’image native à 0,75 px/unité : leur échec de densité est normal ; le verdict de livraison doit porter sur les tuiles exportées à 2,25 px/unité. Aucun seuil de qualité modifié. Le réglage de netteté conserve son plafond de 120 % et s’applique désormais après rééchantillonnage à la densité native réelle. Une option --native-only permet de vérifier les matières avant l’encodage coûteux des tuiles WebP.

Deux secteurs de lisière boisée restent sous les critères sectoriels à (0,4800) et (4000,4800) ; la conformité globale exige 85 % des secteurs et est contrôlée séparément. Les essais et leurs chiffres sont livrés pour diagnostiquer ces limites sans les masquer.

## Cadence retenue pour les prochaines cartes

Contrôler l’aperçu natif avant chaque encodage des grandes tuiles (--native-only). Après les régions, employer le détecteur de cases de 160 unités de main et sa correction locale deblur_map.py, plutôt que multiplier les générations lorsque seul le piqué des matières manque. Conserver les régions brutes, les essais et les chiffres avant/après. La correction locale ne remplace jamais une passe de régions ni une correction d’échelle ou de plan.

## Livraison finale — tuiles exportées

Trois tuiles de 3762 × 11286 pixels, ensemble 11286 × 11286, **2,25 pixels par unité**. Après correction locale, le traitement préserve le grain réellement peint des régions (rayon 2 pixels, amplitude limitée à ±12 par canal, aucun bruit ajouté). Export WebP sans perte, compression méthode 0 pour réduire le temps d’encodage sans modifier les pixels.

Contrôle officiel des trois tuiles : **CONFORME**. Lisse 0,170 ; fins 372,720 ; moyens 108,147 ; secteurs conformes **100 %** ; fidélité **0,986**. Les seuils du contrôle sont inchangés.

Détection fine : 530 cases initiales sur 961. Après correction et préservation du grain : **0 case résiduelle à référence initiale figée**, seuil 0,6 inchangé. Le percentile recalculé devient beaucoup plus haut et signale 529 cases : ce résultat relatif ne se compare pas directement au précédent, conformément à la note du guide de qualité. Scores bruts et deux résultats conservés dans uniformite/.

[Carte entière](../previews/source-des-cascades/carte-detaillee.png), [échelle](../previews/source-des-cascades/echelle.png), [rapport final](../previews/source-des-cascades/qualite.json). Import Godot final sans erreur. Manifeste différé jusqu’au field peint par le propriétaire : le validateur exige ce field, aucun masque inventé.
