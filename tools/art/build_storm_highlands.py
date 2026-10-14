#!/usr/bin/env python3
"""Construit les collisions des Hautes Terres ; les petits détails au sol sont traversables."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage
from build_map import hue_sat_light
ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/environments/storm_highlands'
SIZE = 5016
FIELD = 2508

def build():
    source = Image.open(ROOT / 'assets/concepts/incoming/map.storm_highlands/source/map_detailed.png').convert('RGB')
    small = source.resize((FIELD, FIELD), Image.Resampling.BOX)
    hue, sat, light = hue_sat_light(np.asarray(small))
    walk = (hue > 19) & (hue < 80) & (sat > .18) & (light > .32) & (light < .90)
    walk = np.asarray(Image.fromarray(walk.astype('uint8')*255).filter(ImageFilter.MedianFilter(7))) > 128
    layer = Image.new('L', (FIELD, FIELD)); d = ImageDraw.Draw(layer)
    def poly(points):
        d.polygon([(int(x*FIELD),int(y*FIELD)) for x,y in points],fill=255)
    def line(points,width):
        d.line([(int(x*FIELD),int(y*FIELD)) for x,y in points],fill=255,width=int(FIELD*width),joint='curve')
    # Places pavées et entrées existantes, sans englober les façades périphériques.
    poly([(.345,.425),(.47,.372),(.63,.426),(.648,.483),(.54,.526),(.386,.478)])
    line([(.48,.525),(.46,.575),(.43,.61)],.032)
    poly([(.387,.761),(.51,.718),(.626,.759),(.637,.826),(.528,.874),(.408,.814)])
    line([(.53,.863),(.54,.902),(.49,.935)],.035)
    # Clairière du départ et place des menhirs : les pierres restent en bordure.
    poly([(.052,.143),(.158,.137),(.19,.195),(.097,.206),(.041,.185)])
    # Cendres : vastes dalles ouvertes entre les pitons volcaniques.
    poly([(.04,.598),(.10,.571),(.155,.603),(.147,.678),(.069,.681)])
    line([(.13,.63),(.18,.649),(.215,.681),(.235,.722)],.032)
    # Ancienne arène supprimée : plateau naturel, aucune barrière de boss.
    poly([(.80,.677),(.875,.66),(.972,.70),(.959,.80),(.868,.842),(.803,.774)])
    walk |= np.asarray(layer)>0
    walk = ndimage.binary_closing(walk,iterations=3)
    holes,n = ndimage.label(~walk)
    counts=np.bincount(holes.ravel()); tiny=counts<250; tiny[0]=False
    walk |= tiny[holes]
    walk[:8,:]=False; walk[-8:,:]=False; walk[:,:8]=False; walk[:,-8:]=False
    labels,n=ndimage.label(walk)
    # Conserver le réseau de routes principal ; les corniches isolées restent du décor.
    sizes=np.bincount(labels.ravel()); sizes[0]=0
    walk=labels==sizes.argmax()
    signed=np.where(walk,ndimage.distance_transform_edt(walk)*2,-ndimage.distance_transform_edt(~walk)*2)
    start_uv=(.18,.19)
    yy,xx=np.mgrid[:FIELD,:FIELD]
    score=np.where(signed>=40,-np.hypot(xx-start_uv[0]*FIELD,yy-start_uv[1]*FIELD),-np.inf)
    sy,sx=np.unravel_index(score.argmax(),score.shape)
    start=[(sx+.5)*2-SIZE/2,(sy+.5)*2-SIZE/2]
    Image.fromarray(np.clip(np.round(signed/2)+128,0,255).astype('uint8')).save(BASE/'field.png')
    report={'world_size':[SIZE,SIZE],'source_size':list(source.size),'start':start,'small_rocks_blocking':False,'walkable_percent':round(walk.mean()*100,2)}
    (BASE/'collision_report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    mpath=ROOT/'assets/asset_manifest.json'; m=json.loads(mpath.read_text(encoding='utf8'))
    m['entries']['environment.storm_highlands']={'status':'final','kind':'map','map':'res://assets/environments/storm_highlands/map.webp','field':'res://assets/environments/storm_highlands/field.png','field_step':2,'arena_size':SIZE,'start':start,'filter':'linear','ambient':{'amount':0},'generated_by':'tools/art/build_storm_highlands.py'}
    mpath.write_text(json.dumps(m,ensure_ascii=False,indent='	')+'\n',encoding='utf8')
    print(json.dumps(report))
if __name__=='__main__': build()
