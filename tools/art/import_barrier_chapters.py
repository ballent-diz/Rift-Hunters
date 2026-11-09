#!/usr/bin/env python3
"""Décline les planches peintes validées vers les chapitres 2 à 5.

Deux dessins imagegen par chapitre (38 poses de voile, 24 poses de bornes).
Découpage, palette prélevée sur le décor, ancrage, projections puis import standard.
"""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
import import_sheet
from import_painted_barriers import ROOT, INCOMING, SPECS, digest, periodic, project, write

CONFIG = {
    2: {'map': 'scorched_verge', 'center': [2450, 1400], 'decor_scale': 1.0,
        'material': 'basalte, cendres et braises'},
    3: {'map': 'root_mangrove', 'center': [2750, 1550], 'decor_scale': 1.0,
        'material': 'bois noyé, racines et eau sombre'},
    4: {'map': 'glacier_entry', 'center': [2400, 1500], 'decor_scale': .9,
        'material': 'glace bleutée, givre et pierre gelée'},
    5: {'map': 'shattered_outskirts', 'center': [4050, 800], 'decor_scale': 1.0,
        'material': 'acier pâle, ardoise, dorures ternies et veines magenta'},
}


def ids(chapter):
    return [f'object.barrier_{chapter}'+suffix for suffix in ['', '.bias', '.corner', '.seal_a', '.seal_b']]


def color_distance(rgb, colors):
    flat = rgb.reshape(-1, 3).astype(np.int32)
    result = np.empty_like(flat, dtype=np.uint8)
    for i in range(0, len(flat), 8192):
        block = flat[i:i+8192]
        distances = ((block[:, None, :]-colors[None, :, :].astype(int))**2).sum(2)
        result[i:i+8192] = colors[distances.argmin(1)]
    return result.reshape(rgb.shape)


def palette(chapter, assets):
    folder = assets/'assets/environments'/CONFIG[chapter]['map']
    pixels, sources = [], []
    for name in ['map.webp', 'map_1.webp', 'map_2.webp']:
        path = folder/name
        image = Image.open(path).convert('RGB')
        pixels.append(np.asarray(image)[::8, ::8].reshape(-1, 3))
        sources.append({'file': str(path.relative_to(assets)).replace('\\', '/'),
                        'sha256': digest(path), 'size': list(image.size), 'sample_stride': 8})
    rgb = np.concatenate(pixels).astype(int)
    r, g, b = rgb.T; mean = rgb.mean(1); chroma = rgb.max(1)-rgb.min(1)
    if chapter == 2:
        groups = [('basalte', (chroma < 65) & (mean < 160), 12),
                  ('braises', (r > 160) & (r > g*1.35) & (g > b*1.2), 16),
                  ('reflets chauds', (r > 230) & (g > 160) & (b < 140), 4)]
    elif chapter == 3:
        groups = [('bois noyé', (r > g*1.08) & (g > b*1.2) & (mean < 130), 10),
                  ('mousse', (g > r*1.08) & (g > b*1.1), 5),
                  ('eau sombre et reflets', (g > r*1.15) & (b > r*1.25), 17)]
    elif chapter == 4:
        groups = [('pierre gelée et ombres', mean < 110, 8),
                  ('glace et givre', (b > r+8) & (b >= g) & (g > r+5), 24)]
    else:
        groups = [('acier et ardoise', (chroma < 65) & (mean > 35), 12),
                  ('dorures ternies', (r > g*1.04) & (g > b*1.15) & (mean < 180) & (r > 75), 4),
                  ('corruption', (r > g*1.2) & (b > g*1.2), 16)]
    colors, samples = [], []
    for name, mask, count in groups:
        selected = rgb[mask].astype(np.uint8)
        assert len(selected) > 100, (chapter, name)
        image = Image.fromarray(selected.reshape(1, -1, 3))
        q = image.quantize(colors=count, method=Image.Quantize.MEDIANCUT)
        representatives = np.asarray([q.getpalette()[i*3:i*3+3] for _, i in q.getcolors()], dtype=np.uint8)
        # Choisir un pixel réellement prélevé, pas le centre RGB moyen du groupe.
        actual = []
        for color in representatives:
            distances = ((selected.astype(int)-color.astype(int))**2).sum(1)
            actual.append(selected[distances.argmin()].tolist())
        colors.extend(actual); samples.append({'material': name, 'colors': actual, 'sample_count': len(selected)})
    colors = np.unique(np.asarray(colors, dtype=np.uint8), axis=0)
    assert len(colors) <= 32
    source = INCOMING/f'object.barrier_{chapter}/source'
    write(source/'palette.json', {'chapter': chapter, 'map': CONFIG[chapter]['map'],
                                'colors': colors.tolist(), 'sources': sources, 'samples': samples,
                                'exact_map_pixels': True})
    Image.fromarray(colors.reshape(1, -1, 3)).save(source/'palette.png')
    return colors


