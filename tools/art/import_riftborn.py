#!/usr/bin/env python3
"""Import reproductible des Enfants de la Faille et de la Statue, sans redessiner les poses."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
import import_sheet
from sprite_source_tools import digest, pack, split_source, write

ROOT = Path(__file__).resolve().parents[2]
IDS = ['rift_larva', 'drifting_eye', 'void_crawler', 'torn_shade',
       'portal_strider', 'echo_mirror', 'statue_keeper', 'awakened_statue']
ELITES = IDS[4:7]
TECHNIQUES = {'torn_shade': ['rift_step'], 'portal_strider': ['opening', 'portal_jump'],
              'echo_mirror': ['copy', 'reflection'], 'statue_keeper': ['awaken_statues', 'stone_wave']}
TARGETS = dict(zip(IDS, [112, 112, 88, 112, 150, 150, 150, 220]))


def strip(poses, path):
    side = max(max(p.size) for p in poses) + 32
    image = Image.new('RGBA', (side * len(poses), side))
    for i, pose in enumerate(poses):
        image.paste(pose, (i * side + (side - pose.width) // 2, side - 16 - pose.height))
    image.save(path, lossless=True, exact=True, method=4)


def import_one(identifier, preview_dir):
    folder = ROOT / 'assets/concepts/incoming' / ('enemy.' + identifier)
    statue = identifier == 'awakened_statue'
    rows = 3 if statue or identifier in ELITES or identifier == 'torn_shade' else 2
    a, info_a = split_source(folder / 'source/planche_A.png', rows)
    b, info_b = [], None
    if identifier in ELITES:
        b, info_b = split_source(folder / 'source/planche_B.png', 2)
    reference = a[:1] if statue else a[:6]
    reference_height = sorted(p.height for p in reference)[len(reference) // 2]
    scale_b = reference_height / float(np.median([b[i].height for i in (0, 5, 6, 11)])) if b else 1.0
    side = 320 if statue else (256 if identifier in ELITES else 192)
    hover = 12 if identifier == 'drifting_eye' else 0
    anchor = [side // 2, side - 28]
    target = TARGETS[identifier]
    while any(round(p.width * target / reference_height * factor) > side - 4 or
              round(p.height * target / reference_height * factor) > anchor[1] - hover - 2
              for p, factor in [(p, 1.0) for p in a] + [(p, scale_b) for p in b]):
        target -= 1
    assert target >= TARGETS[identifier] * .9, (identifier, target)
    animations = []
    if statue:
        # La source demandée reste 6×3 : 1 endormie + 5 éveil, puis 6 déplacement et 6 coups lourds.
        for name, poses, fps, loop in [('dormant', a[:1], 1, True), ('awaken', a[1:6], 9, False),
                                       ('move', a[6:12], 8, True), ('attack', a[12:18], 9, False)]:
            strip(poses, folder / (name + '.webp'))
            animations.append({'name': name, 'source': name + '.webp', 'grid': [len(poses), 1],
                               'frames': len(poses), 'fps': fps, 'loop': loop})
    else:
        pack(a, rows, folder / 'planche_A.webp')
        for row, name in enumerate(['move', 'attack'] +
                                   (['death'] if identifier in ELITES else TECHNIQUES.get(identifier, []))):
            animations.append({'name': name, 'source': 'planche_A.webp', 'grid': [6, rows], 'row': row,
                               'frames': 6, 'fps': 10 if name == 'move' else 12, 'loop': name == 'move'})
        if b:
            pack(b, 2, folder / 'planche_B.webp')
            for row, name in enumerate(TECHNIQUES[identifier]):
                animations.append({'name': name, 'source': 'planche_B.webp', 'grid': [6, 2], 'row': row,
                                   'source_scale': round(scale_b, 8), 'frames': 6, 'fps': 10, 'loop': False})
    for animation in animations:
        animation['frame_offsets'] = [[0, y] for y in (0, -1, -2, -1, 0, 1)] if hover and animation['name'] == 'move' \
            else [[0, 0] for _ in range(animation['frames'])]
    job = {'visual_id': 'enemy.' + identifier, 'cell': [side, side], 'anchor': anchor, 'scale': .5,
           'target_height': target, 'status': 'final', 'background': 'alpha', 'colors': 32, 'outline': False,
           'flip': False, 'hover': hover, 'preview_zoom': 1,
           'anchor_mode': 'mass' if identifier in ['rift_larva', 'void_crawler', 'drifting_eye'] else 'feet',
           'animations': animations, 'aliases': {'idle': 'dormant' if statue else 'move'},
           'family': 'Statue éveillée' if statue else 'Les Enfants de la Faille', 'chapter': 5,
           'integration': 'Claude : comportements, données et phases ; aucun src/ ni data/ modifié.'}
    if identifier not in ELITES:
        job['empty_animations'] = [{'name': 'death', 'fps': 12, 'loop': False}]
    write(folder / 'job.json', job)
    entry = import_sheet.run(str(folder / 'job.json'), preview_dir=str(preview_dir))
    image = Image.open(ROOT / entry['sheet'].removeprefix('res://')).convert('RGBA')
    changed = False
    for animation in animations:
        row = entry['animations'][animation['name']]['row']
        for i in range(animation['frames']):
            box = image.crop((i * side, row * side, (i + 1) * side, (row + 1) * side)).getbbox()
            assert box
            dx = max(0, 2 - box[0]) - max(0, box[2] - side + 2)
            if dx:
                animation['frame_offsets'][i][0] += dx
                changed = True
    write(folder / 'job.json', job)
    if changed:
        entry = import_sheet.run(str(folder / 'job.json'), preview_dir=str(preview_dir))
    write(folder / 'source/normalization.json', {'sheets': [v for v in [info_a, info_b] if v],
          'packing': 'Composantes alpha, marge de 32 pixels, sans redessin.', 'reference_height_source': reference_height,
          'source_scale_B': scale_b, 'target_height': target, 'world_height_base': target * .5, 'native_cell': [side, side],
          'same_scale_through_each_animation': True, 'death_and_disappearance_not_regrown': True,
          'text_hash_convention': 'UTF-8, fins de ligne LF'})
    write(folder / 'source/SHA256.json', {p.name: digest(p) for p in sorted((folder / 'source').iterdir())
                                        if p.is_file() and p.name != 'SHA256.json'})
    print('IMPORTED', identifier, 'cell', side, 'target', target, flush=True)
    return {'visual_id': job['visual_id'], 'source_sheets': 2 if b else 1, 'painted_poses': len(a) + len(b),
            'job': (folder / 'job.json').relative_to(ROOT).as_posix()}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview-dir', type=Path, required=True)
    args = parser.parse_args()
    args.preview_dir.mkdir(parents=True, exist_ok=True)
    catalog = [import_one(identifier, args.preview_dir) for identifier in IDS]
    (ROOT / 'docs/art').mkdir(parents=True, exist_ok=True)
    write(ROOT / 'docs/art/ENFANTS_FAILLE_CATALOGUE.json', catalog)
