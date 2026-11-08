#!/usr/bin/env python3
"""Importe les sept planches de l'Abyssarque en feuilles de phase compatibles avec Godot."""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image
import import_sheet
from sprite_source_tools import digest, pack, split_source, write

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / 'assets/concepts/incoming/boss.abyssarch'
CELL = [1408, 1152]
PACK_ANCHOR = [704, 1100]
RUNTIME_ANCHOR = [704, 650]
WORLD_SCALE = .5
HEIGHT = 900
PHASES = {
    'A': ('boss.abyssarch', ['idle', 'move', 'attack']),
    'B': ('boss.abyssarch.roots', ['roots_entry', 'roots_idle', 'roots_attack']),
    'C': ('boss.abyssarch.magma', ['magma_entry', 'magma_idle', 'magma_attack']),
    'D': ('boss.abyssarch.crystal', ['crystal_entry', 'crystal_idle', 'crystal_attack']),
    'E': ('boss.abyssarch.ice', ['ice_entry', 'ice_idle', 'ice_attack']),
    'F': ('boss.abyssarch.rift', ['final_entry', 'ray_sweep', 'summon']),
    'G': ('boss.abyssarch.death', ['collapse', 'eye_close']),
}


def shared_palette(poses):
    opaque = np.concatenate([np.asarray(p)[np.asarray(p)[:, :, 3] > 0, :3] for p in poses])
    side = 4096
    rows = (len(opaque) + side - 1) // side
    canvas = np.tile(opaque[-1], (rows * side, 1))
    canvas[:len(opaque)] = opaque
    image = Image.fromarray(canvas.reshape(rows, side, 3)).quantize(colors=32, method=Image.Quantize.FASTOCTREE)
    palette = np.array(image.getpalette(), dtype=np.uint8).reshape(-1, 3)[:32]
    Image.fromarray(palette.reshape(1, 32, 3)).save(FOLDER / 'palette.png')


def indexed_lossless(path):
    """Compression sans perte : 32 couleurs opaques et un indice transparent."""
    rgba = Image.open(path).convert('RGBA')
    a = np.asarray(rgba)
    colors = np.unique(a[a[:, :, 3] > 0, :3], axis=0)
    assert len(colors) <= 32
    palette = Image.new('P', (1, 1))
    values = colors.ravel().tolist()
    palette.putpalette(values + values[-3:] * (256 - len(colors)))
    indexed = rgba.convert('RGB').quantize(palette=palette, dither=Image.Dither.NONE)
    indices = np.asarray(indexed).copy()
    indices[a[:, :, 3] == 0] = 255
    result = Image.fromarray(indices, 'P')
    result.putpalette(palette.getpalette())
    result.save(path, transparency=255, optimize=True)
    check = np.asarray(Image.open(path).convert('RGBA'))
    assert np.array_equal(a[:, :, 3], check[:, :, 3])
    assert np.array_equal(a[a[:, :, 3] > 0, :3], check[a[:, :, 3] > 0, :3])