def grid(path, cols, rows):
    image = Image.open(path).convert('RGBA')
    return [image.crop((round(c*image.width/cols), round(r*image.height/rows),
                        round((c+1)*image.width/cols), round((r+1)*image.height/rows)))
            for r in range(rows) for c in range(cols)]


def clean_veil(frame, chapter):
    a = np.array(frame); rgb = a[:, :, :3].astype(int)
    if chapter == 3:
        # La source contient un matte quadrillé très pâle : il n'est pas un dessin de matière.
        use = (rgb.min(2) < 195) & ((rgb.max(2)-rgb.min(2)) > 14)
    elif chapter == 4:
        use = (rgb[:, :, 2] > rgb[:, :, 0]+6) | (rgb.max(2)-rgb.min(2) < 30)
    elif chapter == 5:
        use = (rgb[:, :, 2] > rgb[:, :, 1]+5) | ((rgb[:, :, 0] > rgb[:, :, 2]+4) & (rgb[:, :, 0] > 120))
    else:
        use = (rgb.mean(2) < 185) | (rgb[:, :, 0] > rgb[:, :, 2]+15)
    a[~use, 3] = 0
    a[a[:, :, 3] < 32] = 0
    a[a[:, :, 3] == 0, :3] = 0
    return Image.fromarray(a)


def core_bounds(image):
    alpha = np.asarray(image)[:, :, 3] > 120
    labels, _ = ndi.label(alpha, np.ones((3, 3)))
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    y, x = np.where(labels == sizes.argmax())
    return [int(x.min()), int(y.min()), int(x.max()+1), int(y.max()+1)]


def quantize(image, colors, veil=False, chapter=None):
    a = np.array(image)
    a[:, :, :3] = color_distance(a[:, :, :3], colors)
    raw = np.asarray(image)[:, :, :3].astype(int)
    if chapter in [2, 5]:
        r, g, b = raw[:, :, 0], raw[:, :, 1], raw[:, :, 2]
        pr, pg, pb = colors[:, 0].astype(int), colors[:, 1].astype(int), colors[:, 2].astype(int)
        if chapter == 2:
            accent = (r > g+35) & (g > b+20) & (r > 145)
            ramp = colors[(pr > pg*1.25) & (pr > pb*1.8)]
        else:
            accent = (r > g+25) & (b > g+20)
            ramp = colors[(pr > pg*1.15) & (pb > pg*1.15)]
        assert len(ramp) > 2
        a[accent, :3] = color_distance(raw[accent].astype(np.uint8), ramp)
    multiplier = .55 if veil else 1.0
    a[:, :, 3] = np.round(a[:, :, 3].astype(float)*multiplier/8).clip(0, 31).astype(np.uint8)*8
    a[a[:, :, 3] < 8] = 0
    return Image.fromarray(a)


