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
        ("ellipse", 445, 40, 715, 172),
        ("poly", (565, 150), (645, 150), (645, 220), (565, 220)),
        # Faille de l'ouest.
        ("ellipse", -20, 330, 185, 490),
        # Place des ruines de l'est et son escalier.
        ("ellipse", 1085, 385, 1290, 505),
        ("poly", (1095, 470), (1160, 470), (1160, 545), (1095, 545)),
        # Faille de l'est.
        ("ellipse", 1140, 600, 1290, 710),
        # Place du sud-est et son escalier.
        ("ellipse", 895, 745, 1105, 880),
        ("poly", (1020, 840), (1095, 840), (1095, 920), (1020, 920)),
        # Faille du sud-ouest.
        ("ellipse", -20, 885, 150, 1010),
    ],
    "block_shapes": [],
    "ambient": {"color": "#f4f0b8", "amount": 22},
    "outside_tint": "#06120c99",
}
