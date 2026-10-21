# Bois des Lucioles : diagnostic ciblé

Aucun fichier du dépôt modifié, aucune action git. Deux essais autonomes sauvegardés ici par le générateur intégré, sans API. Prompt régional officiel reproduit exactement ; entrée 1 = recadrage original rY_X_input.png, entrée 2 = reference_scale.png. Les fichiers livrés dans ce dossier ne sont PAS des remplacements validés.

## État réel

Le rapport officiel global fourni par le parent échoue sur la finesse : 277,319 détails fins /100×100 unités pour une borne minimale de329,944. Plan très bien conservé :0,993 ; moyens95,401 conformes ; part lisse0,227 conforme ; secteurs0,886 conformes.
Visuellement, les pavés, roches et aiguilles de pins restent plus grands et arrondis que dans les Ruines. L'image gagne en netteté par rapport à la composition mais manque de vrai détail de matière à l'intérieur des objets. Les zones de falaises et les grandes clairières aggravent le manque. Ce n'est pas une erreur du contrôle à contourner.

## Essais avec prompt exact, mêmes entrées

Mesures indicatives par région, après le redimensionnement0,75px/unité utilisé par l'assemblage, puis métriques officielles à2,25px/unité. Ces statistiques régionales n'ont pas le même échantillonnage que le contrôle de la carte entière et ne le remplacent pas.

|Région|Version|Lisse|Fins|Moyens|
|---|---|---:|---:|---:|
|r1_1|livraison courante|0,1405|328,882|108,533|
|r1_1|nouvel essai|0,1224|325,212|105,443|
|r2_3|livraison courante|0,2686|269,208|95,787|
|r2_3|nouvel essai|0,2696|274,036|93,663|

Les deux essais se ressemblent fortement aux sorties existantes. Gain de finesse nul ou faible. Il serait inutile de regénérer encore deux régions sans modification de stratégie. Je déconseille de remplacer les sorties actuelles par ces essais.

## Diagnostic spatial

regional_metrics.json contient les statistiques indicatives des12 régions d'origine. Seul r2_0 dépasse la borne fine globale330 dans cet échantillonnage local ; r1_1 est proche. r2_1 est le plus faible239,66 ; il faudrait cependant améliorer plus de la moitié des secteurs de la carte pour relever la médiane globale, pas seulement les4 secteurs hors norme du rapport officiel.

## Suite possible à arbitrer

Ne pas toucher au plan, aux collisions, aux seuils, et ne pas ajouter du bruit ou du sharpen pour faire passer la mesure. Une vraie correction demanderait une passe de matière et de subdivision des gros objets sur les emprises existantes : fissures, mousses, feuilles et branches réellement dessinées plus fines. Le prompt régional actuel le dit déjà mais les essais restent visuellement accrochés aux formes et à l'échelle du recadrage de composition. Une retouche locale plus directive serait une stratégie différente à documenter ; elle ne doit pas être présentée comme le prompt officiel inchangé.

## Provenance

- r1_1.png : générateur intégré, exec-a4c75fd8-15c1-4d18-97a1-7c5781304179.png, sortie1313×1198.
- r2_3.png : générateur intégré, exec-ace0c2df-109c-47d5-ac12-92180b568dc6.png, sortie1321×1191.
- PROMPT_REGION.txt : copie exacte de la version active officielle.
- sha256.json : empreintes des essais et du prompt.
- measure.py / measure2.py : comparaison locale, en lecture seule sur le dépôt.
- all_metrics.py : diagnostic des12 régions, sans modifier les outils officiels.
