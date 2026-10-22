#!/usr/bin/env python3
"""Préserve le grain des régions peintes après la correction locale de netteté.

Usage : python tools/art/preserve_map_texture.py cascade_source sortie.png
Le détail réinjecté provient des régions générées ; amplitude limitée, aucun bruit synthétique.
"""
from pathlib import Path
import sys,numpy as np
from PIL import Image,ImageFilter
Image.MAX_IMAGE_PIXELS=None
repo=Path(__file__).resolve().parents[2];ident=sys.argv[1]
paths=[repo/'assets/environments'/ident/n for n in ['map.webp','map_1.webp','map_2.webp']]
tiles=[Image.open(p).convert('RGB') for p in paths]
size=(sum(t.width for t in tiles),tiles[0].height)
post=Image.new('RGB',size);x=0
for tile in tiles:post.paste(tile,(x,0));x+=tile.width
original=Image.open(repo/f'assets/concepts/incoming/map.{ident}/source/regions_v1/map_detailed.png').convert('RGB').resize(size,Image.Resampling.LANCZOS)
blur=original.filter(ImageFilter.GaussianBlur(2.0))
out=np.asarray(post).astype(np.int16)
detail=np.asarray(original).astype(np.int16)-np.asarray(blur).astype(np.int16)
# Réinjecter uniquement le grain réellement peint, avec une amplitude limitée ; aucun bruit ajouté.
out=np.clip(out+np.clip(detail,-12,12),0,255).astype(np.uint8)
candidate=Path(sys.argv[2])
Image.fromarray(out).save(candidate,compress_level=1)
print(candidate,flush=True)
