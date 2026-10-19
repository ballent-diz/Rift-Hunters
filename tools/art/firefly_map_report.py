from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/"assets/concepts/incoming/map.firefly_woods"
OUT=ROOT/"docs/previews/bois-des-lucioles"
survey=json.loads((BASE/"survey.json").read_text(encoding="utf-8"))
size=(1800,1200)
def pts(poly):
 return [(x*size[0]/100,y*size[1]/100) for x,y in poly]
mask=Image.new("L",size,0)
draw=ImageDraw.Draw(mask)
for p in survey["walk_polygons"]: draw.polygon(pts(p),fill=255)
for p in survey["blocked_polygons"]: draw.polygon(pts(p),fill=0)
draw.polygon(pts(survey["ford_polygon"]),fill=255)
# Les fleurs et petits cailloux ne réduisent pas ce relevé de terrain traversable.
fraction=sum(mask.histogram()[128:])/(size[0]*size[1])
report={"survey_walkable_percent":round(100*fraction,2),"method":survey["method"],"precision":"Relevé visuel approximatif, incertitude de quelques points ; ce n'est pas une validation des collisions."}
(OUT/"surface-releve.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
image=Image.open(OUT/"bois-carte-entiere.png").convert("RGBA")
green=Image.new("RGBA",size,(65,225,180,72))
overlay=Image.composite(green,Image.new("RGBA",size),mask)
Image.alpha_composite(image,overlay).convert("RGB").save(OUT/"surface-releve.png")
draw=ImageDraw.Draw(image)
font=ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf",23)
for p in survey["points"]+survey["fireflies"]:
 x,y=pts([p["xy"]])[0]
 color=(245,235,120) if p["id"].startswith("L") else (150,235,255)
 radius=20
 draw.ellipse((x-radius,y-radius,x+radius,y+radius),fill=(8,24,28,240),outline=color,width=3)
 draw.text((x,y),p["id"],font=font,anchor="mm",fill=color)
image.convert("RGB").save(OUT/"bois-plan-annote.png")
print(json.dumps(report,ensure_ascii=False))
