# Filtre pixel — prototype conservé pour Claude

Essai réalisé les 4 et 5 novembre 2026 dans Godot 4.3. Ces fichiers sont autonomes :
aucun appel n'est ajouté au jeu et aucun filtre n'est activé par cette livraison.

## Fichiers et utilisation

Garder `rift_pixel_filter.gd` et `rift_pixel.gdshader` dans le même dossier.
Le script construit le matériau, calcule la densité de la texture depuis la taille
du monde et ancre la grille dans le monde, avec la même origine pour les tuiles.

```gdscript
# ground : ArenaGround déjà initialisé, avec un EnvironmentSet de type map.
# Conserver cette instance tant que le filtre est utilisé.
var pixel_filter = preload("res://tools/art/pixel_filter/rift_pixel_filter.gd").new()
pixel_filter.apply(ground, "graphique")

# Pour revenir au matériau et au filtrage précédents :
pixel_filter.restore(ground)
```

Préréglages :

- `fine` : premier essai discret.
- `affirme` : premier essai plus marqué.
- **`graphique` : réglage utilisé dans les dernières captures des chapitres 1 à 4.**
- `original` : appelle la restauration du matériau et du filtrage précédents.

Le traitement combine grille de pixels, regroupement local des couleurs, contraste
et quantification luminance/chrominance. Il agit sur le décor dessiné par ArenaGround,
sans modifier les images sources, dimensions, collisions, personnages, effets ou UI.
Il remplace temporairement le matériau du sol, y compris son éventuel effet de netteté.

## Retours du propriétaire et périmètre

- Prototype gardé de côté, sans généralisation autorisée par cette livraison.
- Les captures des chapitres 1 et 4 sont les cibles appréciées. Le filtre était moins
  flagrant sur les cartes des chapitres 2 et 3 : harmonisation encore à effectuer.
- La référence graphique jointe par le propriétaire est une image redessinée par
  génération, pas le résultat de ce shader. Ne pas promettre une reproduction exacte.
- Les problèmes de proportions du décor, notamment au glacier, restent distincts.
  Le filtre ne les corrige pas ; ne pas agrandir globalement les personnages.
- Chapitres 1 à 3 : captures dans le jeu ; chapitre 4 : vrai décor détaillé dans un
  banc statique, sans simulation de navigation ou de combat. Zoom identique 1,3333.

## Vérifications et limites

Les fichiers publiés sont identiques aux deux fichiers du prototype local capturé.
Chargement et rendu effectifs sous Godot 4.3 / GLES3 sur Intel Iris Xe ; contrôle ciblé
de l'activation, de la restauration du matériau et du filtrage, et de la conservation
des pixels sources et du champ de collisions réussi. Les bancs de partie émettaient
des avertissements de ressources encore utilisées à leur fermeture ; aucune absence
totale d'avertissements n'est revendiquée. Aucun test complet du jeu ni mesure de
performances en combat. Les captures et les images générées ne sont pas poussées.

Avant intégration : garder l'activation optionnelle, vérifier mouvement, raccords de
tuiles et coût de rendu, puis demander le choix du propriétaire avant généralisation.
L'adaptateur suppose un décor de type map valide ; il ne gère pas les sols procéduraux.
Il conserve des références aux sols traités : restaurer les sols avant de les libérer.
