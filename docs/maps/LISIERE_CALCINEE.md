# Lisière calcinée — carte 6

Composition à valider, avant toute passe de régions. Monde : **5016 × 3344 unités**, image **1536 × 1024**. Aucun niveau jouable ni collision produit.

![Carte entière](../previews/scorched-verge/composition.png)

## Identité du chapitre 2 : Les Terres dévastées

Carte 6 : steppe brûlée, village et fortin noircis, herbes grises et ocre, arbres calcinés, fissures fumantes. Palette gris cendre, ocre brûlé, brun charbon, violet discret. Orange incandescent exclusivement sur les plaques dangereuses. Lumière haut-gauche et rendu peint du chapitre 1. Cartes 7–9 : davantage de roche nue, cendres, fissures et fumée. Carte 10 : paysage volcanique, lave et roche noire. Cette progression visuelle est la référence pour les prochaines cartes du chapitre.

## Plan de composition

Coordonnées approximatives en pourcentage, origine en haut à gauche.

| Repère | X,Y % | Intention |
|---|---|---|
| Départ proposé | 13,56 | Place du village sans danger proche |
| Zone 1 | 20,50 | Village brûlé, grande place libre |
| Passage 1 | 31,48 | Porte de palissade courte |
| Zone 2 | 49,52 | Grande plaine de cendres |
| Passage 2 | 65,49 | Pont de pierre au-dessus de la gorge |
| Zone 3 | 80,58 | Cour du fortin |
| Accès arène | 83,31 | Large escalier |
| Arène | 84,18 | Terrasse polygonale sous la faille violette |
| Rocher-abri 1 | 78.5,15.5 | Couverture, décalée vers le fond |
| Rocher-abri 2 | 88.5,23 | Couverture, décalée vers le premier plan |

L’arène ne présente plus de forme circulaire : terrasse aux angles irréguliers, deux gros rochers espacés et entrée libre. Le reste du plan et les dix plaques sont conservés. Les rochers sont uniquement dessinés : leur collision et leur capacité à bloquer les attaques restent à raccorder par le propriétaire et Claude. Circulation favorable visuellement, à confirmer sur les collisions peintes.

## Plaques de dégâts

Le masque hazards.png possède exactement les mêmes dimensions que composition.png : noir = hors plaque, magenta pur #FF00FF = plaque. Dix composantes distinctes ; aucune autre couleur. Les enveloppes suivent les fissures orange, incluent le charbon entre celles-ci et une marge de 2 pixels sur leur bord visible. Ce masque ne décrit jamais les collisions.

| Plaque | Centre X,Y % | Diamètre enveloppe, unités |
|---|---|---|
| H01 | 21.48, 32.23 | 231.9 |
| H02 | 14.97, 44.92 | 251.5 |
| H03 | 20.18, 63.48 | 209 |
| H04 | 44.27, 29.79 | 261.2 |
| H05 | 50.13, 44.92 | 215.5 |
| H06 | 44.27, 67.38 | 274.3 |
| H07 | 55.34, 59.57 | 163.3 |
| H08 | 83.01, 43.95 | 205.7 |
| H09 | 78.12, 52.25 | 205.7 |
| H10 | 88.54, 66.89 | 215.5 |

Distance minimale du départ proposé aux plaques : **311.3 unités**, supérieure aux 200 demandées. La plaque de la zone 1 a été éloignée de la palissade afin de dégager son approche. Les détours sûrs de chaque plaque restent à confirmer avec les collisions du propriétaire.

## Mesures et contrôle de composition

| Critère | Relevé |
|---|---|
| Format | 3:2, 1536 × 1024, monde 5016 × 3344 |
| Grandes zones | Trois clairières successives |
| Palissade | Environ 65–80 px de large, estimation visuelle |
| Pont | Environ 45–55 px, estimation visuelle ; minimum 2,5 % = 38,4 px |
| Escalier final | Environ 100–115 px de large |
| Arène | Environ 24 % de la largeur ; deux obstacles de couverture |
| Plaques | 10, diamètres enveloppes 163–274 unités |
| Sol praticable ≥55 % | Non certifié avant peinture des collisions |
| Netteté et échelle finales | Non revendiquées à cette étape de composition |

## Checklist

- [x] Carte entière, sans texte, interface ni personnages.
- [x] Trois grands espaces, pont et accès lisibles.
- [x] Identité cendre/ocre/charbon, orange réservé aux dix dangers.
- [x] Départ proposé dégagé, masque technique bicolore contrôlé.
- [x] Arène non circulaire, deux rochers-abris, entrée et couloirs dégagés visuellement.
- [ ] Validation du propriétaire : plan, circulation, détours sûrs et proportion praticable.
- [ ] Collisions peintes par le propriétaire.
- [ ] Après validation seulement : régions redessinées, assemblage, comparaison d’échelle, rapport qualité conforme et carte de netteté.

## Sources

Images originales, références, prompts exacts et SHA256 dans assets/concepts/incoming/map.scorched_verge/source/. Retouche finale : PROMPT_ARENE_ABRIS.txt. Génération par imagegen intégré. Contrôle ciblé dans docs/previews/scorched-verge/controle.json et aperçu des plaques dans plaques-annotees.png. Aucun changement de src/, data/ ni du manifeste runtime. Le script sharpness_map.py demandé pour la livraison détaillée est absent du main de référence a0946bf ; à vérifier avant cette future étape.
