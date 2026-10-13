"""Palette maîtresse (voir docs/ART_BIBLE.md).

Chaque matériau est une rampe de 7 tons générée à partir d'une couleur médiane, avec glissement de teinte :
les ombres glissent vers le bleu-violet (teinte de la Faille), les lumières vers l'ambre chaud.
Ce glissement donne la richesse du pixel art « peint » plutôt qu'un simple assombrissement.
"""
import colorsys

OUTLINE = "#0e0a17"
SHADOW_HUE = 262.0  # degrés : violet-bleu des ombres
LIGHT_HUE = 48.0    # degrés : ambre des lumières
TONES = 7

# Matériau : (couleur médiane, intensité du glissement de teinte, luminosité min, luminosité max)
MATERIALS = {
    "void": ("#6a1fd0", 0.35, 0.07, 0.90),
    "corrupt": ("#6a3378", 0.45, 0.07, 0.72),
    "flesh": ("#a24a72", 0.40, 0.08, 0.82),
    "obsidian": ("#2f2a3c", 0.45, 0.05, 0.58),
    "ember": ("#f07a2a", 0.25, 0.18, 0.95),
    "stone": ("#5d616d", 0.45, 0.08, 0.80),
    "moss": ("#4f9446", 0.40, 0.07, 0.86),
    "glass": ("#3fa6c4", 0.30, 0.10, 0.95),
    "cloth": ("#4a77a8", 0.40, 0.08, 0.92),
    "gold": ("#d9a531", 0.30, 0.12, 0.93),
    "storm": ("#e0c232", 0.25, 0.12, 0.95),
    "bark": ("#6e4c2e", 0.45, 0.07, 0.75),
    "leaf": ("#3f8a4f", 0.40, 0.07, 0.85),
    "silver": ("#7c86a3", 0.35, 0.10, 0.96),
    "danger": ("#d43a5c", 0.35, 0.10, 0.90),
    "shade": ("#36265a", 0.40, 0.05, 0.66),
    "char": ("#4a1f18", 0.40, 0.05, 0.60),
    "bone": ("#c9bba0", 0.35, 0.12, 0.96),
    "skin": ("#c08a6a", 0.35, 0.10, 0.92),
}


def hexrgb(value: str) -> tuple:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _hex(rgb) -> str:
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(c)))) for c in rgb)


def _shift_hue(h: float, target: float, amount: float) -> float:
    diff = ((target - h + 180.0) % 360.0) - 180.0
    return (h + diff * amount) % 360.0


def make_ramp(mid_hex: str, shift: float, l_min: float, l_max: float, n: int = TONES) -> list:
    r, g, b = (c / 255.0 for c in hexrgb(mid_hex))
    h, l_mid, s = colorsys.rgb_to_hls(r, g, b)
    h *= 360.0
    l_min, l_max = l_min + 0.035, l_max - 0.07
    ramp = []
    mid = (n - 1) / 2.0
    for i in range(n):
        t = (i - mid) / mid  # -1 (ombre) … +1 (lumière)
        if t < 0:
            hue = _shift_hue(h, SHADOW_HUE, shift * -t)
            light = l_mid + (l_min - l_mid) * (-t) ** 0.9
            sat = s * (1.0 - 0.25 * -t)
        else:
            hue = _shift_hue(h, LIGHT_HUE, shift * t * 0.8)
            light = l_mid + (l_max - l_mid) * t ** 1.1
            sat = min(1.0, s * (1.05 - 0.22 * t * t))
        rgb = colorsys.hls_to_rgb(hue / 360.0, max(0.0, min(1.0, light)), max(0.0, min(1.0, sat)))
        ramp.append(_hex([c * 255.0 for c in rgb]))
    return ramp


PALETTE = {name: make_ramp(*spec) for name, spec in MATERIALS.items()}


def ramp(name: str) -> list:
    return [hexrgb(c) for c in PALETTE[name]]


def outline_for(material: str) -> tuple:
    """Contour du côté ombré : ton le plus sombre du matériau fondu dans le contour global."""
    dark = hexrgb(PALETTE[material][0])
    base = hexrgb(OUTLINE)
    return tuple(int(base[i] * 0.55 + dark[i] * 0.45) for i in range(3))


def lit_outline_for(material: str) -> tuple:
    """Contour du côté éclairé (haut-gauche) : plus coloré, il donne du relief à la silhouette."""
    return hexrgb(PALETTE[material][1])
