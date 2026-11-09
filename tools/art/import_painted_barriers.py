#!/usr/bin/env python3
"""Prépare le premier chapitre peint : découpage, palette, raccords et import.

Les quatre sources sont dessinées par imagegen. Les projections du même dessin
ne changent ni la collision ni le parcours ; aucun shader ni texture procédurale.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
import import_sheet

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / 'assets/concepts/incoming'
SOURCE = INCOMING / 'object.barrier_1/source'
IDS = ['object.barrier_1', 'object.barrier_1.bias', 'object.barrier_1.corner',
       'object.barrier_1.seal_a', 'object.barrier_1.seal_b']
SPECS = {'object.barrier_1': ((256, 256), (0, 224)),
         'object.barrier_1.bias': ((112, 512), (16, 224)),
         'object.barrier_1.corner': ((384, 384), (16, 224)),
         'object.barrier_1.seal_a': ((160, 256), (80, 232)),
         'object.barrier_1.seal_b': ((160, 256), (80, 232))}
VEIL_LEVELS = None
VEIL_TONE = (1.0, 0.0)


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def grid(name, cols, rows):
    image = Image.open(SOURCE / name).convert('RGBA')
    return [image.crop((round(c*image.width/cols), round(r*image.height/rows),
                        round((c+1)*image.width/cols), round((r+1)*image.height/rows)))
            for r in range(rows) for c in range(cols)]


def veil_cut(frame):
    a = np.array(frame)
    rgb = a[:, :, :3].astype(int)
    # Supprimer le résidu neutre de matte, sans remplir les trous alpha.
    purple = (rgb[:, :, 2] > rgb[:, :, 0]+3) & (rgb[:, :, 2] > rgb[:, :, 1]+6)
    a[~purple, 3] = 0
    a[a[:, :, 3] < 28, 3] = 0
    a[a[:, :, 3] == 0, :3] = 0
    return Image.fromarray(a)


def bounds(frame, threshold=100):
    a = np.asarray(frame)[:, :, 3] > threshold
    y, x = np.where(a)
    return (int(x.min()), int(y.min()), int(x.max()+1), int(y.max()+1))


def palette(assets):
    samples = [
        ('map.webp', [160, 420, 540, 940], 'pierre grise et ardoise', 10),
        ('map.webp', [300, 1300, 780, 1800], 'mousse et ombres végétales', 7),
        ('map_2.webp', [2200, 100, 3650, 800], 'Faille violette du décor', 15)]
    colors, record = [], []
    for name, box, material, count in samples:
        path = assets / 'assets/environments/cascade_ruins' / name
        im = Image.open(path).convert('RGB').crop(box)
        rgb = np.asarray(im).reshape(-1, 3).astype(int)
        if material.startswith('pierre'):
            use = (rgb.max(1)-rgb.min(1) < 43) & (rgb.mean(1) > 38)
        elif material.startswith('mousse'):
            use = (rgb[:, 1] > rgb[:, 0]) & (rgb[:, 1] > rgb[:, 2]*1.2)
        else:
            use = (rgb[:, 2] > rgb[:, 1]*1.2) & (rgb[:, 0] > rgb[:, 1]*1.1)
        picked = rgb[use].astype(np.uint8)
        assert len(picked) > 100, material
        swatch = Image.fromarray(picked.reshape(1, -1, 3))
        q = swatch.quantize(colors=count, method=Image.Quantize.MEDIANCUT)
        local = [list(q.getpalette()[i*3:i*3+3]) for _, i in q.getcolors()]
        colors += local
        record.append({'file': str(path.relative_to(assets)).replace('\\', '/'),
                       'sha256': digest(path), 'pixel_rect': box, 'material': material, 'colors': local})
    colors = np.unique(np.asarray(colors, dtype=np.uint8), axis=0)
    assert len(colors) <= 32
    write(SOURCE / 'palette.json', {'map': 'cascade_ruins', 'colors': colors.tolist(), 'samples': record})
    Image.fromarray(colors.reshape(1, -1, 3)).save(SOURCE / 'palette.png')
    return colors


def quantize(frame, colors, veil=False):
    a = np.array(frame)
    rgb = a[:, :, :3].astype(np.int32).reshape(-1, 3)
    mapped = np.empty_like(rgb, dtype=np.uint8)
    for i in range(0, len(rgb), 8192):
        d = ((rgb[i:i+8192, None, :] - colors[None, :, :].astype(int))**2).sum(2)
        mapped[i:i+8192] = colors[d.argmin(1)]
    a[:, :, :3] = mapped.reshape(a.shape[:2]+(3,))
    # Les filaments et les glyphes gardent la rampe violette du décor ; une
    # distance RGB globale les ferait à tort tomber dans la pierre grise.
    purple = colors[(colors[:, 2].astype(int) > colors[:, 1].astype(int)+15)
                    & (colors[:, 0].astype(int) > colors[:, 1].astype(int)+10)]
    selected = np.ones(a.shape[:2], dtype=bool) if veil else (
        (np.asarray(frame)[:, :, 2].astype(int) > np.asarray(frame)[:, :, 1].astype(int)+15)
        & (np.asarray(frame)[:, :, 2].astype(int) > np.asarray(frame)[:, :, 0].astype(int)+6))
    original = np.asarray(frame)[:, :, :3].astype(int)[selected]
    distance = ((original[:, None, :] - purple[None, :, :].astype(int))**2).sum(2)
    a[selected, :3] = purple[distance.argmin(1)]
    if veil:
        # Quantification tonale commune aux 38 poses : conserver les plis
        # peints plutôt que rabattre leurs gris-violets sur un seul aplat.
        luminance = np.asarray(frame)[:, :, :3].astype(float) @ np.array([.2126, .7152, .0722])
        luminance = luminance*VEIL_TONE[0]+VEIL_TONE[1]
        order = np.argsort(purple.astype(float) @ np.array([.2126, .7152, .0722]))
        ramp = purple[order[[1, 2, 4, 5, 6, 9, -1]]]
        a[:, :, :3] = ramp[np.digitize(luminance, VEIL_LEVELS)]
        # L'opacité conserve les trous générés et laisse lire le dallage sous les nappes.
        a[:, :, 3] = np.round(a[:, :, 3].astype(float)*.55/8).clip(0, 20).astype(np.uint8)*8
    else:
        a[:, :, 3] = np.round(a[:, :, 3].astype(float)/8).clip(0, 31).astype(np.uint8)*8
    a[a[:, :, 3] < 8] = 0
    return Image.fromarray(a)


def periodic(frame, width=22):
    """Raccord prémultiplié sur les seuls bords, aucun motif synthétique ajouté."""
    a = np.asarray(frame).astype(float)
    alpha = a[:, :, 3:4]/255
    p = np.concatenate([a[:, :, :3]*alpha, a[:, :, 3:4]], axis=2)
    for i in range(width):
        weight = (1-i/(width-1))*.5
        left, right = p[:, i].copy(), p[:, -1-i].copy()
        p[:, i] = left*(1-weight)+right*weight
        p[:, -1-i] = right*(1-weight)+left*weight
    denom = p[:, :, 3:4]/255
    out = np.zeros_like(p)
    out[:, :, :3] = np.divide(p[:, :, :3], denom, out=np.zeros_like(p[:, :, :3]), where=denom>0)
    out[:, :, 3] = p[:, :, 3]
    return Image.fromarray(np.round(out).clip(0, 255).astype(np.uint8))


def veil_frames(colors):
    global VEIL_LEVELS, VEIL_TONE
    sets = {'loop': grid('loop.png', 8, 2), 'appear': grid('appear.png', 5, 2),
            'dissolve': grid('dissolve.png', 6, 2)}
    pixels = np.concatenate([np.asarray(veil_cut(fr)).reshape(-1, 4) for fr in sets['loop']])
    pixels = pixels[pixels[:, 3] > 100, :3].astype(float)
    VEIL_LEVELS = np.quantile(pixels @ np.array([.2126, .7152, .0722]), [.15, .35, .55, .73, .87, .95])
    def tonal_reference(im):
        a = np.asarray(im)
        values = a[:, :, :3][a[:, :, 3] > 100].astype(float) @ np.array([.2126, .7152, .0722])
        return np.quantile(values, [.15, .85])
    target_tone = tonal_reference(veil_cut(sets['loop'][0]))
    result = {}
    for name, raw in sets.items():
        cut = [veil_cut(fr) for fr in raw]
        ref = cut[-1] if name == 'appear' else cut[0]
        original_tone = tonal_reference(ref)
        tone_scale = float(np.diff(target_tone)[0]/np.diff(original_tone)[0])
        VEIL_TONE = (tone_scale, float(target_tone[0]-tone_scale*original_tone[0]))
        box = bounds(ref)
        # Une transformation commune par planche : les petits fragments ne sont jamais regonflés.
        top, bottom = box[1], box[3]
        factor = 200/(bottom-top)
        frames = []
        for im in cut:
            # La planche générée contient un trait de cellule sur quelques
            # colonnes extrêmes : il ne fait pas partie du voile peint.
            im = im.crop((8, 0, im.width-8, im.height))
            transformed = im.resize((256, round(im.height*factor)), Image.Resampling.NEAREST)
            canvas = Image.new('RGBA', (256, 256))
            canvas.paste(transformed, (0, 224-round(bottom*factor)))
            frames.append(quantize(periodic(canvas), colors, veil=True))
        result[name] = frames
    # Points de raccord d'état exacts ; la pose terminale de disparition reste vide.
    result['appear'][-1] = result['loop'][0].copy()
    result['dissolve'][0] = result['loop'][0].copy()
    result['dissolve'][-1] = Image.new('RGBA', (256, 256))
    return result


def project(frame, corner=False):
    """Projection des pixels peints en plans verticaux, par triangles enregistrés."""
    source = np.asarray(frame)
    size = (384, 384) if corner else (112, 512)
    out = np.zeros((size[1], size[0], 4), dtype=np.uint8)

    def triangle(src, dst):
        dst = np.asarray(dst, dtype=float); src = np.asarray(src, dtype=float)
        lo = np.floor(dst.min(0)).astype(int); hi = np.ceil(dst.max(0)).astype(int)
        lo = np.maximum(lo, 0); hi = np.minimum(hi, size)
        if np.any(hi <= lo):
            return
        yy, xx = np.mgrid[lo[1]:hi[1], lo[0]:hi[0]]
        p = np.stack([xx+.5-dst[0, 0], yy+.5-dst[0, 1]], -1)
        matrix = np.stack([dst[1]-dst[0], dst[2]-dst[0]], 1)
        if abs(np.linalg.det(matrix)) < .001:
            return
        uv = p @ np.linalg.inv(matrix).T
        valid = (uv[:, :, 0] >= 0) & (uv[:, :, 1] >= 0) & (uv.sum(2) <= 1)
        xy = src[0]+uv[:, :, :1]*(src[1]-src[0])+uv[:, :, 1:]*(src[2]-src[0])
        sx = np.clip(xy[:, :, 0].astype(int), 0, 255)
        sy = np.clip(xy[:, :, 1].astype(int), 0, 255)
        out[yy[valid], xx[valid]] = source[sy[valid], sx[valid]]

    def quad(src, dst):
        for a, b, c in [(0, 1, 2), (0, 2, 3)]:
            triangle([src[a], src[b], src[c]], [dst[a], dst[b], dst[c]])

    if not corner:
        # Pied (0,0) -> (0,128u), sommet projeté de +40u vers la droite.
        quad([(0, 0), (256, 0), (256, 256), (0, 256)],
             [(105.6, 0), (105.6, 256), (3.2, 512), (3.2, 256)])
    else:
        # Deux bras de 64u. Le pli supérieur s'ouvre progressivement au tournant.
        out[0:256, 16:144] = source[:, :128]
        quad([(128, 0), (256, 0), (256, 256), (128, 256)],
             [(144, 0), (233.6, 128), (131.2, 384), (144, 256)])
    return Image.fromarray(out)


def posts(colors):
    raw = grid('bornes.png', 6, 4)
    result = {}
    for variant in range(2):
        rows = raw[variant*12:(variant+1)*12]
        normalized = []
        for fr in rows:
            a = np.array(fr); a[a[:, :, 3] < 40] = 0
            fr = Image.fromarray(a); box = bounds(fr, 150)
            # Corps, hors ombre basse : le sommet et le pied donnent une hauteur de 100u.
            factor = 200/(box[3]-box[1])
            width = round(fr.width*factor); height = round(fr.height*factor)
            image = fr.resize((width, height), Image.Resampling.NEAREST)
            canvas = Image.new('RGBA', (160, 256))
            canvas.paste(image, (80-round((box[0]+box[2])*.5*factor), 232-round(box[3]*factor)))
            normalized.append(quantize(canvas, colors))
        a = np.asarray(normalized[0])[:, :, 3]
        widths = [np.ptp(np.where(a[y] > 180)[0])+1 for y in range(80, 170) if np.any(a[y] > 180)]
        horizontal_scale = 70/float(np.median(widths))
        calibrated = []
        for fr in normalized:
            image = fr.resize((round(160*horizontal_scale), 256), Image.Resampling.NEAREST)
            canvas = Image.new('RGBA', (160, 256))
            canvas.paste(image, (80-round(80*horizontal_scale), 0))
            calibrated.append(canvas)
        normalized = calibrated
        # La pierre de la dernière pose éteinte reste fixe ; seules les zones
        # de runes et leur poussière peinte changent entre poses enregistrées.
        data = [np.array(fr) for fr in normalized]
        mask = np.zeros((256, 160), dtype=bool)
        for a in data:
            mask |= (a[:, :, 2].astype(int) > a[:, :, 1].astype(int)+20) & (a[:, :, 3] > 0)
        mask = ndi.binary_dilation(mask, iterations=1)
        stable = []
        for a in data:
            base = data[-1].copy(); base[mask] = a[mask]
            stable.append(Image.fromarray(base))
        result['object.barrier_1.seal_'+('a' if variant == 0 else 'b')] = {
            'idle': stable[:6], 'open': stable[6:]}
    return result


def publish(visual_id, frames, work):
    cell, anchor = SPECS[visual_id]
    folder = INCOMING / visual_id; folder.mkdir(parents=True, exist_ok=True)
    cols = max(map(len, frames.values()))
    sheet = Image.new('RGBA', (cell[0]*cols, cell[1]*len(frames)))
    animations = []
    for row, (name, poses) in enumerate(frames.items()):
        for col, pose in enumerate(poses):
            assert pose.size == cell
            sheet.paste(pose, (col*cell[0], row*cell[1]))
        animations.append({'name': name, 'source': 'poses.webp', 'grid': [cols, len(frames)],
                           'row': row, 'frames': len(poses), 'fps': 12,
                           'loop': name in ['loop', 'idle']})
    sheet.save(folder / 'poses.webp', lossless=True, exact=True)
    job = {'visual_id': visual_id, 'cell': list(cell), 'anchor': list(anchor), 'scale': .5,
           'target_height': 200, 'keep_size': True, 'registered_cells': True, 'status': 'final',
           'background': 'alpha', 'preserve_alpha': True, 'colors': 0, 'outline': False,
           'preview_zoom': 1, 'animations': animations, 'aliases': {},
           'palette_note': '32 couleurs maximum prélevées dans les Ruines ; alpha gradué conservé',
           'approval': 'chapitre 1 validé explicitement par le propriétaire',
           'source_recipe': 'tools/art/import_painted_barriers.py',
           'source_master': '../object.barrier_1/source/'}
    write(folder / 'job.json', job)
    import_sheet.REPO = str(ROOT)
    return import_sheet.run(str(folder / 'job.json'), preview_dir=str(work / 'imports'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets-root', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    args = parser.parse_args(); args.work.mkdir(parents=True, exist_ok=True)
    colors = palette(args.assets_root)
    veil = veil_frames(colors)
    variants = {'object.barrier_1': veil,
                'object.barrier_1.bias': {k: [project(p) for p in v] for k, v in veil.items()},
                'object.barrier_1.corner': {k: [project(p, True) for p in v] for k, v in veil.items()}}
    variants.update(posts(colors))
    entries = {ident: publish(ident, frames, args.work) for ident, frames in variants.items()}
    write(SOURCE / 'generation.json', {'mode': 'imagegen intégré', 'chapter': 1, 'approval': 'validé par le propriétaire',
          'sources': {p.name: digest(p) for p in SOURCE.glob('*.png') if p.name != 'palette.png'},
          'prompts': [p.name for p in SOURCE.glob('PROMPT_*.txt')],
          'processing': ['découpage en grille', 'retrait du matte neutre résiduel',
                         'recalage commun par planche', 'palette du décor et alpha gradué',
                         'raccord prémultiplié des bords', 'projection des pixels peints en biais et au pli'],
          'body_height_world': 100, 'module_length_world': 128, 'entries': entries,
          'no_gameplay_changes': True})
    print('BARRIERES_IMPORTEES', len(entries), 'assets ; chapitre 1 validé')


if __name__ == '__main__':
    main()
