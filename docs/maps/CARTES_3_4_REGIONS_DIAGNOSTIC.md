# Cartes 3 et 4 — état livré pour diagnostic

Publication demandée par le propriétaire le 20 octobre 2026, **sans PR et sans nouvelle génération**.
Ce dépôt de travail est destiné à la comparaison par Claude avec les régions natives des Hautes Terres.
Les deux cartes restent **non conformes** au contrôle actuel ; aucune qualité finale n'est revendiquée.

## Images et assemblages

- Plans approuvés : `map.firefly_woods/source/map_source.png` et `map.mist_ford/source/map_connected.png`.
- Douze sorties natives par carte, découpage 4 × 3 de la PR #42 ; aucun ancien découpage réutilisé.
- Tous les inputs, sorties, référence des Ruines, prompt exact et empreintes sont dans
  `assets/concepts/incoming/map.<id>/source/regions_v2/`.
- Assemblages officiels : `source/regions_v2/map_detailed.png` (3762 × 2508),
  puis trois tuiles de présentation de 3762 × 7524 dans `assets/environments/<id>/map*.webp`.
- L'agrandissement de présentation ×3 suit bien des générations régionales ; ce n'est pas une carte directement agrandie sans régions.
- Les 24 sorties et les essais sont conservés pour une comparaison des sources natives, avant le redimensionnement de l'assemblage.
- Le manifeste reste inchangé : les tuiles supplémentaires ne sont pas déclarées finales.

## Contrôles globaux officiels

| État | Part lisse | Détails fins | Détails moyens | Secteurs conformes | Fidélité au plan |
|---|---:|---:|---:|---:|---:|
| Bois avant retouche | 0,227 | 277,319 | 95,401 | 0,886 | 0,993 |
| Bois après retouche r1_1 | 0,227 | 277,319 | 96,173 | 0,886 | 0,992 |
| Gué, assemblage brut | 0,213 | 288,520 | 98,491 | 0,943 | 0,993 |

Seuil de finesse : 329,944 à 446,395. Densité des deux présentations : 2,25 px/unité.
Les autres critères passent ; la finesse médiane reste sous le minimum.
Rapports complets :
- [Bois courant](../previews/firefly_woods-regions-v2/qualite.json),
  [avant retouche](../previews/firefly_woods-regions-v2/essais/00-avant-retouche.json),
  [après r1_1](../previews/firefly_woods-regions-v2/essais/01-apres-r1_1.json).
- [Gué brut](../previews/mist_ford-regions-v2/qualite.json).

## Essais de texture

L'ajout autorisé figure intégralement dans `regions_v2/PROMPT_RETOUCHE.txt`.
Le prompt original reste intact ; les prompts combinés effectivement utilisés sont conservés dans `essais/`.
La retouche reçoit la région générée courante comme image1 et la référence des Ruines comme image2.
Le plan, les emprises et le sol praticable doivent rester strictement inchangés.

| Essai | Part lisse avant → après | Fins avant → après | Moyens avant → après | État |
|---|---:|---:|---:|---|
| Bois r1_1 | 0,1405 → 0,1267 | 328,882 → 328,689 | 108,533 → 111,043 | Assemblé, contrôle global ci-dessus |
| Bois r2_3 | 0,2686 → 0,2264 | 269,208 → 286,009 | 95,787 → 102,739 | PNG pilote conservé, non assemblé |
| Gué r1_1 | 0,2248 → 0,2093 | 295,279 → 326,564 | 96,560 → 102,353 | PNG pilote conservé, non assemblé |

Ces trois lignes sont des mesures **régionales**, obtenues avec la fonction de mesure du contrôleur après le même redimensionnement à 0,75 px/unité ; elles ne valent pas verdict de conformité global.
Les deux pilotes non assemblés ne disposent donc pas d'un nouveau taux de secteurs ni d'une fidélité globale après retouche.
Aucun nouvel assemblage n'a été lancé après la demande de publication immédiate.
Détail machine : [essais.json](../previews/cartes-3-4-regions-diagnostic/essais.json).

Deux régénérations antérieures au prompt standard seul ont été écartées :
Bois r1_1, fins 328,882 → 325,21 ; Bois r2_3, fins 269,208 → 274,04.
Leurs PNG sont archivés comme `standard-*-non-retenu.png`, avec diagnostic régional.
Elles ne modifient pas les statistiques de l'assemblage publié.

## Comparaisons et secteurs à examiner

- Bois : [échelle](../previews/firefly_woods-regions-v2/echelle.png),
  [carte entière](../previews/firefly_woods-regions-v2/carte-entiere.png),
  [secteurs fautifs](../previews/firefly_woods-regions-v2/secteurs-fautifs.png).
- Gué : [échelle](../previews/mist_ford-regions-v2/echelle.png),
  [carte entière](../previews/mist_ford-regions-v2/carte-entiere.png),
  [secteurs fautifs](../previews/mist_ford-regions-v2/secteurs-fautifs.png).

Sur les planches officielles, colonnes : carte assemblée, composition approuvée, référence des Ruines au même zoom.
Les volumes de feuillage et les pavés paraissent encore plus arrondis/gros que la référence : comparaison visuelle à poursuivre, sans corriger les seuils pour obtenir artificiellement un passage.

## Périmètre conservé

Les deux plans approuvés, la peinture et le masque du Bois, ainsi que son champ sont identiques à leurs empreintes initiales :
[contrôle des fichiers protégés](../previews/cartes-3-4-regions-diagnostic/fichiers-proteges.json).
Aucune modification de `src/`, `data/`, du contrôleur de qualité ou des seuils.
La correction de l'accès au pont a été abandonnée par le propriétaire ; elle n'a pas été appliquée.
Aucune génération supplémentaire ni PR n'est prévue en attendant le diagnostic de Claude.
