# Le Gué des Brumes — livraison de l’image

Carte 4 du chapitre 1, « Le Val des Cascades ». Composition et correction des accès validées par le propriétaire le 20 octobre 2026.

## Fichiers livrés

- Image de présentation : [map.webp](../../assets/environments/mist_ford/map.webp), 6144 × 4096 pixels, WebP sans perte.
- Image à peindre : [carte_a_peindre.png](../../assets/concepts/incoming/map.mist_ford/collision/carte_a_peindre.png), 5016 × 3344 pixels : un pixel par unité du plan de travail, format intermédiaire de six cases, rapport 3:2.
- Sources, prompts exacts, références et empreintes SHA256 : [dossier de génération](../../assets/concepts/incoming/map.mist_ford/source/).
- Provenance et préparation : [job.json](../../assets/concepts/incoming/map.mist_ford/job.json).

La source générée et sa correction font 1536 × 1024 pixels. La présentation est une restauration et un agrandissement ×4 par Real-ESRGAN, modèle realesr-animevideov3 ; elle n’est pas une génération native à 6144 pixels. Les détails très fins restent limités par la source. [Outil et version](https://github.com/xinntao/Real-ESRGAN/releases/tag/v0.2.5.0). Le programme et ses exemples ne sont pas inclus dans le dépôt.

## Composition approuvée

Delta au matin, eau claire aux gués, eau profonde bleue, saules et roseaux dorés, pierre grise et ruines en bordure. Les trois secteurs signalés (sud-ouest, sud-est et nord-est) ont été reliés visuellement par une correction unique des chemins de rive. La composition validée est conservée.

Repères visuels approximatifs, en pourcentage depuis le coin supérieur gauche :

| Repère | Centre X / Y |
|---|---|
| Socle vide de l’île centrale | 50 % / 44 % |
| Départ proposé, près du socle | 48 % / 46 % |
| Gués nord, ouest, est, sud | 50 / 22 ; 26 / 48 ; 75 / 47 ; 50 / 72 % |
| Pont de pierre au nord-ouest | 22 % / 27 % |
| Accès de rive possibles | 12 / 12 ; 88 / 16 ; 14 / 76 ; 87 / 74 % |

Ces repères ne sont pas des données de collision ni des positions imposées au niveau.

## Passage au propriétaire

À sa demande, le propriétaire prend entièrement en charge les collisions et les rectangles. Aucun masque, rectangle, champ de navigation ou arène n’est produit. Le dossier collision contient seulement l’image vierge à peindre. La proportion de terrain réellement praticable et les largeurs finales ne sont donc pas certifiées par cette livraison d’image.

Claude raccordera ensuite les gués, l’autel, les vagues et le gardien. L’environnement n’est pas encore déclaré au manifeste : son champ et ses données seront fournis avec cette intégration. Aucun fichier src/ ou data/ n’est modifié.

## Références et contrôle visuel

Références jointes au générateur : Plaine fracturée (netteté/échelle), Ruines des Cascades et Hautes Terres d’Orage (style), Bois des Lucioles (source conservée depuis la PR #36).

- [Carte entière](../previews/gue-des-brumes/carte-entiere.png).
- [Comparaison des quatre décors du chapitre](../previews/gue-des-brumes/comparaison-chapitre.png).
- [Plaine fracturée, référence complémentaire](../previews/gue-des-brumes/plaine.png).
- [Gué au zoom du jeu](../previews/gue-des-brumes/gue.png).

Les vues individuelles sont rendues dans Godot à 1280 × 720, zoom 1,3333, avec les sprites réels du Chasseur et de Mousseroc et leur échelle actuelle. Ce sont des aperçus de décor, sans partie ni collisions. Les cadrages et paramètres sont dans comparaison.json. Le shader de détail des deux cartes existantes est repris ; aucun filtre supplémentaire n’est ajouté au Gué.

Reproduction : lancer tools/art/crop_mist_ford.py, puis Godot avec --audio-driver Dummy --resolution 1280x720 res://tools/art/preview_mist_ford.tscn. Les captures sont silencieuses, hors écran, puis Godot se ferme.

Contrôle ciblé de fin de lot : import Godot, chargement des cinq cadrages, export des cinq captures à la taille attendue, vérification des dimensions et des empreintes source. Pas de suite complète pour cette livraison d’images, conformément à AGENTS.md. La validation de circulation en jeu suit la peinture des collisions par le propriétaire.
