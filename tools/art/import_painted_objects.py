#!/usr/bin/env python3
"""Détoure et importe les objets peints ; aucun dessin ou changement de gameplay.

Les palettes retenues et leurs prélèvements sont conservés dans chaque source/.
La préparation des cellules fige le pied, le cadre des portails et les ombres.
"""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
import import_sheet

ROOT = Path(__file__).resolve().parents[2]
INCOMING = ROOT / 'assets/concepts/incoming'
CELL = (256, 256)
ANCHOR = (128, 232)
PORTALS = ['object.mirror_portal', 'object.mirror_portal.sage',
           'object.mirror_portal.pale_gold', 'object.mirror_portal.lilac_grey']
IDS = PORTALS + ['object.crystal_mirror', 'object.crystal_mirror.marsh_heart', 'object.training_dummy']


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def cutouts(visual_id, rows):
    """Retire le résidu blanc du fond généré et sépare l'ombre déjà peinte.

    L'ombre neutre, matée sur blanc dans la source, retrouve un alpha par sa
    luminance. Aucun nouvel ovale ni texture de sol n'est dessiné.
    """
    path = INCOMING / visual_id / 'source/planche.png'
    image = Image.open(path).convert('RGBA')
    result, records = [], []
    for row in range(rows):
        for col in range(6):
            region = (round(col * image.width / 6), round(row * image.height / rows),
                      round((col + 1) * image.width / 6), round((row + 1) * image.height / rows))
            arr = np.asarray(image.crop(region)).copy()
            rgb = arr[:, :, :3].astype(float)
            chroma = rgb.max(2) - rgb.min(2)
            body = (arr[:, :, 3] >= 220) & (rgb.min(2) < 225) & (chroma >= 8)
            if visual_id == 'object.training_dummy':
                body &= ~((rgb[:, :, 0] > 210) & (rgb[:, :, 1] < 70) & (rgb[:, :, 2] < 70))
            labels, _ = ndi.label(body, np.ones((3, 3)))
            sizes = np.bincount(labels.ravel()); sizes[0] = 0
            assert sizes.max() > 150, (visual_id, row, col)
            # Conserver aussi les fragments séparés pendant burst.
            body = np.isin(labels, np.where(sizes >= max(8, sizes.max() * .001))[0])
            body = ndi.binary_fill_holes(body)
            yy, xx = np.where(body)
            bounds = (int(xx.min()), int(yy.min()), int(xx.max()+1), int(yy.max()+1))
            # La zone sous le corps contient la véritable ombre portée de la source.
            yy_grid, xx_grid = np.indices(body.shape)
            low = yy_grid >= bounds[3] - max(14, round((bounds[3]-bounds[1]) * .18))
            near = (xx_grid >= bounds[0]-8) & (xx_grid <= bounds[2]+60)
            darkness = np.clip((245 - rgb.mean(2)) / 200, 0, .46)
            shadow_alpha = np.where(low & near & ~body & (arr[:, :, 3] >= 8),
                                    darkness * arr[:, :, 3], 0)
            shadow_alpha[shadow_alpha < 12] = 0
            shadow = np.zeros_like(arr)
            shadow[:, :, 3] = (np.round(shadow_alpha / 8) * 8).clip(0, 120).astype(np.uint8)
            arr[:, :, 3] = body.astype(np.uint8) * 255
            arr[~body, :3] = 0
            result.append((Image.fromarray(arr), Image.fromarray(shadow), bounds))
            records.append({'row': row, 'column': col, 'source_region': list(region),
                            'body_bounds': list(bounds)})
    return result, {'source_sha256': digest(path), 'size': list(image.size), 'poses': records}


def place(image, origin, factor):
    size = (round(image.width * factor), round(image.height * factor))
    image = image.resize(size, Image.Resampling.NEAREST)
    canvas = Image.new('RGBA', CELL)
    canvas.paste(image, (round(ANCHOR[0] - origin[0] * factor), round(ANCHOR[1] - origin[1] * factor)))
    return canvas


def normalize(visual_id, rows, height):
    poses, record = cutouts(visual_id, rows)
    reference = poses[0][2]
    factor = height / (reference[3] - reference[1])
    # Relevé du pied sur le corps seulement : l'ombre ne déplace jamais l'objet.
    anchors = []
    for body, _, bounds in poses[:6]:
        alpha = np.asarray(body)[:, :, 3] > 0
        xs = np.where(alpha[max(bounds[1], bounds[3]-5):bounds[3]].any(0))[0]
        anchors.append((float(np.median(xs)), float(bounds[3]-1)))
    bodies = [place(body, anchors[i % 6], factor) for i, (body, _, _) in enumerate(poses)]
    shadow = place(poses[0][1], anchors[0], factor)
    shadow_data = np.asarray(shadow).copy()
    # L'ombre ne doit pas conserver des pixels de matière d'une autre pose.
    shadow_data[np.asarray(bodies[0])[:, :, 3] > 0] = 0
    shadow = Image.fromarray(shadow_data)
    record.update({'source_visual_id': visual_id, 'target_body_height_px': height, 'scale': .5, 'factor': factor,
                   'cell': list(CELL), 'anchor': list(ANCHOR), 'source_anchors': anchors,
                   'resample': 'NEAREST', 'cast_shadow': 'ombre de la première pose détourée, alpha conservé'})
    return bodies, shadow, record


