from pathlib import Path
import json
from PIL import Image
root=Path(__file__).resolve().parents[2]
out=root/'docs/previews/gue-des-brumes'
m=json.loads((root/'assets/asset_manifest.json').read_text(encoding='utf-8'))['entries']
items=[('plaine','Plaine fracturée','environment.fractured_plain_map',(1254,1254),(.50,.22)),('cascades','Ruines des Cascades','environment.cascade_ruins',(5016,1672),(.14,.45)),('hautes-terres',"Hautes Terres d’Orage",'environment.storm_highlands',(5016,5016),(.44,.43)),('bois','Bois des Lucioles',None,(5016,3344),(.45,.30)),('gue','Le Gué des Brumes',None,(5016,3344),(.50,.46))]
records=[]
zoom=1.3333
for id,label,key,world,center in items:
    entry=m[key] if key else {}
    paths=entry.get('map_tiles',[entry.get('map')])
    if id=='bois': paths=['assets/concepts/incoming/map.mist_ford/source/references/firefly_woods.webp']
    if id=='gue': paths=['assets/environments/mist_ford/map.webp']
    view=(1280/zoom,720/zoom)
    origin=(center[0]*world[0]-view[0]/2,center[1]*world[1]-view[1]/2)
    tw=world[0]/len(paths)
    tile=int(origin[0]//tw)
    assert origin[0]+view[0] <= (tile+1)*tw
    path=root/paths[tile].replace('res://','')
    with Image.open(path) as im:
        sx,sy=im.width/tw,im.height/world[1]
        rect=(round((origin[0]-tile*tw)*sx),round(origin[1]*sy),round((origin[0]+view[0]-tile*tw)*sx),round((origin[1]+view[1])*sy))
        im.crop(rect).save(out/(id+'-sol.png'))
    records.append(dict(id=id,label=label,crop='res://'+(out/(id+'-sol.png')).relative_to(root).as_posix(),capture='res://'+(out/(id+'.png')).relative_to(root).as_posix(),world_size=world,center_percent=[c*100 for c in center],camera_zoom=zoom,viewport=[1280,720],detail_strength=entry.get('detail_strength',0),source=path.relative_to(root).as_posix(),source_crop=rect,mode='Aperçu Godot, sprites réels, aucune logique de partie ni collision'))
(out/'comparaison.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('5 cadrages préparés')