def veil(chapter, colors):
    source = INCOMING/f'object.barrier_{chapter}/source'
    cells = grid(source/'voile.png', 8, 5)
    groups = {'loop': cells[:16], 'appear': cells[16:26], 'dissolve': cells[26:38]}
    result, calibration = {}, {}
    for name, raw in groups.items():
        frames = [clean_veil(fr, chapter) for fr in raw]
        reference = frames[-1] if name == 'appear' else frames[0]
        box = core_bounds(reference)
        scale = 200/(box[3]-box[1])
        row = []
        for frame in frames:
            frame = frame.crop((5, 0, frame.width-5, frame.height))
            image = frame.resize((256, round(frame.height*scale)), Image.Resampling.NEAREST)
            canvas = Image.new('RGBA', (256, 256))
            canvas.paste(image, (0, 224-round(box[3]*scale)))
            row.append(quantize(periodic(canvas), colors, veil=True, chapter=chapter))
        result[name] = row
        calibration[name] = {'source_body_bounds': box, 'vertical_scale': scale,
                             'registered_anchor': [0, 224], 'common_transform_for_animation': True}
    result['appear'][-1] = result['loop'][0].copy()
    result['dissolve'][0] = result['loop'][0].copy()
    result['dissolve'][-1] = Image.new('RGBA', (256, 256))
    return result, calibration


def pillars(chapter, colors):
    source = INCOMING/f'object.barrier_{chapter}/source'
    cells = grid(source/'bornes.png', 6, 4)
    result, record = {}, []
    for variant in range(2):
        frames = []
        for raw in cells[variant*12:(variant+1)*12]:
            a = np.array(raw); rgb = a[:, :, :3].astype(int)
            # Résidu de fond blanc de la source C5, distinct du métal teinté.
            white = (rgb.min(2) > 225) & (rgb.max(2)-rgb.min(2) < 16)
            a[white | (a[:, :, 3] < 40)] = 0
            image = Image.fromarray(a)
            box = core_bounds(image)
            scale = 200/(box[3]-box[1])
            image = image.resize((round(image.width*scale), round(image.height*scale)), Image.Resampling.NEAREST)
            canvas = Image.new('RGBA', (160, 256))
            canvas.paste(image, (80-round((box[0]+box[2])*.5*scale), 232-round(box[3]*scale)))
            frames.append(quantize(canvas, colors, chapter=chapter))
        a = np.asarray(frames[0])[:, :, 3]
        widths = [np.ptp(np.where(a[y] > 180)[0])+1 for y in range(80, 170) if np.any(a[y] > 180)]
        horizontal = 70/float(np.median(widths))
        normalized = []
        for frame in frames:
            image = frame.resize((round(160*horizontal), 256), Image.Resampling.NEAREST)
            canvas = Image.new('RGBA', (160, 256))
            canvas.paste(image, (80-round(80*horizontal), 0))
            normalized.append(np.array(canvas))
        # Masque des glyphes lumineux prélevé dans les dessins ; corps et ombre fixes.
        mask = np.zeros((256, 160), dtype=bool)
        for a in normalized:
            r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
            glow = ((r > g+20) & (r > b+30)) if chapter == 2 else (
                ((b > r+20) & (g > r+15)) if chapter in [3, 4] else ((r > g+20) & (b > g+20)))
            mask |= glow & (a[:, :, 3] > 80)
        region = np.zeros_like(mask); region[55:185, 46:114] = True
        mask = ndi.binary_dilation(mask, iterations=1) & region
        assert mask.sum() > 10, (chapter, variant, 'glyphes absents')
        stable = []
        for a in normalized:
            fixed = normalized[-1].copy(); fixed[mask] = a[mask]
            stable.append(Image.fromarray(fixed))
        ident = f'object.barrier_{chapter}.seal_'+('a' if variant == 0 else 'b')
        result[ident] = {'idle': stable[:6], 'open': stable[6:]}
        record.append({'id': ident, 'horizontal_scale': horizontal, 'target_shaft_width_px': 70,
                       'animated_glyph_pixels': int(mask.sum()), 'fixed_body_outside_glyphs': True})
    return result, record


