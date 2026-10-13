"""Plaine fracturée, version map dessinée (fournie par le propriétaire du projet)."""

SPEC = {
    "id": "fractured_plain_map",
    "source": "assets/concepts/incoming/map.fractured_plain/map_source.png",
    # 1254 px agrandis exactement 2 fois : pixels nets.
    "arena_size": 2508.0,
    # Carte de distance : 1 pixel = 8 unités du monde.
    "field_size": 313,
    # Praticable : herbe et terre (teintes jaune-vert à brun clair).
    "walk_hue": (20.0, 100.0),
    "walk_light": (0.2, 0.7),
    "walk_sat": 0.22,
    "min_obstacle_px": 5,
    # Retouches en pixels de la map : dalles des ruines et leurs escaliers (praticables).
    "walk_shapes": [
        ("ellipse", 515, 70, 665, 192),
        ("poly", (565, 175), (625, 175), (625, 215), (565, 215)),
        ("ellipse", 1075, 325, 1205, 425),
        ("poly", (1095, 405), (1155, 405), (1155, 490), (1095, 490)),
        ("ellipse", 835, 645, 1005, 765),
        ("poly", (955, 735), (1015, 735), (1015, 800), (955, 800)),
    ],
    "block_shapes": [],
    "ambient": {"color": "#f4f0b8", "amount": 22},
    "outside_tint": "#06120c99",
}
