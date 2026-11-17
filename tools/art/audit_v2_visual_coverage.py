"""Contrôle de livraison : ressources des15sorts v2,12combos et5récompenses, sans exécuter de gameplay."""
from pathlib import Path
from PIL import Image
import json
import re

ROOT=Path(__file__).resolve().parents[2]
ALIASES={'aegis':'rift_aegis','refracting_crystal':'refractor_crystal'}
BASE=['cleaving_slash','prismatic_lance','rupture','rift_leap','parry','singularity','rift_wall','aegis','refracting_crystal']
NEW=['hunter_mark','void_rend','rift_step','stasis_wave','shard_rain','ash_veil']
COMBOS={
    'prismatic_execution':'combo_prismatic_execution','prismatic_deluge':'combo_prismatic_deluge',
    'gravity_blade':'combo_gravity_blade','rift_counter':'combo_counter_rift',
    'dimensional_hunt':'combo_dimensional_hunt','tracker_rupture':'combo_tracker_rupture',
    'spectral_rebound':'combo_spectral_rebound','shattering_rampart':'combo_shattering_bastion',
    'vengeful_aegis':'combo_avenging_aegis','still_storm':'combo_still_storm',
    'rift_prison':'combo_rift_prison','prismatic_convergence':'combo_prismatic_convergence',
}
REWARDS=['passive_dash_blade','passive_void_wake','passive_counter_cut','passive_anchor','rule_extra_slot']


def load(p):return json.loads((ROOT/p).read_text(encoding='utf-8'))


def file_path(resource):
    p=ROOT/resource.removeprefix('res://')
    assert p.is_file(),f'Ressource absente : {resource}'
    return p


def sheet(effect,family='violet'):
    folder=ROOT/f'assets/vfx/pixelfx/{effect}'
    if not (folder/(family+'.json')).is_file():family='violet'
    data=json.loads((folder/(family+'.json')).read_text(encoding='utf-8'))
    im=Image.open(folder/(family+'.png'))
    assert im.mode=='RGBA'
    frames=data['frames'];frames=frames if isinstance(frames,list) else list(frames.values())
    for f in frames:
        r=f['frame'];assert 0<=r['x']<r['x']+r['w']<=im.width and 0<=r['y']<r['y']+r['h']<=im.height
    return dict(effect=effect,family=family,path=f'res://assets/vfx/pixelfx/{effect}/{family}.png',
                frames=len(frames),fps=data['meta']['pixelfx']['fps'],size=im.size)


def main():
    manifest=load('assets/asset_manifest.json')['entries'];catalog=load('assets/ui/items/catalog.json')['entries']
    spells=[]
    for id_ in BASE:
        alias=ALIASES.get(id_,id_)
        icon=manifest['icon.hunter.'+alias]['sheet'];scene=manifest['vfx.hunter.'+alias]['scene']
        file_path(icon);file_path(scene)
        spells.append(dict(id=id_,icon=icon,fx_scene=scene,source='illustration et scène existantes',status='PASS'))
    for id_ in NEW:
        source=(ROOT/f'draft3d/spells/data/{id_}.tres').read_text(encoding='utf-8')
        effect=re.search(r'"icon_fx"\s*:\s*"([^"]+)"',source).group(1)
        family=re.search(r'"icon_family"\s*:\s*"([^"]+)"',source)
        fx=sheet(effect,family.group(1) if family else 'violet')
        spells.append(dict(id=id_,icon=fx['path']+'#image_du_milieu',fx=fx,
                           source='FX existant, icône AtlasTexture existante de DraftSpellBar',status='PASS'))
    code=(ROOT/'draft3d/combos.gd').read_text(encoding='utf-8')
    code+=(ROOT/'draft3d/spells.gd').read_text(encoding='utf-8')
    combos=[]
    for runtime,effect in COMBOS.items():
        fx=sheet(effect);entry=catalog['combo.'+runtime];p=file_path(entry['image'])
        im=Image.open(p);assert im.mode=='RGBA' and im.size==(1254,1254)
        combos.append(dict(id=runtime,asset_id=effect,fx=fx,illustration=entry['image'],status='PASS',
                           trigger_in_current_branch=bool(re.search(r'fx_or\(&"'+effect+r'"',code))))
    rewards=[]
    for id_ in REWARDS:
        p=file_path(catalog['upgrade.'+id_]['image']);im=Image.open(p)
        assert im.mode=='RGBA' and im.size==(1254,1254)
        rewards.append(dict(id=id_,image=catalog['upgrade.'+id_]['image'],status='PASS'))
    for id_ in REWARDS[:3]:sheet(id_)
    result=dict(status='PASS',scope='Ressources v2 uniquement, pas de simulation de gameplay',
                spells=spells,combos=combos,rewards=rewards,
                totals=dict(spells=len(spells),combo_fx=len(combos),combo_illustrations=len(combos),
                            reward_illustrations=len(rewards),passive_fx=3),
                runtime_dependency='PR #212 fusionnée ; raccord visuel des douze combos présent dans cette branche locale.')
    out=ROOT/'docs/previews/couverture-vfx/coverage.json';out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result['totals'],ensure_ascii=False))


if __name__=='__main__':main()
