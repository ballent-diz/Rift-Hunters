# Ninja Adventure – Asset Pack (décor)

- **Auteurs** : Pixel-boy et AAA — https://pixel-boy.itch.io/ninja-adventure-asset-pack
- **Licence** : Creative Commons Zero v1.0 (domaine public, `LICENSE.txt`). Usage commercial autorisé,
  modification et redistribution autorisées, crédit non obligatoire (mais apprécié : voir les crédits du jeu).

## Contenu de ce dossier

Seule la partie « décor » du pack est versionnée ici (le pack complet fait ~80 Mo et contient aussi
personnages, monstres, interface, musiques et sons).

| Fichier | Contenu | Provenance |
|---|---|---|
| `tilesets/TilesetFloor.png` | sols à transitions (herbe/terre, sable, neige…) | identique à `content/map/tileset_floor.png` du dépôt de l'auteur (github.com/pixel-boy/NinjaAdventure) |
| `tilesets/TilesetVillageAbandoned.png` | ruines, statues, piliers, pierres moussues, grands arbres | identique à `content/map/tileset_village_abandoned.png` du dépôt de l'auteur |
| `tilesets/TilesetNature.png` | arbres, rochers, souches, buissons, fleurs, cristaux | `Backgrounds/Tilesets` du pack (copie publiée dans github.com/Erioluwa-dev/ninja-ops) |
| `tilesets/TilesetFloorDetail.png` | touffes d'herbe, feuilles, cailloux, ossements | idem |
| `tilesets/TilesetWater.png`, `TilesetHouse.png`, `TilesetElement.png` | eau, maisons, objets | idem |
| `tilesets/TilesetReliefCliff.png`, `TilesetInteriorStone.png` | falaises, dallage de pierre | idem (renommés par ce projet intermédiaire) |
| `v1_superpowers/tileset.png` | première version du pack (temples, glace, cristaux…) | github.com/sparklinlabs/superpowers-asset-packs (CC0) |

Le jeu n'utilise pas ces fichiers directement : `python3 tools/art/build_env.py fractured_plain` en extrait
le sol et les éléments de décor vers `assets/environments/` (dossier exclu des exports : `assets/third_party/*`).