def palette_for(visual_id):
    return json.loads((INCOMING / visual_id / 'source/palette.json').read_text(encoding='utf-8'))


def map_colors(rgb, colors):
    values = np.asarray(colors, dtype=np.int32)
    flat = rgb.reshape(-1, 3).astype(np.int32)
    # Lots bornés pour ne pas allouer une distance pour toute la planche.
    result = np.empty_like(flat, dtype=np.uint8)
    for start in range(0, len(flat), 8192):
        block = flat[start:start+8192]
        distance = ((block[:, None, :] - values[None, :, :]) ** 2).sum(2)
        result[start:start+8192] = values[distance.argmin(1)]
    return result.reshape(rgb.shape)


def quantize(body, shadow, colors, accent=None, accent_mask=None):
    arr = np.asarray(body).copy()
    arr[:, :, :3] = map_colors(arr[:, :, :3], colors[:24] if accent is not None else colors)
    if accent is not None:
        mask, desired, crown = accent_mask
        arr[mask, :3] = map_colors(desired[mask], colors)
        arr[crown, :3] = map_colors(desired[crown], colors[24:])
    arr[arr[:, :, 3] == 0, :3] = 0
    sh = np.asarray(shadow).copy()
    sh[:, :, :3] = colors[0]
    sh[sh[:, :, 3] == 0, :3] = 0
    return Image.alpha_composite(Image.fromarray(sh), Image.fromarray(arr))


def polygon(points):
    mask = Image.new('1', CELL)
    ImageDraw.Draw(mask).polygon(points, fill=1)
    return np.asarray(mask).astype(bool)


def portal_frames():
    bodies, shadow, record = normalize(PORTALS[0], 4, 200)
    origin = record['source_anchors'][0]; factor = record['factor']
    def coords(points):
        return [(round(ANCHOR[0]+(x-origin[0])*factor), round(ANCHOR[1]+(y-origin[1])*factor)) for x,y in points]
    water = polygon(coords([(153,56),(169,67),(181,85),(182,193),(117,193),(117,86),(131,66)]))
    crown = polygon(coords([(153,24),(160,34),(153,44),(146,34)]))
    reference = np.asarray(bodies[0])
    fixed = []
    for i, frame in enumerate(bodies):
        arr = reference.copy()
        source = np.asarray(frame)
        arr[water] = source[water]
        # Le cadre et la mousse sont strictement identiques ; seules vitre et gemme varient.
        if i // 6 == 1:
            arr[crown, :3] = (arr[crown, :3].astype(float) * .52).astype(np.uint8)
        fixed.append(Image.fromarray(arr))
    fixed[5] = fixed[0].copy()  # fermeture de la boucle
    fixed[17] = fixed[0].copy()
    fixed[18] = fixed[0].copy()
    fixed[23] = fixed[0].copy()
    record['stable_frame'] = 'cadre, mousse et ombre de active/0 ; seules vitre et gemme changent'
    record['water_polygon'] = coords([(153,56),(169,67),(181,85),(182,193),(117,193),(117,86),(131,66)])
    for visual_id in PORTALS:
        pal = palette_for(visual_id)
        colors = pal['rgb']
        target = np.asarray(pal['pair_rgb'], dtype=float)
        frames = []
        for i, body in enumerate(fixed):
            arr = np.asarray(body)
            source_luma = arr[:, :, :3].mean(2)
            threshold = np.percentile(source_luma[water], 94)
            lit = water & (source_luma >= threshold)
            mask = crown | lit
            if i // 6 == 1:
                frames.append(quantize(body, shadow, colors[:24]))
                continue
            desired = arr[:, :, :3].astype(float).copy()
            # Conversion de palette limitée à la gemme et aux reflets peints.
            luma = desired.mean(2)
            desired[crown] = np.clip(target * (luma[crown,None] / 110).clip(.4,1.4),0,255)
            desired[lit] = desired[lit] * .8 + target * .2
            frames.append(quantize(body, shadow, colors, True, (mask,desired.astype(np.uint8),crown)))
        save_job(visual_id, frames, [('active',6,8,True),('cooldown',6,8,True),
                 ('enter',6,10,False),('exit',6,10,False)], record, empty=['hidden'])


