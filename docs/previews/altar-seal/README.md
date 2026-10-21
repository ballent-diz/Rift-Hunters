# Sceau ancien — contrat de branchement

Objet peint généré, puis énergies animées et précalculées avec Godot 4.3. Aucune source tierce.

- Visuel : `object.altar_seal`, feuille `assets/sprites/objects/altar_seal/sheet.png`.
- Atlas 2048 × 1280, 8 colonnes × 5 lignes ; cellules 256 × 256 ; ancre (128, 200) ; échelle 1.
- Socle visible : 220 px de large. Emprise de jeu demandée : rayon 70 unités ; aucune collision ajoutée par ce lot.
- Icône transparente : `assets/ui/icons/objects/altar_seal.png`, 64 × 64.
- `intact` : ligne 0, 8 images à 8 FPS, boucle 1 s.
- `damaged` : ligne 1, 8 images à 8 FPS, boucle 1 s.
- `sealed` : ligne 2, 8 images à 8 FPS, boucle 1 s.
- `hit` : ligne 3, 4 images à 16 FPS, 0,25 s, sans boucle ; les quatre cellules restantes sont transparentes.
- `seal_wave` : ligne 4, 8 images à 12 FPS, 0,667 s, sans boucle, contenue dans la cellule ; aucune feuille 512 nécessaire.

Les trois bases de pierre restent immobiles. Les gravures et filaments bleu-blanc animent l'état intact ; les fissures violettes animent l'état endommagé ; l'état scellé conserve son anneau calme bleu-blanc.
L'impact ajoute des éclats rouge-violet localisés, la purification une onde et des particules bleu-blanc.
Le rendu précalculé ne crée aucun émetteur ni particule en partie. Aucune barre de vie peinte.

Sources et prompts exacts : `assets/concepts/incoming/object.altar_seal/source/`.
Reproduction : Godot en rendu compatible, audio Dummy, script `tools/art/bake_altar_seal.gd`,
arguments `--input=<source/bases> --out=<sortie> --center=128,164 --core=128,82`.
Le répertoire de sortie contient la feuille et les images séparées ; recopier la feuille vers le chemin du manifeste.

Claude raccorde les changements d'état, les impacts et la purification. Aucun fichier de `src/` n'est modifié.

Validation : Godot 4.3, import puis `tools/run_tests.sh assets` : **313 assets valides, 0 erreur, 0 placeholder**. Le rapport des boucles et de transparence figure dans `render-check.json`.
