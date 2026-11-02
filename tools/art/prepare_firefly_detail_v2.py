from pathlib import Path
import json,hashlib,shutil
from PIL import Image
R=Path(__file__).resolve().parents[2]
B=R/'assets/concepts/incoming/map.firefly_woods'
D=B/'source/detail_v2'
D.mkdir(exist_ok=True)
(D/'inputs').mkdir(exist_ok=True)
(D/'outputs').mkdir(exist_ok=True)
source=Image.open(B/'source/map_source.png').convert('RGB')
assert source.size==(1536,1024)
locked=['assets/concepts/incoming/map.firefly_woods/source/map_source.png','assets/concepts/incoming/map.firefly_woods/collision/collision.png','assets/concepts/incoming/map.firefly_woods/collision/painted.webp','assets/environments/firefly_woods/field.png']
(D/'locked_sha256.json').write_text(json.dumps({p:hashlib.sha256((R/p).read_bytes()).hexdigest() for p in locked},indent=2)+'\n')
backup=R.parent/'detail-v2-work/before.webp'
if not backup.exists():shutil.copyfile(R/'assets/environments/firefly_woods/map.webp',backup)
regions=[]
for row in range(4):
 for col in range(6):
  rect=[max(0,col*256-32),max(0,row*256-32),min(1536,(col+1)*256+32),min(1024,(row+1)*256+32)]
  id=f'r{row+1}c{col+1}'
  crop=source.crop(rect)
  crop.resize((crop.width*7,crop.height*7),Image.Resampling.LANCZOS).save(D/'inputs'/f'{id}.png')
  regions.append(dict(id=id,row=row,col=col,source_rect=rect,core=[col*256,row*256,(col+1)*256,(row+1)*256],input=f'inputs/{id}.png',output=f'outputs/{id}.png'))
with Image.open(R/'assets/environments/cascade_ruins/map.webp') as im:
 im.crop((1100,1000,3340,3240)).save(D/'inputs/cascade_scale.png')
(D/'regions.json').write_text(json.dumps(dict(source_size=[1536,1024],world_size=[5016,3344],final_size=[11286,7524],overlap_source_pixels=64,regions=regions),indent=2)+'\n')
print('24 recadrages prêts ; source et collisions archivées par empreintes')
