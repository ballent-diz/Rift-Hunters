#!/usr/bin/env python3
"""Prépare les bases du sceau et les aperçus depuis le rendu Godot, sans modifier le gameplay."""
from pathlib import Path
import argparse,hashlib,json,shutil
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'assets/concepts/incoming/object.altar_seal/source'
def main():
 parser=argparse.ArgumentParser()
 parser.add_argument('--baked-folder',type=Path)
 args=parser.parse_args()
 if args.baked_folder:
  shutil.copyfile(args.baked_folder/'sheet.png',ROOT/'assets/sprites/objects/altar_seal/sheet.png')
  preview=ROOT/'docs/previews/altar-seal'
  for name in ['intact','damaged','sealed','hit','seal_wave']:
   shutil.copyfile(args.baked_folder/(name+'.gif'),preview/(name+'.gif'))
  shutil.copyfile(args.baked_folder/'render-check.json',preview/'render-check.json')
  shutil.copyfile(args.baked_folder/'animations.json',SOURCE/'animations.json')
 bases=[Image.open(SOURCE/'bases'/(n+'.png')).convert('RGBA') for n in ['intact','damaged','sealed']]
 icon=bases[0].resize((64,64),Image.Resampling.LANCZOS)
 icon.save(ROOT/'assets/ui/icons/objects/altar_seal.png')
 board=Image.new('RGB',(960,420),'#18212b');draw=ImageDraw.Draw(board)
 font=ImageFont.truetype(str(ROOT/'assets/fonts/inter/Inter-Variable.ttf'),16)
 for k,(name,im) in enumerate(zip(['Intact','Endommagé','Scellé'],bases)):
  board.paste(im,(32+320*k,30),im)
  tiny=im.resize((128,128),Image.Resampling.LANCZOS)
  board.paste(tiny,(96+320*k,268),tiny)
  draw.text((120+320*k,242),name,fill='white',font=font)
 board.save(ROOT/'docs/previews/altar-seal/trois-etats.png')
 paths=sorted(p for p in SOURCE.rglob('*') if p.is_file() and p.name!='SHA256SUMS.txt')
 (SOURCE/'SHA256SUMS.txt').write_text('\n'.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(SOURCE).as_posix() for p in paths)+'\n',encoding='utf-8')
 print('Sceau : icône et aperçu préparés ; sources tracées.')
if __name__=='__main__':main()
