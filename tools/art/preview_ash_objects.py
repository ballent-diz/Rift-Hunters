"""Aperçus des nids et œufs importés, sans retouche des pixels."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]


def main():
    out=ROOT/'docs/previews/ash-nest-egg';out.mkdir(parents=True,exist_ok=True)
    (out/'.gdignore').write_text('',encoding='utf-8')
    manifest=json.loads((ROOT/'assets/asset_manifest.json').read_text(encoding='utf-8'))['entries']
    report={};board=Image.new('RGB',(1200,800),'#242932');draw=ImageDraw.Draw(board)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
    labels={'idle':'Repos','spawn':'Émission','death':'Cendres','hatch':'Coque vide'}
    for index,identifier in enumerate(['ash_nest','ash_egg']):
        entry=manifest['object.'+identifier]
        sheet=Image.open(ROOT/entry['sheet'].removeprefix('res://')).convert('RGBA')
        cw,ch=entry['cell'];assert sheet.size==(cw*6,ch*(3 if index==0 else 2))
        controls={}
        for column_index,(name,anim) in enumerate(entry['animations'].items()):
            frames=[];bounds=[];zoom=3 if index==0 else 4
            width,height=(800,560) if index==0 else (400,360)
            baseline=470 if index==0 else 285
            for c in range(6):
                fr=sheet.crop((c*cw,anim['row']*ch,(c+1)*cw,(anim['row']+1)*ch));box=fr.getbbox()
                assert box and min(box[:2])>0 and box[2]<cw and box[3]<ch,(identifier,name,c,box)
                bounds.append(box)
                canvas=Image.new('RGB',(width,height),'#242932')
                sprite=fr.resize((cw*zoom,ch*zoom),Image.Resampling.NEAREST)
                canvas.paste(sprite,(width//2-entry['anchor'][0]*zoom,baseline-entry['anchor'][1]*zoom),sprite)
                ImageDraw.Draw(canvas).text((15,15),identifier+' / '+name,font=font,fill='white')
                frames.append(canvas)
            duration=[round(1000/anim['fps'])]*6
            if name in ['death','hatch']:duration[-1]=1500
            frames[0].save(out/(identifier+'_'+name+'.gif'),save_all=True,append_images=frames[1:],duration=duration,loop=0)
            frame_index=5 if name in ['death','hatch'] else 3
            fr=sheet.crop((frame_index*cw,anim['row']*ch,(frame_index+1)*cw,(anim['row']+1)*ch))
            sprite=fr.crop(fr.getbbox());sprite=sprite.resize((sprite.width*(2+index),sprite.height*(2+index)),Image.Resampling.NEAREST)
            x=column_index*400+200;y=index*400+300
            board.paste(sprite,(x-sprite.width//2,y-sprite.height),sprite)
            draw.text((column_index*400+25,y+20),identifier+' : '+labels[name],font=font,fill='white')
            if name in ['death','hatch']:fr.save(out/(identifier+'_dernier_etat.png'))
            controls[name]={'frames':6,'fps':anim['fps'],'loop':anim['loop'],'bounds':bounds}
        idle=controls['idle']['bounds']
        size=sorted((b[2]-b[0]) if index==0 else (b[3]-b[1]) for b in idle)[3]*entry['scale']
        assert (88<=size<=95) if index==0 else (21<=size<=24),size
        report[identifier]={'animations':controls,'idle_size_world':size,'dimension_checked':'width' if index==0 else 'height'}
    board.save(out/'etats.png')
    (out/'controle.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('30 poses contrôlées ; dimensions monde :', {key:v['idle_size_world'] for key,v in report.items()})


if __name__=='__main__':main()
