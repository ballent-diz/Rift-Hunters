#!/usr/bin/env python3
"""Contrôle les vraies sorties d'un lot : poses, bords, alpha, ancre et recettes communes."""
import argparse
import hashlib
import json
from pathlib import Path
from statistics import median

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def audit(catalog_path, output):
    manifest = json.loads((ROOT / 'assets/asset_manifest.json').read_text())['entries']
    catalog = json.loads(catalog_path.read_text())
    report, failures = {}, []
    for item in catalog:
        key = item['visual_id']
        entry = manifest[key]
        job_path = ROOT / entry['imported_from']
        job = json.loads(job_path.read_text())
        cw, ch = entry['cell']
        image = Image.open(ROOT / entry['sheet'].removeprefix('res://')).convert('RGBA')
        if image.getchannel('A').getextrema()[0] != 0:
            failures.append(key + ': alpha absent')
        opaque_colors = len([rgba for count, rgba in image.getcolors(cw*ch*image.width) if rgba[3]])
        if opaque_colors > job['colors']:
            failures.append(f'{key}: {opaque_colors} couleurs pour un budget de {job["colors"]}')
        poses, metrics = 0, {}
        for animation in job['animations']:
            name = animation['name']
            data = entry['animations'][name]
            heights, bottoms = [], []
            for index in range(data['frames']):
                frame = image.crop((index*cw, data['row']*ch, (index+1)*cw, (data['row']+1)*ch))
                bounds = frame.getbbox()
                if not bounds or min(bounds[:2]) <= 0 or bounds[2] >= cw or bounds[3] >= ch:
                    failures.append(f'{key}/{name}/{index}: pose vide ou bord touché {bounds}')
                    continue
                heights.append(bounds[3]-bounds[1])
                bottoms.append(bounds[3]-1)
                poses += 1
            metrics[name] = {'heights': heights, 'bottoms': bottoms, 'fps': data['fps'], 'loop': data['loop']}
        reference = metrics[job['animations'][0]['name']]
        if abs(median(reference['heights']) - job['target_height']) > 4:
            failures.append(key + ': hauteur de référence incohérente')
        expected_bottom = entry['anchor'][1] - job.get('hover', 0) + 1
        if set(reference['bottoms']) != {expected_bottom}:
            failures.append(f'{key}: ancre instable {reference["bottoms"]}, attendu {expected_bottom}')
        hashes = json.loads((job_path.parent / 'source/SHA256.json').read_text())
        for filename, expected in hashes.items():
            if hashlib.sha256((job_path.parent / 'source' / filename).read_bytes()).hexdigest() != expected:
                failures.append(key + ': empreinte source différente ' + filename)
        report[key] = {'poses': poses, 'colors': opaque_colors,
                       'reference_world_height': median(reference['heights'])*entry['scale'],
                       'cell': entry['cell'], 'anchor': entry['anchor'], 'scale': entry['scale'],
                       'animations': metrics, 'normalization': json.loads((job_path.parent / 'source/normalization.json').read_text())}
    result = {'entities': len(report), 'painted_poses': sum(x['poses'] for x in report.values()),
              'failures': failures, 'sprites': report}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(len(report), 'visuels,', result['painted_poses'], 'poses,', len(failures), 'erreurs')
    for error in failures:
        print(error)
    if failures:
        raise SystemExit(1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('catalog', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    audit(args.catalog, args.output)
