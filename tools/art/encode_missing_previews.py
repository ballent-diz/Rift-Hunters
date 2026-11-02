"""Encode les captures 720p retenues ; limite chaque GIF à 3 Mo sans ajouter les frames source au Git."""
import argparse
from pathlib import Path
from PIL import Image

p=argparse.ArgumentParser();p.add_argument('frames');p.add_argument('output');p.add_argument('--stem',default='apercu');args=p.parse_args()
files=sorted(Path(args.frames).glob('*.png'))
assert files, 'Aucune capture de cette exécution'
frames=[Image.open(path).convert('RGB') for path in files]
assert all(i.size==(1280,720) for i in frames)
out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
frames[len(frames)//3].save(out/(args.stem+'.webp'),quality=90,method=6)
path=out/(args.stem+'.gif')
for count in (256,192,128,96,64):
    samples=Image.new('RGB',(320*min(8,len(frames)),180))
    for n in range(min(8,len(frames))):
        samples.paste(frames[n*len(frames)//min(8,len(frames))].resize((320,180)),(n*320,0))
    palette=samples.quantize(colors=count,method=Image.Quantize.MEDIANCUT)
    encoded=[i.quantize(palette=palette,dither=Image.Dither.NONE) for i in frames]
    encoded[0].save(path,save_all=True,append_images=encoded[1:],duration=100,loop=0,disposal=2,optimize=True)
    if path.stat().st_size<=3_000_000:break
else:raise ValueError('GIF encore supérieur à 3 Mo : raccourcir la séquence sans réduire sa résolution')
print(path.name,len(frames),'images,',path.stat().st_size,'octets,',count,'couleurs')
