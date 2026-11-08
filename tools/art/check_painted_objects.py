#!/usr/bin/env python3
"""Audit ciblé des objets peints et de leur contrat de raccordement."""
import argparse
import json
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from import_painted_objects import ROOT, INCOMING, IDS, PORTALS, CELL, ANCHOR, digest, write


def audit(reference_root=None):
    manifest = json.loads((ROOT/'assets/asset_manifest.json').read_text(encoding='utf-8'))['entries']
    records = {}
    for visual_id in IDS:
        entry = manifest[visual_id]
        folder = INCOMING/visual_id
        job = json.loads((folder/'job.json').read_text(encoding='utf-8'))
        palette = json.loads((folder/'source/palette.json').read_text(encoding='utf-8'))
        allowed = {tuple(color) for color in palette['rgb']}
        image = Image.open(ROOT/entry['sheet'].removeprefix('res://')).convert('RGBA')
        array = np.asarray(image)
        colors = {tuple(color) for color in array[array[:,:,3]>0,:3]}
        assert len(colors) <= 32 and colors <= allowed, (visual_id,'palette')
        assert entry['cell'] == list(CELL) and entry['anchor'] == list(ANCHOR) and entry['scale'] == .5
        assert max(image.size) <= 16384
        assert np.count_nonzero((array[:,:,3]>0)&(array[:,:,3]<128))>50, (visual_id,'ombre perdue')
        normalized = Image.open(folder/'poses.webp').convert('RGBA')
        assert image.crop((0,0,*normalized.size)).tobytes() == normalized.tobytes(), (visual_id,'recalage import')
        names = set(entry['animations'])
        expected = {'active','cooldown','enter','exit','hidden'} if visual_id in PORTALS else (
            {'idle','hit','hurt'} if visual_id.endswith('training_dummy') else
            {'idle','charged','primed','burst','debris','hidden'})
        assert names == expected, (visual_id,names)
        animations = {}
        for spec in job['animations']:
            details = []
            for i in range(spec['frames']):
                pose = image.crop((i*256,spec['row']*256,(i+1)*256,(spec['row']+1)*256))
                bounds = pose.getbbox()
                if bounds:
                    assert min(bounds[:2])>=2 and max(bounds[2:])<=254, (visual_id,spec['name'],i,bounds)
                alpha = np.asarray(pose)[:,:,3]
                yy,xx=np.where(alpha==255)
                height = int(yy.max()-yy.min()+1) if len(yy) else 0
                details.append({'bounds':list(bounds) if bounds else None,'body_height_world':height*.5})
            animations[spec['name']] = details
        first_name = job['animations'][0]['name']
        expected_height = 100 if visual_id in PORTALS else 70 if visual_id.endswith('training_dummy') else 72
        assert abs(animations[first_name][0]['body_height_world']-expected_height)<=.5
        if 'hidden' in names:
            row = entry['animations']['hidden']['row']
            assert not image.crop((0,row*256,256,(row+1)*256)).getbbox()
        if 'debris' in names:
            assert animations['burst'][-1]['body_height_world']<animations['burst'][0]['body_height_world']*.4
            assert animations['debris'][-1]['bounds'] is None
        icon=Image.open(ROOT/entry['icon'].removeprefix('res://')).convert('RGBA')
        bounds=icon.getbbox()
        assert icon.size==(64,64) and bounds and min(bounds[:2])>=3 and max(bounds[2:])<=61
        if visual_id in PORTALS:
            norm=json.loads((folder/'source/normalization.json').read_text(encoding='utf-8'))
            mask=Image.new('1',CELL);draw=ImageDraw.Draw(mask)
            draw.polygon(norm['water_polygon'],fill=1)
            origin=norm['source_anchors'][0];factor=norm['factor']
            points=[(round(128+(x-origin[0])*factor),round(232+(y-origin[1])*factor))
                    for x,y in [(153,24),(160,34),(153,44),(146,34)]]
            draw.polygon(points,fill=1)
            fixed=~np.asarray(mask).astype(bool)
            first=array[:256,:256]
            for row in range(4):
                for col in range(6):
                    pose=array[row*256:(row+1)*256,col*256:(col+1)*256]
                    assert np.array_equal(first[fixed],pose[fixed]), (visual_id,'cadre mobile',row,col)
        if visual_id.endswith('training_dummy'):
            first=array[207:256,:256]
            for row in range(2):
                for col in range(6):
                    assert np.array_equal(first,array[row*256+207:(row+1)*256,col*256:(col+1)*256]), 'pied mobile'
        records[visual_id]={'rgb_colors':len(colors),'animations':animations,
                            'sheet_sha256':digest(ROOT/entry['sheet'].removeprefix('res://'))}
    # La recharge n'identifie pas une paire par une coloration de sa pierre.
    cooldowns=[]
    for visual_id in PORTALS:
        image=Image.open(ROOT/manifest[visual_id]['sheet'].removeprefix('res://')).convert('RGBA')
        cooldowns.append(image.crop((0,256,1536,512)).tobytes())
    assert len(set(cooldowns))==1, 'recharges de couleurs différentes'
    old=json.loads(subprocess.check_output(['git','-c','safe.directory='+str(ROOT).replace('\\','/'),
        '-C',str(ROOT),'show','HEAD:assets/asset_manifest.json'],text=True,encoding='utf-8'))['entries']
    changed={key for key in old if old[key]!=manifest[key]}
    assert changed <= {'object.training_dummy','object.crystal_mirror'}, changed
    references={}
    for ident, rows in [('object.mirror_portal',4),('object.crystal_mirror',3),
                        ('object.crystal_mirror.marsh_heart',3),('object.training_dummy',2)]:
        path=INCOMING/ident/'source/planche.png'
        norm=json.loads((INCOMING/ident/'source/normalization.json').read_text(encoding='utf-8'))
        assert digest(path)==norm['source_sha256']
        assert len(norm['poses'])==rows*6
    if reference_root:
        reference_root=Path(reference_root)
        source_files={}
        samples={}
        for ident in IDS:
            pal=json.loads((INCOMING/ident/'source/palette.json').read_text(encoding='utf-8'))
            for spec in pal['source_files']:
                source_files[spec['path']]=spec
            for sample in pal['samples']:
                source=pal['source_files'][sample['source_index']]
                samples.setdefault(source['path'],[]).append(sample)
        for rel,spec in source_files.items():
            path=reference_root/rel
            assert digest(path)==spec['sha256'],path
            references[rel]=spec['sha256']
            image=Image.open(path).convert('RGB')
            for sample in samples.get(rel,[]):
                assert list(image.getpixel(tuple(sample['pixel_xy'])))==sample['rgb']
    return {'objects':records,'errors':[],'states_preserved':True,'static_portal_frames':True,
            'dummy_foot_fixed':True,'painted_source_cells':72,'runtime_pose_cells':156,
            'unchanged_old_manifest_entries':len(old)-len(changed),'modified_old_entries':sorted(changed),
            'reference_sha256':references,'zoom':1.3333,'scope':'banc statique, raccordement par Claude'}


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--reference-root')
    parser.add_argument('--out',default=str(ROOT/'docs/previews/objets-peints/audit_sprites.json'))
    args=parser.parse_args()
    result=audit(args.reference_root)
    write(Path(args.out),result)
    print('OBJETS_PEINTS_OK',len(result['objects']),'variantes ; 0 erreur')
