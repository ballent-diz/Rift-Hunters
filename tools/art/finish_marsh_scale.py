#!/usr/bin/env python3
"""Présente le master d'échelle en conservant les pixels runtime hors retouche.

La source finale et le masque de retouche sont retenus ; les anciens fichiers
se récupèrent dans le commit de référence indiqué par recipe.json.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'assets/concepts/incoming/map.marsh_heart/source'
SCALE=SOURCE/'echelle'
Image.MAX_IMAGE_PIXELS=None


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def baseline_file(recipe,rel,cache):
    path=cache/Path(rel).name
    expected=recipe['baseline_sha256'][rel]
    if not path.exists() or digest(path)!=expected:
        data=subprocess.check_output(['git','-c','safe.directory='+str(ROOT).replace('\\','/'),
            '-C',str(ROOT),'show',recipe['baseline_commit']+':'+rel])
        assert hashlib.sha256(data).hexdigest()==expected,rel
        path.write_bytes(data)
    return path


def export(work,output=None):
    work=Path(work).resolve()
    assert not work.is_relative_to(ROOT),'Intermédiaires hors dépôt'
    work.mkdir(parents=True,exist_ok=True)
    recipe=json.loads((SCALE/'recipe.json').read_text(encoding='utf-8'))
    cache=work/'baseline';cache.mkdir(exist_ok=True)
    master=Image.open(SOURCE/'map_detailed.webp').convert('RGB')
    old_path=baseline_file(recipe,recipe['master_path'],cache)
    old=Image.open(old_path).convert('RGB')
    assert master.size==old.size==(2508,3762)
    mask=Image.open(SCALE/'edit_mask.png').convert('L')
    allowed=np.asarray(mask)>0
    assert np.array_equal(np.asarray(master)[~allowed],np.asarray(old)[~allowed])
    folder=Path(output) if output else ROOT/'assets/environments/marsh_heart'
    folder.mkdir(parents=True,exist_ok=True)
    records=[]
    for i,name in enumerate(['map.webp','map_1.webp']):
        rel='assets/environments/marsh_heart/'+name
        old_tile=Image.open(baseline_file(recipe,rel,cache)).convert('RGB')
        assert old_tile.size==(3762,11286)
        # Inclure le voisinage Lanczos du joint, sans refaire le reste de l'image.
        left=max(0,i*1254-8);right=min(2508,(i+1)*1254+8)
        box=(left,0,right,3762);size=((right-left)*3,11286)
        crop=((i*1254-left)*3,0,((i+1)*1254-left)*3,11286)
        before=old.crop(box).resize(size,Image.Resampling.LANCZOS).crop(crop)
        after=master.crop(box).resize(size,Image.Resampling.LANCZOS).crop(crop)
        local_mask=np.asarray(mask.crop((i*1254,0,(i+1)*1254,3762)).resize(
            old_tile.size,Image.Resampling.NEAREST))>0
        original=np.asarray(old_tile)
        delta=np.asarray(after).astype(np.int16)-np.asarray(before).astype(np.int16)
        result=original.copy()
        result[local_mask]=np.clip(original[local_mask].astype(np.int16)+delta[local_mask],0,255).astype(np.uint8)
        assert np.array_equal(result[~local_mask],original[~local_mask])
        path=folder/name
        Image.fromarray(result).save(path,lossless=True,exact=True,method=6)
        # Contrôler le fichier relu, pas seulement le tampon avant encodage.
        decoded=np.asarray(Image.open(path).convert('RGB'))
        assert np.array_equal(result,decoded),name
        changed=np.any(decoded!=original,axis=2)
        assert not np.any(changed&~local_mask)
        records.append({'file':name,'size':list(old_tile.size),'bytes':path.stat().st_size,
            'sha256':digest(path),'changed_pixels':int(changed.sum()),
            'changed_outside_edit_mask':0,'lossless_roundtrip_verified':True})
        print('TUILE_CONFORME',name,path.stat().st_size,flush=True)
        del original,result,decoded,delta,before,after,old_tile
    report={'world':[3344,5016],'density':2.25,'native_density':.75,
        'baseline_commit':recipe['baseline_commit'],'tiles':records,
        'unchanged_runtime_pixels_outside_edit_mask':True,
        'method':'delta du master natif présenté en Lanczos, appliqué seulement au masque ; WebP sans perte',
        'no_synthetic_texture':True}
    (work/'presentation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work',required=True)
    parser.add_argument('--out')
    args=parser.parse_args()
    export(args.work,args.out)
