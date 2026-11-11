"""Première passe du masquage de la carte 16 (Entrée du Glacier) : les 13 rochers-abris.

  python3 assets/concepts/incoming/map.glacier_entry/occlusion/trace_rocks.py <dossier de contrôle>

Flancs détourés par la couleur (glace saturée contre neige), sommet enneigé relevé à la main (trois points par rocher,
la neige du sommet a la couleur du sol), ligne de pied au bord bas de la collision. Écrit outlines.json à côté et des
planches de contrôle seg_*.png dans le dossier donné. Suite : docs/maps/MASQUAGE_PAR_LE_DECOR.md.
"""
import sys, json
from PIL import Image, ImageDraw
import numpy as np
from scipy import ndimage
Image.MAX_IMAGE_PIXELS=None
S=sys.argv[1]
import os
os.makedirs(S, exist_ok=True)
tiles_in=[Image.open('assets/environments/glacier_entry/'+n) for n in ('map.webp','map_1.webp','map_2.webp')]
full=Image.new('RGB',(sum(t.size[0] for t in tiles_in),tiles_in[0].size[1]))
_x=0
for _t in tiles_in:
    full.paste(_t,(_x,0)); _x+=_t.size[0]
col=np.array(Image.open('assets/concepts/incoming/map.glacier_entry/collision/collision.png').convert('L'))<128
rocks=[(2417,715,225,160),(3581,624,194,153),(4276,413,191,152),(2046,1140,200,163),(4543,932,202,159),(589,1283,188,151),(3769,1427,195,150),(4304,1292,190,145),(2639,1955,215,155),(777,2146,193,153),(382,2711,206,150),(1196,2452,202,141),(1932,2467,191,142)]
k=2.25
# Sommet enneigé relevé à la main (cases de 20 unités depuis le coin bx-10, by-110) : arête gauche, pointe, arête droite.
caps=[((2.7,4.0),(5.6,1.0),(7.8,1.9)),((2.2,4.2),(4.9,1.9),(6.9,2.9)),((1.9,4.3),(4.6,1.9),(6.7,2.8)),((1.7,4.4),(4.4,1.9),(6.3,2.8)),
 ((2.3,4.0),(5.2,1.6),(7.3,2.6)),((1.4,4.4),(4.4,1.9),(6.3,3.0)),((1.7,3.9),(4.6,1.3),(6.9,2.6)),((1.9,3.9),(4.6,1.5),(6.7,2.6)),
 ((2.4,3.9),(5.2,1.1),(7.6,2.3)),((1.9,4.1),(5.0,1.4),(7.2,2.7)),((2.0,3.9),(4.9,1.5),(7.3,2.6)),((2.2,3.7),(5.0,1.3),(7.2,2.5)),
 ((2.2,3.9),(4.7,1.6),(6.9,2.9))]
elements=[]; tiles=[]
for n,(bx,by,bw,bh) in enumerate(rocks):
    x0,y0,x1,y1=bx-40,by-140,bx+bw+40,by+bh+10
    box=(int(x0*k),int(y0*k),int(x1*k),int(y1*k))
    img=np.array(full.crop(box).convert('RGB')).astype(float)
    hsv=np.array(full.crop(box).convert('HSV')).astype(float)
    sat=hsv[:,:,1]; val=hsv[:,:,2]
    h,w=sat.shape
    # sol : couronne du bord de la fenêtre
    ring=np.zeros((h,w),bool); b=int(18*k); ring[:b]=True; ring[:, :b]=True; ring[:, -b:]=True
    gs=sat[ring]; gv=val[ring]
    # roche : nettement plus saturée (flancs bleus) ou nettement plus claire et moins saturée (dessus enneigé)
    side=sat>max(np.percentile(gs,99)+12,188)
    top=(val>np.percentile(gv,97)) & (sat<np.percentile(gs,35))
    side=ndimage.binary_opening(side,iterations=2)
    lab,_=ndimage.label(side)
    own=np.zeros_like(col); own[by:by+bh,bx:bx+bw]=col[by:by+bh,bx:bx+bw]
    cm=np.array(Image.fromarray(own[y0:y1,x0:x1]).resize((w,h),Image.NEAREST))
    ids=np.unique(lab[cm & side]); ids=ids[ids>0]
    body=np.isin(lab,ids)
    body=ndimage.binary_closing(body,iterations=6)
    body=ndimage.binary_fill_holes(body)
    (tl,pk,rv)=caps[n]
    def loc(c,dx=0,dy=0): return (((bx-10+c[0]*20+dx)-x0)*k, ((by-110+c[1]*20+dy)-y0)*k)
    capimg=Image.new('L',(w,h),0)
    ImageDraw.Draw(capimg).polygon([loc(tl,-3,0),loc(pk,0,-3),loc(rv,3,-2),loc(rv,8,45),loc(tl,-2,35)],fill=255)
    whole=body|(np.array(capimg)>0)
    whole=ndimage.binary_closing(whole,iterations=8)
    whole=ndimage.binary_fill_holes(whole)
    # contour : enveloppe par colonnes (haut) et par lignes, simplifiée en polygone
    ys,xs=np.where(whole)
    pts=[]
    step=max(int(10*k),1)
    colsx=list(range(xs.min(),xs.max()+1,step))
    upper=[(x,int(np.where(whole[:,x])[0].min())) for x in colsx if whole[:,x].any()]
    lower=[(x,int(np.where(whole[:,x])[0].max())) for x in colsx if whole[:,x].any()]
    poly=upper+lower[::-1]
    foot_y=int(min((by+bh)*k, box[1]+max(p[1] for p in lower)))
    elements.append({"id":"rock_%02d"%(n+1),"category":"rock","mode":"exact",
        "outline":[[box[0]+int(x),box[1]+int(y)] for x,y in poly],
        "foot":[[int(bx*k),int((by+bh)*k)],[int((bx+bw)*k),int((by+bh)*k)]]})
    c=full.crop(box).convert('RGB'); d=ImageDraw.Draw(c)
    d.line(poly+[poly[0]],fill=(255,0,0),width=3)
    d.line((0,(by+bh-y0)*k,w,(by+bh-y0)*k),fill=(255,255,0),width=2)
    tiles.append(c.resize((w//3,h//3)))
json.dump({"environment":"environment.glacier_entry","elements":elements},open('assets/concepts/incoming/map.glacier_entry/occlusion/outlines.json','w'),indent=1)
for s in range(0,13,7):
    part=tiles[s:s+7]; W=sum(t.size[0] for t in part)+6*len(part); H=max(t.size[1] for t in part)
    sh=Image.new('RGB',(W,H),(255,0,255)); x=0
    for t in part: sh.paste(t,(x,0)); x+=t.size[0]+6
    sh.save(S+'/seg_%d.png'%(s//7)); print(sh.size)
