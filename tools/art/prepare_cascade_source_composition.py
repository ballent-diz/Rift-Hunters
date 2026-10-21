#!/usr/bin/env python3
"""Prépare des aperçus de composition uniquement ; aucune région ni collision."""
from pathlib import Path
import hashlib,json
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[2]
S=R/'assets/concepts/incoming/map.cascade_source/source'
P=R/'docs/previews/source-des-cascades'
P.mkdir(exist_ok=True)
font=ImageFont.truetype(str(R/'assets/fonts/inter/Inter-Variable.ttf'),24)
metadata={}
for name,raw in [('A','variant_A_connected_native.png'),('B','variant_B_native.png')]:
 im=Image.open(S/raw).convert('RGB')
 metadata[name]={'native_size':list(im.size),'composition_size':[1536,1536],'source':raw,'process':'Normalisation du canevas de composition uniquement ; aucun détail final revendiqué.'}
 comp=im.resize((1536,1536),Image.Resampling.LANCZOS);comp.save(S/('composition_'+name+'.png'))
 comp.resize((1024,1024),Image.Resampling.LANCZOS).save(P/('variante_'+name+'.png'))
 if name=='A':
  ann=comp.copy();d=ImageDraw.Draw(ann)
  for label,x,y in [('P1',49,79),('P2',78,44),('P3',24,36),('P4',62,15)]:
   cx,cy=round(x*15.36),round(y*15.36)
   d.rounded_rectangle((cx-30,cy-22,cx+36,cy+24),radius=9,fill='#1c2632',outline='white',width=2)
   d.text((cx-22,cy-15),label,font=font,fill='white')
  for x,y in [(69,59),(57,37),(40,19)]:
   cx,cy=round(x*15.36),round(y*15.36);d.ellipse((cx-21,cy-21,cx+21,cy+21),outline='#6fffe1',width=4)
  for x,y,w,h in [(14,66,72,10),(13,18,19,9)]:
   d.rectangle((x*15.36,y*15.36,(x+w)*15.36,(y+h)*15.36),outline='#68c4ff',width=3)
  ann.save(P/'plan_A_annote.png')
board=Image.new('RGB',(2048,1080),'#18212b');d=ImageDraw.Draw(board)
for k,n in enumerate(['A','B']):
 d.text((30+k*1024,14),'Variante '+n+(' — connexions corrigées' if n=='A' else ' — proposition initiale'),font=font,fill='white')
 board.paste(Image.open(P/('variante_'+n+'.png')),(k*1024,56))
board.save(P/'comparaison_A_B.png')
(S/'generation.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(S/'SHA256SUMS.txt').write_text('\n'.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(S).as_posix() for p in sorted(S.rglob('*')) if p.is_file() and p.name!='SHA256SUMS.txt')+'\n',encoding='utf-8')
print('Compositions1536² et aperçus validés ; aucune région générée.')
