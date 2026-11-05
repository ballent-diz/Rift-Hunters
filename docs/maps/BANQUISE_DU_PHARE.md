# Carte 19 — La Banquise du phare

**Composition corrigée à valider — 5 novembre 2026.** Identifiant proposé : `lighthouse_floe`.
Chapitre 4, Glacier silencieux ; défense d’autel, particularité B4 « Banquise qui se fend ».
Branche `codex/carte-19-banquise-phare`, depuis `origin/main` actualisé.

![Composition entière proposée](../previews/lighthouse-floe/composition.webp)

![Plan proposé et repères](../previews/lighthouse-floe/plan_annote.webp)

## Composition proposée

Monde carré de **5016 × 5016 unités**, image de composition de **1254 × 1254 pixels**.
Île rocheuse centrale, phare peint éteint, eau noire intérieure, anneau de banquise praticable,
puis rivage enneigé et falaises périphériques. Départ au sud-ouest sur une grande place dégagée.
Le phare est lui-même l’autel : aucun second autel ni enceinte de finale.

Les coordonnées ci-dessous partent du coin supérieur gauche, en pourcentages de l’image entière.
Le fichier [plan.json](../../assets/concepts/incoming/map.lighthouse_floe/plan.json)
contient les repères proposés et les nouveaux polygones relevés sur les fractures de l’image corrigée.
Il reste **non figé**, avec `owner_approved: false` et `plan_locked: false`, jusqu’à validation de cette correction.
Le propriétaire a confirmé le plan rayonnant et l’échelle du phare ; la composition corrigée complète reste à valider.

| Repère | Position / trajet proposé |
| --- | --- |
| Départ | 21 % ; 80 %, rivage sud-ouest |
| Phare éteint | Pied vers 50 % ; 50,7 %, sur l’île stable |
| Accès nord | Crête rocheuse ; plaque P01 ; arrivée sur le nord de l’île |
| Accès est | Épave de brise-glace, coque abîmée et pont dégagé ; plaque P05 après la coque |
| Accès sud | Passerelle de pierre ; plaque P08 |
| Accès ouest | Crête rocheuse enneigée traversant tout le fossé ; plaque P11 sur son approche |
| Détour | Boucle sur le rivage ferme, tracée en pointillés sur le plan |
| Abris | A01–A12 : trois par quart, huit sur les rivages et quatre sur l’île |

Le phare, sa porte, ses marches et son socle gardent l’échelle acceptée par le propriétaire,
avec un Chasseur d’environ 52 unités ; la tour reste grande et son sommet sans lumière.
La porte reste dans la cible **75–90 unités**. Les petits motifs seront affinés par régions :
marches 12–16 unités, pavés au plus 26, colonnes 30–45, sans changer la taille du phare.
Les douze abris pleins ont maintenant une emprise au sol estimée à **120–152 unités** de largeur,
dans la plage demandée 110–160 ; leur silhouette dressée et leur ombre les rendent lisibles.
Les quatre rochers de l’île ont été repris. Les deux carcasses éloignées sur neige ont été retirées.

L’épave est raccourcie au fossé : coque inclinée, bordages brisés, membrures de fer rouillé désaturé,
mât couché le long de la coque et tablier praticable dégagé. Son extrémité extérieure rejoint la glace
stable **avant P05**, sans recouvrir cette plaque. Le franchissement ouest est continu jusqu’au sol de l’île.
Rivage découpé, congères ombrées, traces et affleurements varient l’anneau extérieur ; les falaises sont gris-bleu,
moins saturées que dans la première proposition.

## Plaques B4 et chemins de retour

**Quatorze plaques distinctes**, P01–P14 en sens horaire depuis le nord. Leurs polygones proposés
suivent les nouvelles fractures irrégulières, avec des concavités et des silhouettes de tailles variées,
sans octogones. Leurs diamètres maximaux relevés font environ **313–573 unités**
(distance maximale entre sommets, approximation à quatre unités par pixel), dans la plage 300–600 demandée.
Au moins une plaque se trouve sur chacun des quatre accès : **P01 nord, P05 est, P08 sud, P11 ouest**.
Les plaques intactes sont praticables. Aucun abri n’est placé dans leur emprise.
Le turquoise pâle translucide des plaques et leurs lèvres de fracture se distinguent de la glace stable
vert-gris plus sombre. Le goulet d’eau noire permanent reste clairement séparé autour de l’île.

La boucle extérieure doit permettre de rejoindre un autre accès lorsqu’une plaque cède.
Proposition de séquencement pour Claude : conserver au moins deux accès au phare ouverts,
et ne pas ouvrir simultanément toutes les plaques d’un secteur. Les collisions du propriétaire,
la continuité effective des détours et le calendrier B4 seront validés lors de l’intégration.
Aucun test de navigation ou de combat n’est revendiqué par cette revue graphique.

L’image future « banquise brisée » montrera les quatorze emprises ouvertes comme **ressource graphique
à afficher plaque par plaque**. Elle ne décrit pas un état de jeu autorisant l’ouverture des quatorze plaques à la fois.

