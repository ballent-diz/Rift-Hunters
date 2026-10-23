"""Produit les aperçus et contrôle l'atlas importé du bulbe, sans modifier ses pixels."""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]


def main():
    out = ROOT / 'docs/previews/ember-pod'
    out.mkdir(parents=True, exist_ok=True)
    (out / '.gdignore').write_text('', encoding='utf-8')
    entry = json.loads((ROOT / 'assets/asset_manifest.json').read_text(encoding='utf-8'))['entries']['object.ember_pod']
    sheet = Image.open(ROOT / entry['sheet'].removeprefix('res://')).convert('RGBA')
    cw, ch = entry['cell']
    assert sheet.size == (6*cw, 3*ch)
    board = Image.new('RGB', (1050, 420), '#242932')
    draw = ImageDraw.Draw(board)
    font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 20)
    report = {'dimensions': list(sheet.size), 'cell': entry['cell'], 'anchor': entry['anchor'],
              'scale': entry['scale'], 'animations': {}, 'gameplay_changed': False}
    for index, (name, anim) in enumerate(entry['animations'].items()):
        frames, bounds = [], []
        for column in range(anim['frames']):
            frame = sheet.crop((column*cw, anim['row']*ch, (column+1)*cw, (anim['row']+1)*ch))
            box = frame.getbbox()
            assert box and box[0]>0 and box[1]>0 and box[2]<cw and box[3]<ch, (name, column, box)
            bounds.append(box)
            canvas = Image.new('RGB', (400, 360), '#242932')
            # Quatre pixels d'écran par pixel d'art, ancre fixe dans les GIF.
            visible = frame.crop((64, 138, 192, 256)).resize((512, 472), Image.Resampling.NEAREST)
            canvas.paste(visible, (-56,-135),visible)
            ImageDraw.Draw(canvas).text((15,15), name, font=font, fill='white')
            frames.append(canvas)
        durations = [round(1000/anim['fps'])]*len(frames)
        if name == 'burst':
            durations[-1] = 1500
        frames[0].save(out/(name+'.gif'),save_all=True,append_images=frames[1:],duration=durations,loop=0)
        selected = 5 if name=='burst' else 2
        fr = sheet.crop((selected*cw,anim['row']*ch,(selected+1)*cw,(anim['row']+1)*ch))
        sprite = fr.crop(fr.getbbox())
        sprite = sprite.resize((sprite.width*4,sprite.height*4),Image.Resampling.NEAREST)
        board.paste(sprite,(index*350+175-sprite.width//2,290-sprite.height),sprite)
        draw.text((index*350+35,310), {'idle':'Repos','primed':'Amorcé','burst':'Coque vide'}[name],font=font,fill='white')
        report['animations'][name]={'frames':len(frames),'fps':anim['fps'],'loop':anim['loop'],'bounds':bounds}
        if name=='burst':
            fr.save(out/'coque_vide.png')
    heights = [b[3]-b[1] for b in report['animations']['idle']['bounds']]
    report['idle_height_world'] = sorted(heights)[len(heights)//2] * entry['scale']
    assert 27 <= report['idle_height_world'] <= 30
    board.save(out/'etats.png')
    (out/'controle.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print('18 poses, alpha et marges valides ; hauteur au repos :', report['idle_height_world'], 'unités.')


if __name__ == '__main__':
    main()
