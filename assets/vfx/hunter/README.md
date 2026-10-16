# Effets visuels du Chasseur — C5

Douze familles autonomes : deux premiers sorts et leurs variantes, puis dix familles
partageant `spell_vfx.gd`. Aucune règle de jeu ni interrogation de la partie.
Tous les chemins sont déclarés dans `assets/asset_manifest.json` sous `vfx.hunter.*`.
Charger le champ `scene`, pas `sheet` : celui-ci est une référence graphique de catalogue
ou une texture réutilisée, pas une planche d’animation ou une icône.

- [Contrat général C5](../../../docs/art/CHASSEUR_C5.md)
- [Pilote de Taille fendante et capture en partie](../../../docs/art/TAILLE_FENDANTE_PILOTE.md)
- [Dix autres sorts : variantes, durées, dimensions et API](../../../docs/art/AUTRES_SORTS_C5.md)

`remaining_catalog.json` est régénéré avec `node tools/art/build_remaining_hunter_vfx.mjs`.
Les deux textures existantes de Taille sont les seules images dessinées de ce lot.
Les dernières familles réutilisent ce dessin avec des courbes, des facettes et des mouvements propres.
Les scènes restent `wip` jusqu’à raccordement et validation en jeu par le propriétaire.