def fit_icon(sheet_path, entry, phase):
    """Une icône technique réduite, sans rogner les grands corps à 64 pixels."""
    name = 'idle' if phase != 'G' else 'collapse'
    image = Image.open(sheet_path).convert('RGBA')
    row = entry['animations'][name]['row']
    pose = image.crop((0, row * CELL[1], CELL[0], (row + 1) * CELL[1]))
    pose = pose.crop(pose.getbbox())
    factor = 58 / max(pose.size)
    pose = pose.resize((max(1, round(pose.width * factor)), max(1, round(pose.height * factor))),
                       Image.Resampling.NEAREST)
    icon = Image.new('RGBA', (64, 64))
    icon.paste(pose, ((64 - pose.width) // 2, (64 - pose.height) // 2))
    icon.save(ROOT / entry['icon'].removeprefix('res://'))


def run(preview_dir):
    sources, records = {}, []
    for letter in PHASES:
        poses, info = split_source(FOLDER / ('source/planche_' + letter + '.png'), 2 if letter == 'G' else 3)
        sources[letter] = poses
        records.append(info)
        pack(poses, 2 if letter == 'G' else 3, FOLDER / ('planche_' + letter + '.webp'))
    shared_palette([pose for poses in sources.values() for pose in poses])
    # Une pose de repos finale est réutilisée depuis F ; elle n'ajoute aucune pose peinte.
    pack([sources['F'][5]] * 6, 1, FOLDER / 'final_idle.webp')
    jobs = FOLDER / 'jobs'
    jobs.mkdir(exist_ok=True)
    catalog = []
    normalization = []
    for letter, (visual_id, names) in PHASES.items():
        poses = sources[letter]
        first = poses[:6]
        reference = sorted(p.height for p in first)[3]
        target = round(HEIGHT * reference / first[0].height)
        factor = target / reference
        assert all(round(p.width * factor) <= CELL[0] - 4 and
                   round(p.height * factor) <= PACK_ANCHOR[1] - 2 for p in poses), letter
        prefix = '' if letter == 'A' else '../'
        animations = [{'name': name, 'source': prefix + 'planche_' + letter + '.webp',
                       'grid': [6, 2 if letter == 'G' else 3], 'row': row, 'frames': 6,
                       'fps': 8 if name in ['idle', 'move'] or name.endswith('_idle') else 10,
                       'loop': name in ['idle', 'move'] or name.endswith('_idle'),
                       'frame_offsets': [[0, 0] for _ in range(6)]} for row, name in enumerate(names)]
        aliases = {}
        empty = [{'name': 'death', 'fps': 10, 'loop': False}]
        if letter in 'BCDE':
            aliases = {'idle': names[1], 'move': names[1], 'attack': names[2]}
        elif letter == 'F':
            animations.append({'name': 'idle', 'source': prefix + 'final_idle.webp', 'grid': [6, 1],
                               'frames': 1, 'fps': 1, 'loop': True, 'frame_offsets': [[0, 0]]})
            aliases = {'move': 'idle', 'attack': 'ray_sweep'}
        elif letter == 'G':
            empty = [{'name': 'hidden', 'fps': 1, 'loop': False}]
            aliases = {'death': 'collapse', 'idle': 'hidden', 'move': 'hidden', 'attack': 'hidden'}
        job = {'visual_id': visual_id, 'master_visual_id': 'boss.abyssarch', 'phase': letter,
               'cell': CELL, 'anchor': PACK_ANCHOR, 'runtime_anchor': RUNTIME_ANCHOR, 'scale': WORLD_SCALE,
               'anchor_mode': 'mass', 'target_height': target, 'status': 'final', 'background': 'alpha',
               'outline': False, 'colors': 32, 'palette_source': prefix + 'palette.png', 'preview_zoom': 1,
               'animations': animations, 'aliases': aliases, 'empty_animations': empty,
               'integration': 'Claude : changer le visual_id selon la phase. Mort : G/collapse, eye_close, hidden.',
               'boss_size': 'Référence 450u ; Nivorath existant 150u. Aucun multiplicateur de rang dans le banc.'}
        if letter == 'A':
            job['phase_jobs'] = {key: 'jobs/' + key + '.json' for key in PHASES if key != 'A'}
        path = FOLDER / 'job.json' if letter == 'A' else jobs / (letter + '.json')
        write(path, job)
        entry = import_sheet.run(str(path), preview_dir=str(preview_dir))
        sheet_path = ROOT / entry['sheet'].removeprefix('res://')
        image = Image.open(sheet_path).convert('RGBA')
        changed = False
        for animation in animations:
            row = entry['animations'][animation['name']]['row']
            for i in range(animation['frames']):
                box = image.crop((i * CELL[0], row * CELL[1], (i + 1) * CELL[0], (row + 1) * CELL[1])).getbbox()
                assert box
                dx = max(0, 2 - box[0]) - max(0, box[2] - CELL[0] + 2)
                if dx:
                    animation['frame_offsets'][i][0] += dx
                    changed = True
        if changed:
            write(path, job)
            entry = import_sheet.run(str(path), preview_dir=str(preview_dir))
        fit_icon(sheet_path, entry, letter)
        indexed_lossless(sheet_path)
        catalog.append({'phase': letter, 'visual_id': visual_id, 'job': path.relative_to(ROOT).as_posix(),
                        'source_sheets': 1, 'painted_poses': len(poses)})
        normalization.append({'phase': letter, 'source_first_pose_height': first[0].height,
                              'import_reference_height': reference, 'target_height': target,
                              'uniform_source_factor': factor, 'first_pose_world_height': round(first[0].height * factor * .5, 3)})
        print('IMPORTED', letter, visual_id, 'world height', round(first[0].height * factor * .5, 2), flush=True)
    write(FOLDER / 'source/normalization.json', {'sheets': records, 'phases': normalization,
          'source_poses': 120, 'reused_runtime_pose': 'F/idle reprend F entrée colonne6',
          'cell': CELL, 'pack_anchor': PACK_ANCHOR, 'runtime_anchor': RUNTIME_ANCHOR, 'scale': WORLD_SCALE,
          'density': 'Scale0.5 conservé ; agrandissement technique des clusters source, aucun nouveau détail inventé.',
          'palette': '32 couleurs communes A–G', 'png_encoding': 'Indexé sans perte,32couleurs+transparence',
          'uniform_factor_per_source': True, 'death_not_regrown': True, 'text_hash_convention': 'UTF-8, fins de ligne LF'})
    write(FOLDER / 'source/SHA256.json', {p.name: digest(p) for p in sorted((FOLDER / 'source').iterdir())
                                       if p.is_file() and p.name != 'SHA256.json'})
    (ROOT / 'docs/art').mkdir(parents=True, exist_ok=True)
    write(ROOT / 'docs/art/ABYSSARQUE_CATALOGUE.json', catalog)
    # Préfixer les nouveaux IDs évite de concurrencer les ajouts en fin de manifeste de la PR129.
    manifest_path = ROOT / 'assets/asset_manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    entries = manifest['entries']
    own_ids = [value[0] for value in PHASES.values()]
    manifest['entries'] = {**{key: entries[key] for key in own_ids},
                           **{key: value for key, value in entries.items() if key not in own_ids}}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent='\t') + '\n',
                             encoding='utf-8', newline='\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview-dir', type=Path, required=True)
    args = parser.parse_args()
    args.preview_dir.mkdir(parents=True, exist_ok=True)
    run(args.preview_dir)
