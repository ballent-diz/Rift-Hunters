#!/usr/bin/env python3
"""Masque technique binaire des dix plaques observées, sans collision ni donnée de combat."""
from pathlib import Path
from collections import deque
import json,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/'assets/concepts/incoming/map.scorched_verge'
PREVIEW=ROOT/'docs/previews/scorched-verge'
CENTERS=[(330,330),(230,460),(310,650),(680,305),(770,460),(680,690),(850,610),(1275,450),(1200,535),(1360,685)]
SPAWN=(200,575)
def hull(points):
 points=sorted(set(points))
 def cross(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
 lo=[]
 for p in points:
  while len(lo)>=2 and cross(lo[-2],lo[-1],p)<=0:lo.pop()
  lo.append(p)
 hi=[]
 for p in reversed(points):
  while len(hi)>=2 and cross(hi[-2],hi[-1],p)<=0:hi.pop()
  hi.append(p)
 return lo[:-1]+hi[:-1]
def main():
 im=Image.open(FOLDER/'composition.png').convert('RGB')
 assert im.size==(1536,1024),im.size
 arr=np.asarray(im).astype(np.int32)
 PREVIEW.mkdir(exist_ok=True);(PREVIEW/'.gdignore').write_text('')
 mask=Image.new('RGB',im.size,(0,0,0));draw=ImageDraw.Draw(mask)
 records=[];unit=5016/1536
 for index,(cx,cy) in enumerate(CENTERS,1):
  x0,y0=max(0,cx-62),max(0,cy-48)
  patch=arr[y0:cy+49,x0:cx+63]
  red,green,blue=patch[:,:,0],patch[:,:,1],patch[:,:,2]
  selected=(red>235)&(green>55)&(green<210)&(blue<80)&(red>1.4*green)
  ys,xs=np.where(selected)
  assert len(xs)>40,(index,len(xs))
  polygon=hull([(int(x+x0+dx),int(y+y0+dy)) for x,y in zip(xs,ys) for dx,dy in [(-2,0),(2,0),(0,-2),(0,2)]])
  draw.polygon(polygon,fill=(255,0,255))
  bbox=[min(x for x,y in polygon),min(y for x,y in polygon),max(x for x,y in polygon)+1,max(y for x,y in polygon)+1]
  diameter=max(bbox[2]-bbox[0],bbox[3]-bbox[1])*unit
  assert 150<=diameter<=400,(index,diameter,bbox)
  records.append({'id':f'H{index:02}','center_px':[cx,cy],'center_percent':[round(cx/15.36,2),round(cy/10.24,2)],'polygon_px':polygon,'bbox_px':bbox,'diameter_world':round(diameter,1)})
 pixels=np.asarray(mask)
 assert set(map(tuple,np.unique(pixels.reshape(-1,3),axis=0)))=={(0,0,0),(255,0,255)}
 binary=pixels[:,:,0]>0
 seen=np.zeros(binary.shape,dtype=bool);components=0
 for y,x in zip(*np.where(binary)):
  if seen[y,x]:continue
  components+=1;todo=deque([(int(x),int(y))]);seen[y,x]=True
  while todo:
   px,py=todo.popleft()
   for nx,ny in [(px-1,py),(px+1,py),(px,py-1),(px,py+1)]:
    if 0<=nx<1536 and 0<=ny<1024 and binary[ny,nx] and not seen[ny,nx]:
     seen[ny,nx]=True;todo.append((nx,ny))
 assert components==10,components
 ys,xs=np.where(binary)
 minimum=float(np.sqrt((xs-SPAWN[0])**2+(ys-SPAWN[1])**2).min())
 assert minimum*unit>=200
 mask.save(FOLDER/'hazards.png')
 data={'image_size':[1536,1024],'world_size':[5016,3344],'spawn_proposal_px':list(SPAWN),'spawn_proposal_percent':[round(SPAWN[0]/15.36,2),round(SPAWN[1]/10.24,2)],'hazard_color':'#FF00FF','background':'#000000','component_count':components,'spawn_minimum_distance_world':round(minimum*unit,1),'method':'Enveloppes convexes des fissures orange dans dix zones de relevé contrôlées ; inclut le charbon entre les fissures et une marge de 2 pixels sur leurs bords visibles. Ce masque de dégâts ne représente jamais les collisions.','hazards':records}
 (FOLDER/'source/hazard_annotations.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 overlay=im.convert('RGBA');layer=Image.new('RGBA',im.size);ld=ImageDraw.Draw(layer)
 font=ImageFont.truetype(str(ROOT/'assets/fonts/inter/Inter-Variable.ttf'),18)
 for rec in records:
  ld.polygon([tuple(p) for p in rec['polygon_px']],fill=(255,0,255,80),outline=(255,140,255,255))
  x,y=rec['center_px'];ld.text((x-14,y-13),rec['id'],fill='white',font=font,stroke_width=2,stroke_fill='#222222')
 ld.ellipse((SPAWN[0]-13,SPAWN[1]-13,SPAWN[0]+13,SPAWN[1]+13),fill='#6fffd0')
 ld.text((SPAWN[0]-40,SPAWN[1]+15),'Départ',fill='white',font=font,stroke_width=2,stroke_fill='#222222')
 overlay.alpha_composite(layer);overlay.convert('RGB').save(PREVIEW/'plaques-annotees.png')
 im.save(PREVIEW/'composition.png')
 mask.save(PREVIEW/'hazards.png')
 result={k:data[k] for k in ['image_size','world_size','component_count','spawn_minimum_distance_world']}
 result['colors_exact']=True;result['hazard_diameters_world']=[r['diameter_world'] for r in records]
 (PREVIEW/'controle.json').write_text(json.dumps(result,indent=2)+'\n')
 (FOLDER/'source/SHA256SUMS.txt').write_text('\n'.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(FOLDER).as_posix() for p in sorted(FOLDER.rglob('*')) if p.is_file() and p.name!='SHA256SUMS.txt')+'\n')
 print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':main()