## Deux états et détail à venir

Après validation de cette composition : figer `plan.json`, découper avec `tools/art/map_regions.py`,
puis redessiner chaque région dans les **deux états, avec les mêmes limites et la même finesse**.
Les références sont les Ruines des Cascades et les règles de
[QUALITE_DES_CARTES.md](QUALITE_DES_CARTES.md). Aucun agrandissement de la composition ne sera livré comme détail.

L’état brisé partira de la source intacte commune : eau noire, morceaux flottants et bords cassés
seront peints localement puis réinsérés strictement dans les polygones des plaques.
Tout ce qui est hors plaques doit conserver **exactement les mêmes pixels**, y compris le phare,
les rivages, les abris, les quatre ouvrages et les ombres extérieures.
Même cadrage et même résolution pour les deux images. Le contrôle pixel à pixel sera effectué
**sur les fichiers effectivement livrés, après encodage**, avec superposition et rapport de différences.
Le choix d’encodage devra préserver cette identité hors plaques.

À ce stade, seul l’état intact de **composition** existe. Le second état, le détail par régions,
le rapport `check_map_quality.py` conforme pour chaque état et la preuve de superposition restent à produire
après validation. Aucun fichier du manifeste ou décor utilisable en jeu n’est ajouté.

## Lisibilité et captures de revue

Le banc [preview_lighthouse_floe.tscn](../../tools/art/preview_lighthouse_floe.tscn) affiche la composition
avec les feuilles existantes du jeu, leurs ancres et leurs échelles inchangées. Le zoom est lu dans
`GameDB.balance.camera_zoom`, à 1280 × 720 ; aucune partie ni écriture de profil n’est lancée.

- [Chasseur et Écho au pied du phare](../previews/lighthouse-floe/phare_zoom_jeu.png)
- [Épave traversable](../previews/lighthouse-floe/epave_zoom_jeu.png)
- [Passerelle de pierre](../previews/lighthouse-floe/pierre_zoom_jeu.png)
- [Franchissement ouest du fossé](../previews/lighthouse-floe/ouest_zoom_jeu.png)
- [Sept Échos du silence sur neige](../previews/lighthouse-floe/silence_neige.png)
- [Les mêmes sur banquise](../previews/lighthouse-floe/silence_banquise.png)
- [Référence des Ruines au même zoom](../previews/lighthouse-floe/reference_ruines_zoom_jeu.png)

Éclat du silence, Chevalier de glace, Sentinelle gelée, Brise-banquise, Héraut du silence,
Mammouth de givre et Sorcière des neiges : sprites déjà livrés au chapitre 4, aucun redessin.
Ces captures examinent leur contraste sur la composition agrandie au zoom réel ; la finesse du terrain
et l’échelle des motifs seront à vérifier à nouveau après les régions.
Les sept silhouettes restent distinctes sur le vert de la banquise et le bleu-gris de la neige.
Le Chasseur est posé au pied des marches du phare ; la porte corrigée garde une taille humaine.
L’orientation lumineuse reste haut-gauche, avec un liseré violet discret en bas à droite.
Glace de mer verte, neige bleutée, pierre grise et fer rouillé désaturé donnent l’identité propre du lieu.

Le reçu [controle_composition.json](../previews/lighthouse-floe/controle_composition.json) conserve
les commandes, résultats de chargement et empreintes de cette étape. La conformité graphique finale
est explicitement en attente du détail et de la validation.

## Collisions et raccordement

Après le détail des deux états, fournir une **référence entière légère de l’image intacte**, sans repères,
avec recette, dimensions et SHA-256 dans `source/collision_reference.json`, comme pour les cartes précédentes.
Le propriétaire peindra les collisions puis renverra un **PNG au même cadrage** ; aucun masque statique n’est
dessiné par Codex. Les plaques resteront praticables dans cette peinture : le jeu les fermera temporairement
lorsqu’elles cèdent. Les polygones B4 sont des repères pour ces changements d’état, pas un masque statique.

Claude intégrera collisions, autel, fermetures B4, gardien et campagne.
**Aucun changement de `src/`, `data/`, du manifeste ni des cartes 14 à 18.**

## Sources et étapes

Dossier `assets/concepts/incoming/map.lighthouse_floe/` ignoré par Godot :
`composition.png`, `job.json`, **`plan.json` proposé**, croquis technique actualisé, prompts de génération et de correction,
`generation.json` et empreintes `SHA256.json`. La première proposition est remplacée dans les mêmes chemins ;
elle reste accessible dans l’historique Git, sans copie `_v2` ni essais supplémentaires versionnés.
Essais et images non retenues restent hors dépôt.

- Composition corrigée et nouveaux polygones dans `plan.json` : proposés, en attente du propriétaire.
- Verrouillage du `plan.json` : après validation.
- Régions intactes et brisées, contrôle qualité conforme et superposition : à faire.
- Référence de peinture des collisions : après le détail.
- Masque et intégration en jeu : propriétaire et Claude.
