"""Plaine fracturée, version map dessinée (fournie par le propriétaire du projet)."""

SPEC = {
    "id": "fractured_plain_map",
    "source": "assets/concepts/incoming/map.fractured_plain/map_source.png",
    # Arène de 1254 unités (1 pixel de la map d'origine = 1 unité) : décor à l'échelle des personnages.
    "arena_size": 1254.0,
    # Image affichée : version agrandie par tools/art/upscale.py (Real-ESRGAN ×4) puis réduite à 1672 px
    # (= 1254 × zoom de la caméra 1,333 : 1 pixel de l'image = 1 pixel d'écran), WebP qualité 92.
    "display": "assets/environments/fractured_plain_map/map.webp",
    # Carte de distance : 1 pixel = 2 unités du monde (assez fin pour les passages étroits).
    "field_size": 627,
    "median": 3,
    # Praticable : herbe et terre (teintes jaune-vert à brun clair).
    "walk_hue": (20.0, 100.0),
    "walk_light": (0.2, 0.7),
    "walk_sat": 0.22,
    "min_obstacle_px": 5,
    # Départ du joueur : au moins à cette distance (unités) de tout obstacle.
    "start_clearance": 50.0,
    # Retouches en pixels de la map : dalles des ruines et leurs escaliers (praticables).
    "walk_shapes": [
        # Place circulaire du nord et son escalier.
        ("ellipse", 505, 58, 700, 152),
        ("poly", (565, 140), (630, 140), (630, 205), (565, 205)),
        # Dalles fracturées de l'ouest (deux zones de faille violettes).
        ("poly", (15, 390), (150, 385), (190, 450), (180, 545), (60, 548), (15, 500)),
        ("poly", (20, 800), (150, 795), (210, 845), (200, 900), (60, 905), (20, 870)),
        # Place des ruines de l'est et son escalier.
        ("ellipse", 1040, 340, 1215, 470),
        ("poly", (1095, 455), (1160, 455), (1160, 535), (1095, 535)),
        # Faille violette de l'est (sur l'herbe).
        ("ellipse", 1100, 580, 1250, 690),
        # Place centrale et son escalier.
        ("ellipse", 800, 662, 1008, 796),
        ("poly", (945, 750), (1005, 750), (1005, 825), (945, 825)),
    ],
    "block_shapes": [],
    "ambient": {"color": "#f4f0b8", "amount": 22},
    "outside_tint": "#06120c99",
}
