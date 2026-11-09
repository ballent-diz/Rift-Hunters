#!/usr/bin/env python3
"""Audit ciblé des cinq assets du premier chapitre peint, sans gameplay."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import numpy as np
from PIL import Image
from import_painted_barriers import IDS, ROOT, SOURCE, SPECS


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads((ROOT/'assets/asset_manifest.json').read_text(encoding='utf-8'))
    git = ['git', '-c', 'safe.directory='+str(ROOT).replace('\\', '/'), '-C', str(ROOT)]
    baseline = json.loads(subprocess.check_output(git+['show', 'origin/main:assets/asset_manifest.json']))
    old_entries = {k: v for k, v in manifest['entries'].items() if k not in IDS}
    assert old_entries == {k: v for k, v in baseline['entries'].items() if k not in IDS}, \
        'Une entrée existante du manifeste a changé'
    forbidden = subprocess.check_output(git+['diff', '--name-only', 'origin/main', '--',
                                            'src', 'data', 'assets/environments', 'assets/shaders']).decode().strip()
    assert not forbidden, forbidden
    reports, all_colors = [], set()
    for ident in IDS:
        e = manifest['entries'][ident]
        cell, anchor = SPECS[ident]
        assert e['cell'] == list(cell) and e['anchor'] == list(anchor) and e['scale'] == .5
        path = ROOT/e['sheet'].removeprefix('res://')
        sheet = np.array(Image.open(path).convert('RGBA'))
        visible = sheet[:, :, 3] > 0
        colors = np.unique(sheet[:, :, :3][visible], axis=0)
        assert len(colors) <= 32, (ident, len(colors))
        all_colors.update(map(tuple, colors.tolist()))
        animations = {}
        poses = {}
        for name, anim in e['animations'].items():
            count = anim['frames']
            expected = {'loop': 16, 'appear': 10, 'dissolve': 12, 'idle': 6, 'open': 6}[name]
            assert count == expected and anim['fps'] == 12
            frames = [sheet[anim['row']*cell[1]:(anim['row']+1)*cell[1], i*cell[0]:(i+1)*cell[0]]
                      for i in range(count)]
            hashes = [hashlib.sha256(fr.tobytes()).hexdigest() for fr in frames]
            assert len(set(hashes)) == count, (ident, name, 'poses répétées')
            poses[name] = frames
            animations[name] = {'frames': count, 'fps': 12, 'unique_frames': len(set(hashes)),
                                'loop': anim['loop']}
        if ident == IDS[0]:
            for frames in poses.values():
                assert all(np.array_equal(fr[:, 0], fr[:, -1]) for fr in frames), 'couture horizontale'
            assert np.array_equal(poses['appear'][-1], poses['loop'][0])
            assert np.array_equal(poses['dissolve'][0], poses['loop'][0])
            assert not poses['dissolve'][-1].any()
            loop = [fr.astype(float) for fr in poses['loop']]
            changes = [float(np.abs(loop[(i+1)%16]-loop[i]).mean()) for i in range(16)]
            animations['loop']['mean_step_rgba'] = changes
            animations['loop']['wrap_over_median_step'] = changes[-1]/float(np.median(changes))
            animations['loop']['mean_alpha'] = float(np.mean([fr[:, :, 3].mean() for fr in loop]))/255
        report = {'id': ident, 'cell': list(cell), 'anchor': list(anchor), 'rgb_colors': len(colors),
                  'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'animations': animations}
        if '.seal_' in ident:
            a = poses['idle'][0][:, :, 3]
            yy, xx = np.where(a > 150)
            widths = [int(np.ptp(np.where(a[y] > 180)[0])+1) for y in range(80, 170)
                      if np.any(a[y] > 180)]
            report['height_world'] = (int(yy.max()-yy.min())+1)*.5
            report['median_shaft_width_world'] = float(np.median(widths))*.5
            assert 90 <= report['height_world'] <= 110
            assert 30 <= report['median_shaft_width_world'] <= 40
        reports.append(report)
    assert len(all_colors) <= 32
    report = {'ok': True, 'chapter': 1, 'approval': 'en attente du propriétaire',
              'palette_rgb_count': len(all_colors), 'palette_map': 'cascade_ruins',
              'existing_manifest_entries_unchanged': True, 'forbidden_paths_changed': [],
              'source_hashes': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCE.glob('*.png')},
              'assets': reports}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('BARRIER_AUDIT_OK', len(reports), 'assets, palette', len(all_colors), 'RGB')


if __name__ == '__main__':
    main()
