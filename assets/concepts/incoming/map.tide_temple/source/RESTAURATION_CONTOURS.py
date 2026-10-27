"""Essai hors dépôt : restaurer les contours sans remplacer la matière peinte."""
from pathlib import Path
import sys,json,hashlib
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
Image.MAX_IMAGE_PIXELS=None
root=Path(__file__).resolve().parent;repo=root/'Rift-Hunters-c12';w=root/'c12-work'
sys.path.insert(0,str(repo/'tools/art'))
import deblur_map as d
d.CACHE=root/'detail-work/models'
paths=[repo/f'assets/environments/tide_temple/{n}.webp' for n in ['map','map_1']]
full=Image.new('RGB',(7524,11286))
for i,p in enumerate(paths):full.paste(Image.open(p).convert('RGB'),(3762*i,0))
src=np.asarray(full);out=np.empty_like(src);sess=d.session();inner=d.BLOCK-2*d.OVERLAP
blocks=[(y,x) for y in range(0,full.height,inner) for x in range(0,full.width,inner)]
for i,(y,x) in enumerate(blocks):
 y0,x0=max(0,y-d.OVERLAP),max(0,x-d.OVERLAP);y1,x1=min(full.height,y+inner+d.OVERLAP),min(full.width,x+inner+d.OVERLAP)
 base=src[y0:y1,x0:x1];restored=d.sharpen_block(sess,base)
 # La matière et les volumes restent ceux du dessin original. Seuls les contours
 # et petits détails réellement reconstruits par le réseau sont transférés.
 residual=restored-ndi.gaussian_filter(restored,(1.25,1.25,0))
 fused=np.clip(base.astype(np.float32)+residual*.75+0.5,0,255).astype(np.uint8)
 ys=slice(y-y0,y-y0+min(inner,full.height-y));xs=slice(x-x0,x-x0+min(inner,full.width-x))
 out[y:y+inner,x:x+inner]=fused[ys,xs]
 if i%20==0:print(f'bloc {i+1} / {len(blocks)}',flush=True)
dest=w/'detail-restored';dest.mkdir(exist_ok=True);Image.fromarray(out).save(dest/'tide_temple.png')
report={'method':'Matière originale conservée ; transfert des contours reconstruits par le modèle officiel, pas de bruit ajouté. Traitement uniforme de toute la carte après passe de régions.','model':'realesr_general_x4v3_0.2.onnx','model_sha256':hashlib.sha256((d.CACHE/'realesr_general_x4v3_0.2.onnx').read_bytes()).hexdigest(),'DENOISE':.2,'block':d.BLOCK,'overlap':d.OVERLAP,'detail_filter_sigma':1.25,'detail_weight':.75,'source_sha256':[hashlib.sha256(p.read_bytes()).hexdigest() for p in paths],'output_sha256':hashlib.sha256((dest/'tide_temple.png').read_bytes()).hexdigest()}
(dest/'provenance.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8');print('Essai complet enregistré, aucune tuile du dépôt remplacée.',flush=True)
