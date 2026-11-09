#!/usr/bin/env python3
"""Cadres des nœuds d'arbre (Chasseur et Échos) : passifs en cercle sobre, sorts en hexagone doré à liseré.

Écrit assets/ui/hunter_tree/node_passive_<état>.svg et node_spell_<état>.svg (cinq états). Les transformants et
clés de voûte gardent leurs cadres d'origine. Usage : python3 tools/art/build_tree_frames.py
(puis godot --headless --import --path . pour réimporter).
"""
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "assets/ui/hunter_tree"
STATES = ["locked", "learnable", "learned", "active", "upcoming"]
RING = {"locked": "#5c586c", "learnable": "#dfad7a", "learned": "#8393b5", "active": "#a5ebec",
        "upcoming": "#46435a"}
GOLD = {"locked": "#8a7350", "learnable": "#edc18d", "learned": "#edc18d", "active": "#f6d39a",
        "upcoming": "#5e5240"}
IVORY = "#f6dfad"
SPARK = "#ffe2b5"


def _svg(side: int, body: str) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{side}" height="{side}" '
            f'viewBox="0 0 {side} {side}">{body}</svg>\n')


def _lock(x: float, y: float) -> str:
    return (f'<path d="M{x + 3} {y}v-5a5 5 0 0 1 10 0v5" fill="none" stroke="#aaa1b6" stroke-width="2"/>'
            f'<rect x="{x}" y="{y}" width="16" height="12" fill="#aaa1b6"/>'
            f'<rect x="{x + 7}" y="{y + 3}" width="3" height="5" fill="#171629"/>')


def _check(x: float, y: float, color: str) -> str:
    return f'<path d="M{x} {y}l5 5 11-12" fill="none" stroke="{color}" stroke-width="3"/>'


def passive(state: str) -> str:
    """Cercle sobre : un seul anneau à la couleur de l'état, aucun doré."""
    c, r = 40, 34
    body = (f'<circle cx="{c}" cy="{c}" r="{r}" fill="#080b18" stroke="#03050e" stroke-width="9"/>'
            f'<circle cx="{c}" cy="{c}" r="{r}" fill="#101325" stroke="{RING[state]}" stroke-width="2.5"/>')
    if state == "active":
        body += f'<circle cx="{c}" cy="{c}" r="{r - 6}" fill="none" stroke="{IVORY}" stroke-width="1.5"/>'
    if state == "learnable":
        body += f'<path d="M34 6h12M34 74h12M6 34v12M74 34v12" stroke="{SPARK}" stroke-width="4"/>'
    if state in ["learned", "active"]:
        body += _check(13, 54, RING[state])
    if state == "locked":
        body += _lock(52, 20)
    return _svg(80, body)


def _hexagon(c: float, r: float) -> str:
    # Hexagone pointe en haut, inscrit dans un cercle de rayon r.
    h = r * 0.866
    pts = [(c, c - r), (c + h, c - r / 2), (c + h, c + r / 2), (c, c + r), (c - h, c + r / 2), (c - h, c - r / 2)]
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)


def spell(state: str) -> str:
    """Hexagone doré : bord or épais, liseré intérieur à la couleur de l'état, gemme dorée au sommet."""
    c = 48
    body = (f'<polygon points="{_hexagon(c, 44)}" fill="#080b18" stroke="#03050e" stroke-width="9"/>'
            f'<polygon points="{_hexagon(c, 44)}" fill="#15122b" stroke="{GOLD[state]}" stroke-width="3.5"/>'
            f'<polygon points="{_hexagon(c, 38)}" fill="none" stroke="{RING[state]}" stroke-width="2"/>')
    if state == "active":
        body += f'<polygon points="{_hexagon(c, 33)}" fill="none" stroke="{IVORY}" stroke-width="1.5"/>'
    body += (f'<polygon points="48,0 54,6 48,12 42,6" fill="{GOLD[state]}" stroke="#03050e" stroke-width="1.5"/>'
             f'<polygon points="48,84 54,90 48,96 42,90" fill="{GOLD[state]}" stroke="#03050e" stroke-width="1.5"/>')
    if state == "learnable":
        body += f'<path d="M10 40v16M86 40v16" stroke="{SPARK}" stroke-width="4"/>'
    if state in ["learned", "active"]:
        body += _check(15, 60, RING[state])
    if state == "locked":
        body += _lock(64, 26)
    return _svg(96, body)


def main() -> None:
    for state in STATES:
        (OUT / f"node_passive_{state}.svg").write_text(passive(state), encoding="utf-8")
        (OUT / f"node_spell_{state}.svg").write_text(spell(state), encoding="utf-8")
    print(f"{len(STATES) * 2} cadres écrits dans {OUT}")


if __name__ == "__main__":
    main()
