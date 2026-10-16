// Affiches de catalogue et contrats visuels ; les scènes sont les animations réelles.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../../',import.meta.url));
const manifestPath=path.join(root,'assets/asset_manifest.json');
const manifest=JSON.parse(await fs.readFile(manifestPath,'utf8'));
const definitions={
 cleaving_slash:{cell:[384,384],anchor:[192,192],variants:{
  base:{duration_seconds:.34,radius:150,angle_degrees:120,bounds:[-180,-180,360,360]},
  whirlwind:{duration_seconds:.55,radius:150,angle_degrees:360,bounds:[-180,-180,360,360]},
  thrust:{duration_seconds:.40,range:320,width:20,bounds:[0,-40,360,80]}},
  poster:'<path d="M267 62 A150 150 0 0 1 267 322" stroke="#eabe82" stroke-width="13" fill="none"/><path d="M265 68 A144 144 0 0 1 265 316" stroke="#fff0ca" stroke-width="4" fill="none"/>'},
 prismatic_lance:{cell:[768,128],anchor:[24,64],variants:{
  base:{duration_seconds:700/950+.24,range:700,speed:950,half_width:14,bounds:[-20,-70,790,140]},
  fan:{duration_seconds:700/950+.24,range:700,speed:950,rays:3,angles_degrees:[-14,0,14],bounds:[-20,-240,800,480]},
  overcharge:{duration_seconds:700/950+.24,range:700,speed:950,half_width:21,bounds:[-20,-70,790,140]},
  charge:{duration_seconds:null,caller_stops:true,max_radius:27,bounds:[-30,-55,115,110]}},
  poster:'<path d="M24 64H716" stroke="#91edff" stroke-width="4"/><path d="M634 64l60-14 30 14-30 14z" fill="#5ed6ed"/><path d="M634 64h84" stroke="#f1ffff" stroke-width="3"/>'}
};
for(const [id,def] of Object.entries(definitions)){
 const folder='assets/vfx/hunter/'+id;
 const [w,h]=def.cell;
 await fs.writeFile(path.join(root,folder,'preview.svg'),`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${def.poster}</svg>\n`);
 manifest.entries['vfx.hunter.'+id]={status:'wip',kind:'effect_scene',sheet:'res://'+folder+'/preview.svg',
  scene:'res://'+folder+'/'+id+'.tscn',cell:def.cell,anchor:def.anchor,scale:1,
  animations:{idle:{row:0,frames:1,fps:1,loop:false}},variants:def.variants,
  notes:'sheet = affiche statique du catalogue ; scene = animation autonome. Aucun dégât ni collision.'};
}
await fs.writeFile(manifestPath,JSON.stringify(manifest,null,'\t')+'\n');
console.log('2 scènes d’effets enregistrées.');