def publish(ident, frames, chapter, work):
    template = ident.replace(f'barrier_{chapter}', 'barrier_1')
    cell, anchor = SPECS[template]
    folder = INCOMING/ident; folder.mkdir(parents=True, exist_ok=True)
    cols = max(map(len, frames.values()))
    image = Image.new('RGBA', (cell[0]*cols, cell[1]*len(frames)))
    animations = []
    for row, (name, poses) in enumerate(frames.items()):
        for col, pose in enumerate(poses):
            image.paste(pose, (col*cell[0], row*cell[1]))
        animations.append({'name': name, 'source': 'poses.webp', 'grid': [cols, len(frames)],
                           'row': row, 'frames': len(poses), 'fps': 12, 'loop': name in ['loop', 'idle']})
    image.save(folder/'poses.webp', lossless=True, exact=True)
    job = {'visual_id': ident, 'cell': list(cell), 'anchor': list(anchor), 'scale': .5,
           'target_height': 200, 'keep_size': True, 'registered_cells': True, 'status': 'final',
           'background': 'alpha', 'preserve_alpha': True, 'colors': 0, 'outline': False,
           'preview_zoom': 1, 'animations': animations, 'aliases': {},
           'palette_note': '32 couleurs RGB maximum prélevées sur '+CONFIG[chapter]['map'],
           'approval': 'déclinaison autorisée après validation du chapitre 1',
           'source_recipe': 'tools/art/import_barrier_chapters.py',
           'source_master': f'../object.barrier_{chapter}/source/'}
    write(folder/'job.json', job)
    import_sheet.REPO = str(ROOT)
    return import_sheet.run(str(folder/'job.json'), preview_dir=str(work/'imports'))


def approve_first():
    manifest_path = ROOT/'assets/asset_manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    for ident in ids(1):
        path = INCOMING/ident/'job.json'
        job = json.loads(path.read_text(encoding='utf-8'))
        job.update(status='final', approval='chapitre 1 validé explicitement par le propriétaire')
        write(path, job)
        manifest['entries'][ident]['status'] = 'final'
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent='\t')+'\n', encoding='utf-8')
    path = INCOMING/'object.barrier_1/source/generation.json'
    data = json.loads(path.read_text(encoding='utf-8')); data['approval'] = 'validé par le propriétaire'
    for e in data['entries'].values():
        e['status'] = 'final'
    write(path, data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets-root', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--chapters', type=int, nargs='+', default=[2, 3, 4, 5])
    args = parser.parse_args(); args.work.mkdir(parents=True, exist_ok=True)
    approve_first()
    for chapter in args.chapters:
        assert chapter in CONFIG
        colors = palette(chapter, args.assets_root)
        face, calibration = veil(chapter, colors)
        variants = {f'object.barrier_{chapter}': face,
                    f'object.barrier_{chapter}.bias': {k: [project(p) for p in v] for k, v in face.items()},
                    f'object.barrier_{chapter}.corner': {k: [project(p, True) for p in v] for k, v in face.items()}}
        posts, post_calibration = pillars(chapter, colors); variants.update(posts)
        entries = {ident: publish(ident, frames, chapter, args.work) for ident, frames in variants.items()}
        source = INCOMING/f'object.barrier_{chapter}/source'
        write(source/'generation.json', {'mode': 'imagegen intégré', 'chapter': chapter,
              'authorization': 'chapitre 1 validé ; déclinaison demandée dans le lot initial',
              'material': CONFIG[chapter]['material'], 'map': CONFIG[chapter]['map'],
              'source_grids': {'voile.png': [8, 5], 'bornes.png': [6, 4]},
              'source_sha256': {p.name: digest(p) for p in source.glob('*.png')},
              'prompts': [p.name for p in source.glob('PROMPT_*.txt')],
              'approved_motion_reference': 'object.barrier_1/poses.webp',
              'approved_motion_sha256': digest(INCOMING/'object.barrier_1/poses.webp'),
              'veil_registration': calibration, 'pillar_registration': post_calibration,
              'processing': ['retrait du résidu neutre de matte', 'découpage et ancrage par planche',
                             'palette prélevée sur le décor', 'raccord local prémultiplié',
                             'projection face, biais et pli', 'corps et ombre des bornes fixes'],
              'entries': entries, 'no_gameplay_changes': True})
        print('CHAPITRE_IMPORTE', chapter, '5 assets', flush=True)


if __name__ == '__main__':
    main()
