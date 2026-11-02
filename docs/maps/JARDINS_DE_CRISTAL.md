# Jardins de cristal — composition de la carte 13

Panorama **3:1**, monde prévu **5016 × 1672 unités**, composition **1536 × 512**. Chapitre 3 : jungle-marais, mousse émeraude, eaux turquoise infranchissables, cristal-miroir cyan pâle. Pas de lave, orange vif ou cendres.

![Carte entière](../previews/crystal-gardens/composition.webp)

## Parcours proposé

| Repère | Position X,Y % |
|---|---|
| Départ, place de pierre à la lisière gauche | 8,49 |
| Grande clairière du jardin | 24,48 |
| Arche de cristal tombé et tablier libre | 46,42 |
| Avenue de jardin très large | 62,48 |
| Chaussée de pierres plates | 75,53 |
| Terrasse finale épaisse en croissant, sans arène | 88,50 |

[Plan annoté](../previews/crystal-gardens/plan_annote.webp). Les repères sont indicatifs et ne définissent pas des zones de gameplay.

Les deux passages relient visuellement les sols libres. Leurs appuis sont ancrés aux berges ; aucun cristal ou pilier sur les tabliers. Le départ est fermé côté extérieur par racines et eau, avec une large ouverture vers la première clairière. La dernière terrasse regarde un lagon : aucun mur d’arène ni cercle peint.

## Contrôle du plan et limites

| Critère demandé | Constat au stade composition |
|---|---|
| Format petit | 3:1, 5016 × 1672 unités |
| Deux passages identifiables | Arche cyan puis pierres de gué ; continuité visuelle contrôlée |
| Routes ≥4 %, passages ≥2,5 % de largeur | Objectifs conservés ; mesures précises à relever sur le détourage, pas de certification de navigation |
| Clairières pour combattre et tourner | Grands plateaux libres, avenue centrale élargie lors de la dernière passe |
| ≥55 % de sol praticable | Objectif visuel recherché, non certifié sans peinture des collisions |
| Obstacles | Regroupés aux bordures, centres dégagés ; petits détails du sol à laisser traversables |
| Bords | Fermés par l’eau, les racines et les ruines ; aucun chemin ne doit sortir |

Deux retouches de composition avant validation : le premier pont de racines a été remplacé par l’arche de cristal du brief ; la bordure gauche a été fermée. Une passe d’espace a ensuite repoussé les bordures de végétation pour éviter une avenue trop étroite. Les essais non retenus restent hors dépôt.

## État et suite

- [x] Composition entière, prompts exacts et empreintes conservés.
- [x] Contrôle ciblé de chargement de l’image dans Godot ; aperçu technique 1280×720 joint.
- [x] Nouveau parcours horizontal, deux franchissements distincts, fin sans arène.
- [x] Composition corrigée validée par le propriétaire le 29 octobre 2026.
- [x] Mesures du sol praticable et des largeurs lors de la peinture des collisions (46 % praticable, pont ~100 unités,
  chaussée de dalles ~230).
- [x] Huit régions détaillées, assemblage et rapport conforme.
- [x] Niveau jouable, collisions et mécaniques, raccordés par Claude (2 novembre 2026).

## En jeu (2 novembre 2026)

- Collisions peintes par le propriétaire (`assets/concepts/incoming/map.crystal_gardens/collision/`).
- Arène `data/arenas/crystal_gardens.tres`, mode vagues par zone :
  - **zone 1, la Clairière de l'arche** : la barrière ferme le pont ;
  - **zone 2, l'Avenue des jardins** : la barrière ferme la chaussée de dalles ;
  - **finale** sur la terrasse est, avec la Mère des spores.
- **Cristaux-miroirs** (brique B5, `PodDirector`), trois par clairière. Un coup les charge ; 0,9 s plus tard, trois
  rayons de 650 unités partent : le premier dans le sens du coup, les deux autres à 120°. Ils transpercent les Corrompus
  (35 + 30 % des PV max), touchent le Chasseur dans l'axe, s'arrêtent sur le décor, puis le cristal repousse en 18 s.
- Chapitre 3, carte 3. Écho découvert : Fulgurine (Voltwisp).

**Ce n’est pas une carte finale ni un niveau jouable.** Aucun agrandissement livré comme détail final, aucun champ, masque de collision, `src/`, `data/` ou manifeste runtime modifié. Les références Ruines/Mangrove servent uniquement au style ; leur plan n’est pas repris. Le propriétaire a autorisé l’enchaînement des autres lots sans attendre une réponse ; la passe de régions attend la validation du plan.

Poids des nouveaux fichiers avant ces petites métadonnées : **4.7 Mo**, sous la limite de 150 Mo.

## Correction validée du premier franchissement

Le contournement au nord de l’arche est remplacé par un chenal infranchissable relié aux eaux des bords nord et sud. Le pont bas en cristal est orienté est-ouest et raccordé directement aux deux berges ; le tablier reste libre. Ce pont est l’unique franchissement entre les deux premières zones. Conserver cette topologie lors du détail ; surveiller la teinte ocre pour éviter un orange vif.

## Détail livré le 31 octobre

Huit régions redessinées puis assemblées, trois tuiles de 3762 × 3762 pixels dans assets/environments/crystal_gardens/. Qualité **conforme** : densité 2,25 ; part lisse 0,111 ; détails fins 346,456 ; détails moyens 111,237 ; secteurs conformes 100 % ; fidélité 0,989. Rapport et planche d’échelle joints. Le pont est conservé ; sa matière est devenue gris-cyan plus discrète. Aucun manifeste runtime, collision, src/ ou data/ modifié : Claude raccordera les tuiles et le propriétaire peindra les collisions.
