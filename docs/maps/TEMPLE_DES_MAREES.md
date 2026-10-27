# Temple des marées — carte 12

Chapitre 3, Marais engloutis. Carte **verticale 2:3**, monde **3344 × 5016**, composition **1024 × 1536**. Quatre espaces destinés aux failles, puis parvis final. Aucun objet de faille, gardien ou cercle d’énergie peint : ils seront dessinés par le jeu.

Le propriétaire a autorisé de poursuivre sans questions ni validation intermédiaire. Composition choisie par Codex, pas validation visuelle explicite du propriétaire ; plan ensuite figé pour la passe de régions.

![Plan annoté](../previews/tide-temple/plan_annote.webp)

## Parcours haut permanent

Six terrasses échelonnées, reliées par **cinq ponts hauts secs** : départ sud → cour ouest → terrasse est → salle nord-ouest à ciel ouvert → bassin nord-est → parvis nord. Ce tracé reste visuellement continu en supprimant les cinq chaussées basses. Les deux premières compositions demandaient des passages bas obligatoires ; la liaison haute nord a été ajoutée avant de figer le plan.

| Repère réalisé | X,Y % approximatifs |
|---|---|
| Départ, parvis sud | 50,85 |
| Faille 1, cour ouest | 20,56 |
| Faille 2, terrasse est | 79,46 |
| Faille 3, salle effondrée | 22,29 |
| Faille 4, bassin sacré | 80,20 |
| Final, parvis du sanctuaire | 42,5 |

Le tracé jaune du plan est schématique : il indique l’ordre des terrasses, pas une trajectoire de navigation. Coordonnées relevées sur l’image réalisée, distinctes des repères indicatifs du brief ; Claude choisira les points exacts après les collisions. Le carrefour haut vers (64,18) permet de rejoindre le parvis final sans traverser le centre de la terrasse Faille 4 ; le mode doit donc conserver sa condition de fermeture des quatre failles avant le gardien, plutôt que supposer un passage imposé par le décor.

## Chaussées de marée

**Cinq chaussées basses** (dans la plage demandée de 5 à 7), en dalles sombres humides au niveau de l’eau. Chaque chaussée relie deux terrains secs, et possède un détour haut. `tide.png` : **noir = rien, blanc = chaussée noyée à marée haute**. Pas un masque de collisions.

| Chaussée | Rectangle X1,Y1,X2,Y2 % | Longueur technique (u) | Largeur moyenne (u) |
|---|---|---:|---:|
| T01 | 18.848, 66.797, 31.738, 77.93 | 563.0 | 167.3 |
| T02 | 35.059, 46.81, 61.328, 53.646 | 826.7 | 173.5 |
| T03 | 15.234, 39.518, 21.68, 47.526 | 389.6 | 186.4 |
| T04 | 77.539, 33.594, 88.574, 39.714 | 336.9 | 166.9 |
| T05 | 55.371, 7.031, 73.438, 14.583 | 576.9 | 128.0 |

Mesures de l’emprise technique du masque, pas d’une navigation simulée : [détails](../previews/tide-temple/mesures_chaussees.json). Le masque couvre toute la largeur, joints compris, avec de petites marges extérieures dans l’eau déjà infranchissable ; aucune bande latérale volontairement laissée hors masque.

- T01 : départ ↔ cour ouest ; détour par le premier pont haut.
- T02 : cour ouest ↔ terrasse est ; détour par le pont haut inférieur.
- T03 : cour ouest ↔ salle nord-ouest ; détour par terrasse est puis pont central.
- T04 : terrasse est ↔ bassin nord-est ; détour par salle nord-ouest et pont haut nord.
- T05 : bassin nord-est ↔ parvis final ; détour par le pont haut supérieur.

![Chaussées superposées](../previews/tide-temple/chaussees.webp)

Masque final **7524 × 11286**, noir/blanc 1 bit, cinq composantes ; emprises provisoires adaptées sans interpolation des valeurs. Bords extérieurs fermés par végétation et ruines. Pierre grise moussue, cristal-miroir cyan pâle, eaux turquoise et profondes, aucune lave ni terrain cendreux.

## Mesures et limites

| Critère | Contrôle |
|---|---|
| Format vertical | 3344 × 5016 unités |
| Espaces de combat | Six terrasses, centres dégagés et abris répartis |
| Ponts hauts | Visuellement continus, ancrés aux terrasses et distincts des chaussées basses |
| Chaussées basses | Cinq, largeur moyenne ci-dessus, détours hauts visibles |
| Sol praticable ≥50 % | Objectif visuel non certifié avant peinture des collisions |
| Couvertures ≥120 u, espaces ≥350 u | Rochers/statues de cristal présents ; tailles et espacements à confirmer manuellement |

Les petits débris de surface doivent rester traversables. Aucune certification de navigation ou de marée en jeu : collisions, règle de submersion et annonces sont hors de ce lot.

## Détail et vérification

