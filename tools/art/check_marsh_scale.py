#!/usr/bin/env python3
"""Prouve les invariants du lot d'échelle de la carte 15 sur les fichiers livrés."""
import argparse
import json
import subprocess
from pathlib import Path
import numpy as np
from PIL import Image
from finish_marsh_scale import ROOT,SOURCE,SCALE,baseline_file,digest


def check(work):
    work=Path(work);work.mkdir(parents=True,exist_ok=True)
    recipe=json.loads((SCALE/'recipe.json').read_text(encoding='utf-8'))
    cache=work/'baseline';cache.mkdir(exist_ok=True)
    baseline=recipe.get('protected_commit',recipe['baseline_commit'])
    old=Image.open(baseline_file(recipe,recipe['master_path'],cache)).convert('RGB')
    new=Image.open(SOURCE/'map_detailed.webp').convert('RGB')
    mask=Image.open(SCALE/'edit_mask.png').convert('L')
    assert old.size==new.size==mask.size==(2508,3762)
    allowed=np.asarray(mask)>0
    changed=np.any(np.asarray(old)!=np.asarray(new),axis=2)
    assert not np.any(changed&~allowed)
    protected={}
    for rel,expected in recipe['protected_sha256'].items():
        actual=digest(ROOT/rel)
        assert actual==expected,rel
        protected[rel]=actual
    git=['git','-c','safe.directory='+str(ROOT).replace('\\','/'),'-C',str(ROOT)]
    subprocess.check_call(git+['diff','--exit-code',baseline,'--']+list(recipe['protected_sha256']),
                          stdout=subprocess.DEVNULL)
    forbidden=subprocess.check_output(git+['diff','--name-only',baseline,'--','src','data',
        'assets/environments/mist_ford','assets/concepts/incoming/map.mist_ford']).decode().strip()
    assert not forbidden,forbidden
    tiles=[]
    for i,name in enumerate(['map.webp','map_1.webp']):
        rel='assets/environments/marsh_heart/'+name
        before=np.asarray(Image.open(baseline_file(recipe,rel,cache)).convert('RGB'))
        after=np.asarray(Image.open(ROOT/rel).convert('RGB'))
        assert before.shape==after.shape==(11286,3762,3)
        a=np.asarray(mask.crop((i*1254,0,(i+1)*1254,3762)).resize((3762,11286),Image.Resampling.NEAREST))>0
        delta=np.any(before!=after,axis=2)
        assert not np.any(delta&~a)
        tiles.append({'name':name,'size':[3762,11286],'changed_pixels':int(delta.sum()),
                      'changed_pixels_outside_edit_mask':0,'sha256':digest(ROOT/rel)})
    bridges=[]
    for x,y,w,h in [[600,2360,720,140],[2020,2360,740,140],[650,2940,710,140],[1990,2940,760,140]]:
        box=tuple(round(v*.75) for v in [x,y,x+w,y+h])
        count=int(changed[box[1]:box[3],box[0]:box[2]].sum())
        assert count==0,box
        bridges.append({'world_rect':[x,y,w,h],'changed_master_pixels':count})
    return {'ok':True,'world':[3344,5016],'native_size':[2508,3762],'density':2.25,
        'baseline_commit':recipe['baseline_commit'],'protected_comparison_commit':baseline,
        'master_changed_pixels':int(changed.sum()),
        'master_changed_share':float(changed.mean()),'master_changed_outside_edit_mask':0,
        'protected_gameplay_files_byte_identical':protected,'bridges':bridges,'tiles':tiles,
        'forbidden_paths_changed':[],
        'scope':'Les joints et silhouettes des colonnes changent dans les emprises de retouche ; '
                'les bitmaps de praticabilité, le champ, le plan et le manifeste sont identiques.'}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work',required=True)
    parser.add_argument('--out',required=True)
    args=parser.parse_args()
    result=check(args.work)
    Path(args.out).parent.mkdir(parents=True,exist_ok=True)
    Path(args.out).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('GEOMETRIE_CONSERVEE : 0 pixel runtime modifié hors retouche ; collisions, field, plan inchangés')
