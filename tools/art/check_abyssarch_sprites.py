#!/usr/bin/env python3
"""Contrôle les feuilles finales : palette commune, gabarits, poses, ancres et mort."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from import_abyssarch import ROOT, FOLDER, PHASES, CELL, PACK_ANCHOR, RUNTIME_ANCHOR
from sprite_source_tools import digest, write


def check(output):
    entries = json.loads((ROOT / 'assets/asset_manifest.json').read_text(encoding='utf-8'))['entries']
    allowed = {tuple(color) for color in np.asarray(Image.open(FOLDER / 'palette.png').convert('RGB')).reshape(-1, 3)}
    failures, report, union = [], {}, set()
    painted = 0
    for letter, (visual_id, names) in PHASES.items():
        entry = entries[visual_id]
        job = json.loads((ROOT / entry['imported_from']).read_text(encoding='utf-8'))
        assert entry['cell'] == CELL and entry['anchor'] == RUNTIME_ANCHOR and entry['scale'] == .5
        path = ROOT / entry['sheet'].removeprefix('res://')
        image = Image.open(path)
        assert max(image.size) <= 16384, (visual_id, image.size)
        assert image.mode == 'P' and image.info.get('transparency') == 255
        palette = np.asarray(image.getpalette(), dtype=np.uint8).reshape(-1, 3)
        active = {tuple(palette[index]) for _, index in image.getcolors(256) if index != 255}
        if not active <= allowed or len(active) > 32:
            failures.append(visual_id + ' : palette commune')
        union.update(active)
        animations = {}
        for animation in job['animations']:
            name = animation['name'];spec = entry['animations'][name]
            boxes, heights, areas, hashes = [], [], [], []
            for i in range(spec['frames']):
                pose = image.crop((i * CELL[0], spec['row'] * CELL[1], (i + 1) * CELL[0],
                                   (spec['row'] + 1) * CELL[1])).convert('RGBA')
                box = pose.getbbox();assert box
                if box[0] < 2 or box[1] < 2 or box[2] > CELL[0] - 2 or box[3] > CELL[1] - 2:
                    failures.append(f'{visual_id}/{name}/{i} : marge {box}')
                alpha = np.asarray(pose)[:, :, 3]
                if not set(np.unique(alpha)) <= {0, 255}:
                    failures.append(f'{visual_id}/{name}/{i} : alpha')
                expected = PACK_ANCHOR[1] + animation['frame_offsets'][i][1]
                if box[3] - 1 != expected:
                    failures.append(f'{visual_id}/{name}/{i} : ancre verticale')
                boxes.append(list(box));heights.append(box[3] - box[1]);areas.append(int(np.count_nonzero(alpha)))
                hashes.append(hashlib.sha256(pose.tobytes()).hexdigest())
            unique = len(set(hashes))
            if unique < min(spec['frames'], 4):
                failures.append(f'{visual_id}/{name} : {unique} poses distinctes')
            animations[name] = {'bounds': boxes, 'heights': heights, 'opaque_pixels': areas,
                                'unique_frames': unique, 'fps': spec['fps'], 'loop': spec['loop']}
        first_height = animations[names[0]]['heights'][0] * .5
        if abs(first_height - 450) > 1:
            failures.append(visual_id + ' : gabarit')
        if letter == 'G':
            collapse = animations['collapse']['heights'];close = animations['eye_close']['heights']
            if collapse[-1] >= collapse[0] * .35 or close[-1] >= collapse[0] * .1:
                failures.append('G : mort insuffisamment affaissée')
            if any(b > a * 1.15 for a, b in zip(collapse, collapse[1:])):
                failures.append('G : mort regonflée')
            hidden = entry['animations']['hidden']
        else:
            hidden = entry['animations']['death']
        assert not image.crop((0, hidden['row'] * CELL[1], CELL[0],
                               (hidden['row'] + 1) * CELL[1])).convert('RGBA').getbbox()
        icon = Image.open(ROOT / entry['icon'].removeprefix('res://')).convert('RGBA')
        box = icon.getbbox()
        assert icon.size == (64, 64) and box and min(box[:2]) >= 3 and max(box[2:]) <= 61
        painted += 12 if letter == 'G' else 18
        report[visual_id] = {'phase': letter, 'colors': len(active), 'sheet_size': list(image.size),
                            'reference_world_height': first_height, 'ratio_to_nivorath': first_height / 150,
                            'animations': animations, 'sheet_sha256': digest(path)}
        print('AUDITED', letter, 'world', first_height, 'colors', len(active), flush=True)
    hashes = json.loads((FOLDER / 'source/SHA256.json').read_text(encoding='utf-8'))
    for name, value in hashes.items():
        if digest(FOLDER / 'source' / name) != value:
            failures.append('Empreinte source : ' + name)
    assert painted == 120
    result = {'ok': not failures, 'source_sheets': 7, 'painted_source_poses': painted,
              'runtime_reused_pose': 'F/idle reprend la dernière pose de final_entry', 'phases': report,
              'shared_colors': len(union), 'failures': failures, 'text_hash_convention': 'UTF-8, fins de ligne LF'}
    write(output, result)
    print('ABYSSARCH_AUDIT', painted, 'poses', len(failures), 'erreurs', flush=True)
    for failure in failures:
        print(failure)
    return not failures


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    raise SystemExit(0 if check(args.out) else 1)
