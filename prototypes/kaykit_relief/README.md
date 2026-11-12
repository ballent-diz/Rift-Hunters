# Essai KayKit : relief et collisions

Prototype Godot **4.3**, indépendant de la campagne. Coût des décors et de l'éditeur : **0 €**.
Caméra orthographique, décors 3D modulaires, Chasseur et Cendrelame d'origine affichés en sprites dans le monde 3D.

## Lancer

Sous Windows, double-cliquer sur `lancer.cmd` (utilise le Godot 4.3 déjà installé dans Downloads).
Autre installation : ouvrir ce **project.godot**, puis F6 sur `main.tscn` ou F5.
En ligne de commande : `godot --path <ce_dossier>`.

- ZQSD, WASD ou flèches : déplacement ; espace : esquive.
- Clic gauche maintenu : projectiles PixelFX vers la souris. Les abris arrêtent les tirs ; les ennemis peuvent être touchés.
- Molette : zoom ; C : suivi du Chasseur / vue d'ensemble ; V : afficher les collisions réelles.
- R : recommencer ; F2 : français / anglais ; Échap : quitter.

## Ce qui se teste

- Terrasse à **2 m**, accessible par l'escalier, avec descente et gravité réelles.
- Solides : murs, fondations de terrasse, piliers, caisses et tonneaux.
- Porte ouverte sous l'arche, passage au centre réellement libre.
- Profondeur devant/derrière le décor par le rendu 3D, sans masque peint.
- Navigation 3D de Cendrelame et de six ennemis, y compris dans l'escalier.
- Collisions de projectiles avec les objets et les ennemis, aux hauteurs de tir.

Le combat est volontairement simplifié : pas de dégâts reçus, de compétences complètes, de loot ou de progression.
Les ennemis approchent le Chasseur ; ils servent ici de cibles et de sondes de navigation. Cendrelame suit le joueur.
Les sprites conservent les animations existantes, mais le contrôleur est propre à ce laboratoire.
Le style KayKit reste plus cartoon que la direction artistique actuelle ; cet essai sert aussi à juger cet écart.

## Modifier la carte

Ouvrir `level.tscn` dans l'éditeur 3D. Chaque module est une scène de `modules/` : on peut le déplacer,
le dupliquer ou le tourner ; **sa collision l'accompagne**. Lancer `main.tscn` pour jouer la carte modifiée.
Conserver l'accès de l'escalier à la terrasse. La navigation est recalculée au lancement.

`build_modules.gd` reconstruit les scènes à partir des GLB :
`godot --headless --path . --script build_modules.gd`.
La rampe de collision sous l'escalier permet une montée fluide ; elle remplace les petites faces verticales des marches.
L'arche provient du GLB `wall_doorway` dont le battant fermé est retiré à la préparation du module.
Les collisions d'abris utilisent les maillages ou des volumes convexes ; les sols utilisent des boîtes jointives.

`arena.gd` conserve la recette initiale d'assemblage ; une fois `level.tscn` créé, le jeu charge cette scène éditable.
Pour régénérer cette composition initiale, déplacer temporairement `level.tscn`, puis lancer avec `-- --save-level`.

## Vérification reproductible

Après `godot --headless --editor --import --path .` :
`godot --path . --resolution 1600x900 --fixed-fps 60 -- --verify --out=<dossier_absolu>`.

Le vérificateur exerce les vrais corps physiques : arche, montée/descente, arrêt et contournement d'un pilier,
tirs bloqués ou traversants, impact sur ennemi, façade de terrasse et suivi de l'Écho par l'escalier.
Il produit le rapport JSON, les captures et les images de mouvement. Il nécessite un rendu graphique pour les captures.
Les résultats retenus figurent dans `verification.json` ; les captures légères dans `docs/previews/kaykit-relief/`
à la racine du dépôt.

## Sources et limites

- Kay Lousberg, **KayKit Dungeon Remastered 1.0**, dépôt officiel :
  https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0 ; licence **CC0** dans `assets/kaykit/LICENSE.txt`.
  Page du pack actuel : https://kaylousberg.itch.io/kaykit-dungeon-pack.
- Une sélection de 13 modèles gratuits seulement, avec une teinte de matériau et un éclairage adaptés à cet essai.
- Sprites Chasseur, Cendrelame et Skitterling : copies inchangées du manifeste Rift Hunters au moment de l'essai.
- Effets : feuilles PixelFX existantes du jeu (`fireball/calcines`, `hit/violet`, outil PixelFX sous MIT).

Aucune modification de `src/`, `data/`, du manifeste, des cartes ni du projet principal. Le dossier parent
`prototypes/.gdignore` empêche l'import du sous-projet par le jeu principal.
**Aucune migration de la simulation 2D de campagne n'est réalisée par cet essai.** Adopter la 3D nécessiterait ensuite
d'adapter mouvements, navigation et combat du jeu complet et de vérifier les performances avec des hordes.
