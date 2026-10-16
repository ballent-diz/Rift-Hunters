# Habillage de l’arbre du Chasseur — C5

Catalogue : `catalog.json` ; identifiants `ui.hunter_tree.*` dans le manifeste commun.
Les 38 SVG sont sans texte. Le refuge réutilise `assets/ui/menus/refuge-backdrop.png`.
La conception reste celle de `docs/design/ARBRE_DU_CHASSEUR.md`.

- `node_<type>_<état>` : passif, sort, transformant, clé de voûte ; quatre états.
- Verrouillé : cadenas et bord assombri. Apprenable : quatre repères lumineux.
  Appris : coche et contour bleu acier. Activé : double contour ivoire/cyan et coche.
  La couleur seule ne porte donc pas l’état.
- `link_vertical_*`, `link_fork_*` : raccords de même état ; pointillés pour le verrouillage.
- `choice_exclusive` : raccord de choix A/B. Les lettres sont ajoutées par l’interface.
- `slot_*`, `keycap`, `build_*`, `points`, `heading_*`, `panel`, `background` : habillage réutilisable.

Utiliser les marges `patch_margins` des panneaux avec `StyleBoxTexture` ou `NinePatchRect`,
et les `content_rect` pour placer les futures icônes au centre des cadres.
Ne pas étirer un cadre de nœud en rectangle. Importer le SVG à la résolution voulue
pour conserver la netteté, et garder les tailles finales sur des pixels entiers.
Les éléments plein écran doivent appeler `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`.

Les maquettes sont des compositions statiques : leurs glyphes géométriques sont des repères
de placement, pas les illustrations définitives. `mockup_data.json` est un jeu d’exemples visuels,
sans validation de prérequis, sauvegarde, achat ou activation. Ne pas en faire une base de gameplay.

Guide de raccordement C2 et effets : `docs/art/CHASSEUR_C5.md`.
