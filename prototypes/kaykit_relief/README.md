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

### Déplacement des sprites dans le décor 3D

Les positions physiques restent exactes ; l'image est interpolée entre deux pas physiques pour éviter les à-coups
quand la cadence de rendu diffère des 60 pas/s. La caméra suit cette même position affichée. Les téléportations
réinitialisent les deux positions pour éviter une traversée visuelle de la carte.

Le Chasseur atteint sa vitesse en environ 0,07 s et freine en environ 0,06 s : une transition courte, sans inertie
prolongée. Les diagonales gardent la même vitesse que les axes. L'esquive garde son impulsion et sa direction.
L'orientation gauche/droite ne change qu'après une intention horizontale suffisante maintenue 0,12 s ; les petites
corrections sur un trajet presque vertical ne retournent plus le dessin à chaque image.

Le cycle de marche avance avec la distance réellement parcourue et se conserve lors des virages. Un personnage
bloqué par un pilier cesse de piétiner. Les dessins d'origine restent à leur cadence propre : aucune interpolation
floue des images de la planche n'est ajoutée.

Cendrelame ralentit près de sa place de suivi, s'arrête à environ 1,5 m et repart au-delà de 2,4 m. Cette marge évite
les départs/arrêts incessants près du Chasseur. Un nouveau chemin n'est demandé que si la cible a suffisamment bougé,
avec un intervalle minimal ; la navigation conserve ses collisions et ses passages.

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
Sans affichage (`--headless`), les mêmes contrôles physiques s'exécutent sans captures.
Les résultats retenus figurent dans `verification.json` ; les captures légères dans `docs/previews/kaykit-relief/`
à la racine du dépôt.

Contrôles de fluidité : `godot --headless --path . --fixed-fps 120 -- --verify-motion --out=<dossier_absolu>`.
Ils mesurent l'orientation sous bruit horizontal, les vrais demi-tours, le freinage, la vitesse diagonale,
les positions affichées entre pas physiques, l'arrêt d'animation contre un obstacle et la stabilité de l'Écho.
Rapport : `motion_verification.json`. Référence avant modification : commit `6603a060`, 59 retournements/s dans
l'exercice de bruit et aucune position intermédiaire affichée ; les mesures décrivent ce scénario contrôlé.
Ajouter `--capture-motion` avec un rendu graphique pour produire 360 images PNG à 60 images/s (rendu simulé à 120).
La vidéo `docs/previews/kaykit-relief/deplacement_fluide_60fps.mp4` est encodée à 60 images/s pour juger le mouvement ;
le GIF réduit sert seulement d'aperçu. Cette capture à pas de temps fixé n'est pas un benchmark des performances.

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
