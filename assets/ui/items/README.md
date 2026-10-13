# Illustrations des améliorations et objets

30 illustrations transparentes générées séparément avec le mode intégré image_gen : 16 améliorations, 12 reliques et les offres soin/éclats. La direction artistique reprend le refuge nocturne japonais : indigo, violet, cyan, cuivre et lumière de lanterne.

Les fichiers PNG originaux sont conservés dans upgrades/, relics/ et offers/. Les imports Godot sont limités à 512 pixels, sans mipmaps, avec filtrage nearest dans les menus. catalog.json associe les identifiants existants aux textures ; prompts.json conserve les descriptions et prompts de génération.

Les illustrations apparaissent dans les choix de niveau, les coffres, les reliques découvertes du Bestiaire et les recherches du laboratoire. Aucune valeur ni règle de gameplay ne dépend de ces ressources. Les portraits des Échos conservent les visuels du jeu.

Prévisualisation : tools/item_gallery.tscn avec --kind=upgrade|relic|offer --locale=fr --out=<dossier>. Captures réelles : docs/previews/items/.

Validation : 154 scripts compilés, 128 tests réussis, captures à 1600×900 et 1024×768.
