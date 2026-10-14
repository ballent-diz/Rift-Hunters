# Ruines des Cascades

Carte continue reconstruite à partir des trois images fournies, avec des raccords organiques, des routes dégagées et de grandes places de manœuvre. Le nom visible remplace « Les Trois Failles » ; l’identifiant three_rifts reste inchangé pour préserver les préférences des sauvegardes.

Départ au nord-ouest, devant l’entrée des ruines. Le premier pont est cassé et infranchissable, même en ruée ; le détour passe par les terrasses du nord. Le second pont permet d’atteindre la plateforme violette. Les petits cailloux sur les routes sont décoratifs.

Source et prompts ImageGen intégré : assets/concepts/incoming/map.three_rifts/. Upscale ×4 avec tools/art/upscale.py et RealESRGAN_x4plus ; texture de 8688 × 2896 pixels, WebP sans perte (égalité pixel par pixel vérifiée). Le filtrage linéaire des textures à haute résolution évite les gros pixels à l’écran. L’échelle du décor est vérifiée avec le Chasseur et un Écho visibles.

Collisions : python tools/art/build_cascade_ruins.py (NumPy, Pillow, SciPy). Champ de 1881 × 627 pixels, arène de 3762 × 1254 unités. Validation de la connexité avec marge de 16 unités et sur la grille de navigation du jeu. Les obstacles gardent l’eau et les falaises fermées ; les ponts et places dégagés sont retouchés dans le masque.

Captures : tools/level_preview.tscn -- --out=<dossier>, dans un profil de test séparé. Les consignes pour les futures cartes sont dans docs/MAP_GUIDELINES.md.