def save_job(visual_id, frames, animations, record, aliases=None, empty=None):
    folder = INCOMING / visual_id
    rows = len(animations)
    strip = Image.new('RGBA', (CELL[0]*6, CELL[1]*rows))
    offset = 0
    entries = []
    for row, (name, count, fps, loop) in enumerate(animations):
        for col in range(count):
            strip.paste(frames[offset+col], (col*CELL[0],row*CELL[1]))
        offset += count
        entries.append({'name':name,'source':'poses.webp','grid':[6,rows], 'row':row,
                        'frames':count, 'fps':fps,'loop':loop})
    folder.mkdir(parents=True,exist_ok=True)
    strip.save(folder/'poses.webp',lossless=True,exact=True,method=4)
    write(folder/'job.json', {'visual_id':visual_id,'cell':list(CELL),'anchor':list(ANCHOR),
          'scale':.5,'target_height':record['target_body_height_px'],'keep_size':True,
          'registered_cells':True,'status':'final','background':'alpha','preserve_alpha':True,
          'colors':0,'outline':False,'preview_zoom':1,'animations':entries,
          'aliases': aliases or {},'empty_animations':[{'name':n,'fps':12,'loop':False} for n in empty or []],
          'palette_note':'32 couleurs prélevées dans le décor, déjà appliquées dans poses.webp',
          'source_recipe':'tools/art/import_painted_objects.py'})
    write(folder/'source/normalization.json',record)
    preview_dir = ROOT/'docs/previews/objets-peints'
    entry = import_sheet.run(str(folder/'job.json'), preview_dir=str(preview_dir))
    preview = preview_dir/(visual_id.replace('.','_')+'_import.png')
    image = Image.open(preview)
    if image.width > 1600:
        image.resize((1600,round(image.height*1600/image.width)),Image.Resampling.NEAREST).save(preview)
    # L'icône doit contenir le corps entier, y compris pour ces grandes cellules.
    icon = frames[0].crop(frames[0].getbbox())
    icon.thumbnail((58,58),Image.Resampling.NEAREST)
    output = Image.new('RGBA',(64,64))
    output.paste(icon,((64-icon.width)//2,(64-icon.height)//2))
    output.save(ROOT/entry['icon'].removeprefix('res://'))
    print(visual_id, len(frames), 'poses ; source',record['source_sha256'][:12])


def crystal_frames():
    gardens, shadow13, rec13 = normalize('object.crystal_mirror',3,144)
    terrace, shadow15, rec15 = normalize('object.crystal_mirror.marsh_heart',3,144)
    for visual_id, bodies, shadow, record in [
            ('object.crystal_mirror',gardens,shadow13,rec13),
            ('object.crystal_mirror.marsh_heart',terrace,shadow15,rec15)]:
        if visual_id == 'object.crystal_mirror':
            # La source complémentaire termine la fracture, sans regonfler le corps.
            bodies[16:18] = [frame.copy() for frame in terrace[16:18]]
            record['burst_completion'] = {'source':'../object.crystal_mirror.marsh_heart/source/planche.png',
                                          'source_sha256':rec15['source_sha256'],'poses':[16,17]}
        bodies[5] = bodies[0].copy()
        colors=palette_for(visual_id)['rgb']
        frames=[quantize(body,shadow,colors) for body in bodies]
        # État existant facultatif : débris peints de la dernière pose, extinction courte.
        debris=[]
        for opacity in [1,.8,.6,.4,.2,0]:
            arr=np.asarray(frames[-1]).copy()
            arr[:,:,3]=np.round(arr[:,:,3].astype(float)*opacity).astype(np.uint8)
            arr[arr[:,:,3]==0,:3]=0
            debris.append(Image.fromarray(arr))
        save_job(visual_id,frames+debris,[('idle',6,8,True),('charged',6,7,True),
                 ('burst',6,12,False),('debris',6,7,False)],record,aliases={'primed':'charged'},empty=['hidden'])


def dummy_frames():
    bodies,shadow,record=normalize('object.training_dummy',2,140)
    reference=np.asarray(bodies[0]);fixed=[]
    for body in bodies:
        arr=np.asarray(body).copy()
        arr[ANCHOR[1]-25:]=reference[ANCHOR[1]-25:]
        fixed.append(Image.fromarray(arr))
    fixed[5]=fixed[0].copy();fixed[6]=fixed[0].copy();fixed[11]=fixed[0].copy()
    colors=palette_for('object.training_dummy')['rgb']
    frames=[quantize(body,shadow,colors) for body in fixed]
    record['stable_foot']='25 dernières lignes du corps et ombre reprises de idle/0 ; retour hit/5 = idle/0'
    save_job('object.training_dummy',frames,[('idle',6,8,True),('hit',6,14,False)],record,aliases={'hurt':'hit'})


if __name__=='__main__':
    portal_frames()
    crystal_frames()
    dummy_frames()
