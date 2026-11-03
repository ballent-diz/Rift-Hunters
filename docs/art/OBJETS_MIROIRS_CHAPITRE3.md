# Cristal-miroir et portails — lot B5/B6

Scènes autonomes pour les cartes13 et14. Le rendu est construit et animé dans Godot4.3, avec facettes de cristal, stries, reflets mobiles, rubans et éclats plafonnés. Aucune ressource tierce. Aucun src/,data/,collision ou manifeste runtime modifié.

- B5 : `res://assets/vfx/objects/mirror_crystal/mirror_crystal.tscn`, racine MirrorCrystal. États idle,charged,burst,debris,hidden. Voir CRISTAL_MIROIR_B5.md.
- B6 : `res://assets/vfx/objects/mirror_portal/mirror_portal.tscn`, racine MirrorPortal. États active,cooldown,enter,exit,hidden. Voir MIROIRS_PORTAILS_B6.md.

Le code de Claude doit confirmer chaque événement avant de jouer le visuel. Les signaux de fin sont graphiques uniquement : ils ne terminent aucune recharge, ne détruisent aucune entité et ne transportent aucun acteur. B5 expose direction/ray_length pour dessiner trois rayons ; leurs dégâts et portée réelle appartiennent au gameplay. B6 reçoit la même tint sur les deux membres d’une paire ; choisir des teintes distinctes pour deux paires, par exemple cyan et vert. Les retours à active après recharge sont commandés par le code appelant.

Les scènes sont réutilisables avec release() puis play(). seek_visual(seconds) fige un aperçu sans émettre de fin. Un seul Node2D par objet ; aucune particule n’a son propre nœud. Aucun grand cercle lumineux au sol.

Les planches de sprites sont des exports du rendu natif Godot, pour aperçu/réutilisation graphique. Elles ne sont pas automatiquement référencées par le manifeste et ne remplacent pas le raccordement aux règles. Les captures et la charge sont des bancs de rendu, pas des combats ; essais dans une vraie partie à faire par le propriétaire/Claude.

## Contrôles et réserves

Import headless puis chargement/rendu natif Godot4.3 : sorties0, aucune erreur dans les journaux. Quatre états de chaque objet, seek, release/reuse et racines sans enfants vérifiés. Captures1280×720, deux GIF de moins3Mo et planche transparente24poses du cristal. Banc avec90sprites Skitterling fixes, pas de combat ni mesure de FPS. La planche du cristal limite ray_length à70 pour contenir les rayons ; la scène autonome conserve240. Style facetté natif plus graphique que le décor peint : validation artistique en partie reste au propriétaire. Aucun test de gameplay invoqué, ces scènes ne sont pas raccordées.

## Actualisation après fusion de main — 3 novembre 2026

`origin/main` (`aee08a9`) a été fusionné par merge ; les entrées B5/B6 et cartes14/15 du ROADMAP sont conservées. Import headless Godot4.3 et banc relancés : 48 captures720p, 24 poses transparentes, zéro erreur de script ou de chargement. Les six fichiers graphiques et scripts des objets sont identiques à la PR90 avant fusion : états, `set_state`/`play`, `seek_visual`, `release` et signaux `finished` inchangés. Le banc vérifie aussi l’émission unique des signaux et l’absence de signal lors d’un seek.

Banc reproductible depuis le dépôt, après import :

```bash
mkdir -p /tmp/rift-mirror-check
godot --path . --resolution 1280x720 --script res://docs/previews/mirror-objects/preview_bench.gd -- /tmp/rift-mirror-check
```
