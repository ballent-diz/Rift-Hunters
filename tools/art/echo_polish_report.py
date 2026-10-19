#!/usr/bin/env python3
"""Contrôle les exports natifs et rassemble les seize Échos, sans retoucher les ressources du jeu."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/previews/echos-animations'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--images-only', action='store_true')
    args = parser.parse_args()
    original = json.loads((ROOT / 'assets/vfx/echoes/origin_catalog.json').read_text(encoding='utf-8'))
    newer = json.loads((ROOT / 'assets/vfx/echoes/catalog.json').read_text(encoding='utf-8'))
    specs = [(s['id'], s['name'], s['spells'][0][0], s['spells'][1][0]) for s in original]
    specs += [(s['id'], s['name'], s['base'], s['alt']) for s in newer]
    board = Image.new('RGB', (1280, 816), '#101326')
    draw = ImageDraw.Draw(board)
    font = ImageFont.truetype(str(ROOT / 'assets/fonts/inter/Inter-Variable.ttf'), 14)
    rows = ['# Animations des seize Échos — reprise Godot', '',
            '[Vue d’ensemble des seize Échos](planche.png). Chaque vignette renvoie ci-dessous à sa capture complète.', '',
            'Rendus natifs 1280 × 720 dans une vraie partie gelée, avec 90 Corrompus, profil isolé en lecture seule.',
            'Le présentateur déclenche les effets sans dégâts ; les raccordements C7 encore absents restent à Claude.',
            'Exports sans son, fenêtres fermées automatiquement à la fin.', '',
            '| Écho | Capture | Attaque | Technique | Second sort |', '|---|---|---|---|---|']
    animations = []
    for i, (identity, name, base, alt) in enumerate(specs):
        image = Image.open(OUT / f'{identity}.png')
        assert image.size == (1280, 720), identity
        x, y = (i % 4) * 320, (i // 4) * 204
        board.paste(image.resize((320, 180), Image.Resampling.LANCZOS), (x, y))
        draw.text((x + 7, y + 183), name, font=font, fill='#f5dfc6')
        rows.append(f'| {name} | [Image]({identity}.png) | [Attaque]({identity}_attack.gif) | '
                    f'[{base}]({identity}_{base}.gif) | [{alt}]({identity}_{alt}.gif) |')
        if args.images_only:
            continue
        for effect in ['attack', base, alt]:
            with Image.open(OUT / f'{identity}_{effect}.gif') as gif:
                assert gif.size == (1280, 720), (identity, effect, gif.size)
                assert gif.n_frames >= 8, (identity, effect, 'animation figée')
                milliseconds = 0
                for frame in range(gif.n_frames):
                    gif.seek(frame)
                    milliseconds += gif.info.get('duration', 0)
                animations.append(dict(echo=identity, effect=effect, frames=gif.n_frames, duration_ms=milliseconds))
    board.save(OUT / 'planche.png')
    if args.images_only:
        print('Seize captures contrôlées et vue d’ensemble créée.')
        return
    assert len(animations) == 48
    rows += ['', '## Contrôles et limites', '',
             'Les deux contrats couvrent 77 scènes : 16 attaques, 32 sorts, 13 statuts et 16 indicateurs.',
             'Plafond commun de 24 émetteurs ; niveau de détail réduit au-delà de 6 effets, sans changement des règles.',
             'performance.json conserve les mesures hors écran sur Intel Iris Xe, 90 Corrompus et 24 effets.',
             'Elles incluent les attentes d’affichage et ne valident pas 60 images/s ni le coût de l’IA en partie.',
             '[Détail de la reprise](../../art/ANIMATIONS_ECHOS_VISIBILITE.md).', '']
    (OUT / 'README.md').write_text('\n'.join(rows), encoding='utf-8')
    (OUT / 'controle-gif.json').write_text(json.dumps(animations, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('16 captures, 48 GIF animés en 1280×720 et durées contrôlés.')


if __name__ == '__main__':
    main()
