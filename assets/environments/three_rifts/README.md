# Les Trois Failles

Niveau sélectionnable depuis Refuge → Expédition → Arène. Les PNG fournis L1, L1p2 et L1p3 sont conservés à leur résolution originale (1254 × 1254) et affichés de gauche à droite, sans déformation, sur une arène de 3762 × 1254 unités.

Le départ sûr se trouve dans L1. field.png contient les collisions : eau, falaises et vide bloqués ; routes, ponts et plateforme violette accessibles. Les raccords visuels des illustrations restent visibles, notamment le décalage des deux ponts entre L1p2 et L1p3. Les retouches du masque ouvrent leurs tabliers et les accès aux routes.

Le niveau réutilise les vagues, événements, difficulté et boss de la Plaine fracturée. Les anciennes arènes conservent leur décor et leurs règles. Aucun déclencheur de boss spécifique à la plateforme violette n’est ajouté.

Régénération des collisions : python tools/art/build_three_rifts.py (Pillow, NumPy, SciPy). Vérification des trois régions avec une marge de 16 unités, puis sur la grille de navigation du jeu ; collision_report.json conserve le résultat.

Captures : tools/level_preview.tscn -- --out=<dossier>, avec un profil de test séparé. Pour simuler une partie : tools/screenshot.tscn -- --arena=three_rifts --times=20 --out=<dossier>.