Douze régions (3 × 4), redessinées avec une référence des Ruines à chaque génération, assemblées avec recouvrements fondus. Une finition des matières remplace les pavés trop lisses par de plus petits composants sans changer le plan ; prompts exacts dans `source/PROMPT_FINITION.txt`, `source/PROMPT_MICROFINITION.txt` et `source/PROMPT_PAVAGE_NORD.txt`. Le premier contrôle comptait 291,610 détails fins, insuffisant : aucune publication de cet essai. La région nord r0_1 utilise un prompt plus court pour remplacer effectivement le motif des grandes dalles. Les nouveaux pavés sont réinsérés uniquement dans quatre emprises de sol, avec fondu intérieur de 4 pixels ; le décor original est conservé pixel pour pixel hors de ces emprises (provenance et polygones dans source/provenance_pavage_seul.json). Deux tuiles **3762 × 11286**, carte totale **7524 × 11286**, **2,25 px/u**. Les régions intermédiaires restent hors Git ; provenance et empreintes dans `source/regions_manifest.json`.

| Contrôle officiel | Résultat |
|---|---:|
| densité (pixels par unité) | 2.25 |
| part lisse (médiane) | 0.2 |
| détails fins / 100×100 u (médiane) | 348.773 |
| détails moyens / 100×100 u (médiane) | 100.808 |
| secteurs conformes (part) | 1.0 |
| fidélité au plan validé (corrélation) | 0.984 |

Verdict **global CONFORME**, seuils inchangés. La réserve de netteté locale ci-dessous empêche de qualifier la livraison de définitive. [Rapport](../previews/tide-temple/qualite.json) · [Échelle](../previews/tide-temple/echelle.webp) · [Carte entière](../previews/tide-temple/carte_entiere.webp). Les extraits de comparaison restent à 1 pixel = 1 unité, réorganisés sans redimensionnement.

Import et chargement des textures et du masque contrôlés dans un projet Godot 4.3 isolé. Le [repère Chasseur/Mousseroc](../previews/tide-temple/secteur_echelle.webp) est un montage technique à l’échelle, pas une capture en partie.

## Checklist et raccordement

- [x] Carte entière verticale, sans interface, texte ni personnages.
- [x] Six terrasses et chemin haut permanent, cinq raccourcis bas séparés.
- [x] Identité du chapitre 3, bordures fermées, centres de combat ouverts.
- [x] Masque de marée final, mesures et plan annoté.
- [x] Douze régions, assemblage, qualité globale conforme et planche d’échelle.
- [ ] Netteté locale conforme : réserve ouverte, statut wip.
- [x] Contrôle ciblé de chargement Godot.
- [ ] Validation manuelle des tailles, de la circulation et des détours par le propriétaire.
- [ ] Collisions peintes, marée, quatre failles, gardien et niveau jouable intégrés par Claude.

Aucun `src/`, `data/` ou masque existant modifié. Entrée du manifeste runtime différée, sans inventer de `field`. Sources retenues, prompts exacts et SHA256 dans `assets/concepts/incoming/map.tide_temple/`.

## Restauration des contours et réserve locale

Une première correction sélective brute a été rejetée : finesse **330,234 → 308,218**, non conforme. Le traitement retenu conserve la matière peinte et transfère uniquement les contours reconstruits par le modèle officiel sur toute la carte : filtre de détail sigma 1,25, poids 0,75, mêmes blocs de 512 pixels et recouvrements de 32. Aucun bruit ajouté, aucune modification de seuil, aucun changement du plan. Recette, code exact et empreintes du modèle sont dans `source/RESTAURATION_CONTOURS.json` et `.py`.

Le contrôle global passe après restauration : **348,773 détails fins**, **100,808 moyens**, **100 % de secteurs conformes**, fidélité **0,984**. Les tuiles WebP sont sans perte : leurs pixels décodés ont été vérifiés identiques à ceux du candidat contrôlé. Import et chargement Godot revérifiés une seule fois après remplacement.

[Avant/après au même zoom](../previews/tide-temple/avant_apres_zoom.webp) · [Chiffres et provenance](../previews/tide-temple/restauration_contours.json).

Le diagnostic relatif de netteté s’améliore de **333 à 219 cases signalées sur 620 (53,7 % → 35,3 %)**. Il reste au-dessus du seuil de 5 % : **réserve maintenue, statut wip, PR en brouillon**. Les Ruines de référence signalent elles-mêmes 50 % dans ce diagnostic, mais cela ne suffit pas à déclarer le Temple conforme localement. Aucune affirmation « aucune case floue ».

[Carte de chaleur](../previews/tide-temple/tide_temple_sharpness.png) · [Cases signalées](../previews/tide-temple/tide_temple_blurry.json) · [Rapport local](../previews/tide-temple/netteté_locale.json). Le comparatif spectral antérieur reste un historique de la version avant restauration.

### Correction d’une mesure de chaussée

La mesure initiale de T05 avait interverti les côtés longs et courts du polygone. Sa longueur correcte est **576,9 unités**, sa largeur moyenne **128,0 unités**, sous l’objectif de 150–300 : écart à examiner avec le propriétaire. Le dessin et le masque restent inchangés ; aucune adaptation de masque pour masquer cet écart. Les quatre autres largeurs moyennes vont de 166,9 à 186,4 unités.

Poids des nouveaux fichiers uniques : **140.2 Mo**, sous la limite 150 Mo. [Mesure](../previews/tide-temple/poids.json).
