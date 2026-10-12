"""Palette maîtresse (voir docs/ART_BIBLE.md). Chaque matériau est une rampe du plus sombre au plus clair."""

OUTLINE = "#120d1c"

PALETTE = {
    # Vide / Corrompus / danger (palette de la fiche Nébulorax)
    "void": ["#1b1e33", "#2c1a4d", "#3a1670", "#6a1fd0", "#c040f0", "#ebd6fa"],
    "corrupt": ["#24142e", "#3b1d4a", "#5a2a68", "#7f3d86", "#a95ba8"],
    "flesh": ["#3b1830", "#5e2648", "#8a3a63", "#c0628a", "#ec9ab6"],
    # Échos et Chasseur
    "obsidian": ["#1a1422", "#2b2238", "#43365a", "#64557f", "#9585b0"],
    "ember": ["#7a2412", "#c2451c", "#f07a2a", "#ffc15e", "#fff1b8"],
    "stone": ["#25272e", "#3b3e47", "#575b66", "#7d828e", "#aab0bb"],
    "moss": ["#1d3b25", "#2f6236", "#4f9446", "#86c95a", "#c8f08a"],
    "glass": ["#163a52", "#2a6f8f", "#4fb3c9", "#9ee8f0", "#e8fdff"],
    "cloth": ["#1f2a44", "#34507a", "#5b86b5", "#a9cfe8", "#eef6ff"],
    "gold": ["#5a3a12", "#9a6a1c", "#d9a531", "#f5d76e", "#fff6c4"],
    "storm": ["#4a3c12", "#8f7a1c", "#d9bb2e", "#f7e46a", "#fffbd0"],
    "bark": ["#2e1f14", "#4a3220", "#6e4c2e", "#977045", "#c49c68"],
    "leaf": ["#173323", "#24543a", "#3f8a4f", "#6fc06a", "#b4ec98"],
    "silver": ["#2a2d3a", "#4a5066", "#7a83a0", "#b2bcd6", "#eef2fb"],
    "danger": ["#4a0f1e", "#8f1d35", "#d43a5c", "#ff7f9a", "#ffd0dc"],
    "char": ["#1f0d0e", "#3a1514", "#5e2219", "#8a3a22", "#b85a33"],
    "shade": ["#140d22", "#24183a", "#3a2760", "#5a3f8e", "#8a6cc2"],
}


def hexrgb(value: str) -> tuple:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def ramp(name: str) -> list:
    return [hexrgb(c) for c in PALETTE[name]]


def outline_for(material: str) -> tuple:
    """Contour sélectif : le ton le plus sombre du matériau, assombri vers le contour global."""
    dark = hexrgb(PALETTE[material][0])
    base = hexrgb(OUTLINE)
    return tuple(int(base[i] * 0.6 + dark[i] * 0.4) for i in range(3))
