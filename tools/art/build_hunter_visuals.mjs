// Génère les éléments vectoriels C5, leur catalogue et les prompts des icônes du propriétaire.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root = fileURLToPath(new URL('../../', import.meta.url));
const target = path.join(root, 'assets/ui/hunter_tree');
await fs.mkdir(target, {recursive:true});
const colors = {locked:'#5c586c',learnable:'#dfad7a',learned:'#8393b5',active:'#a5ebec'};
const branches = [
 ['blade','Lame','Blade','#edc18d'],['prism','Prisme','Prism','#74dce7'],
 ['abyss','Abîme','Abyss','#b7a7df'],['bond','Lien','Bond','#a5d4b5']
];
const entries = {};
const svg = (w,h,body) => `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>\n`;
async function save(id,w,h,body,extra={}) {
 const name=id.replaceAll('.','_')+'.svg'; await fs.writeFile(path.join(target,name),svg(w,h,body));
 entries['ui.hunter_tree.'+id]={status:'final',kind:'ui_element',sheet:'res://assets/ui/hunter_tree/'+name,
  cell:[w,h],anchor:[w/2,h/2],scale:1,animations:{idle:{row:0,frames:1,fps:1,loop:true}},...extra};
}
const cut=(n,inset=5) => `${inset+10},${inset} ${n-inset-10},${inset} ${n-inset},${inset+10} ${n-inset},${n-inset-10} ${n-inset-10},${n-inset} ${inset+10},${n-inset} ${inset},${n-inset-10} ${inset},${inset+10}`;
for(const [type,size] of [['passive',80],['spell',96],['transform',96],['keystone',128]]) {
 for(const [state,color] of Object.entries(colors)) {
  const diamond=type==='transform'||type==='keystone';
  const shape=diamond?`${size/2},5 ${size-5},${size/2} ${size/2},${size-5} 5,${size/2}`:cut(size);
  let b=`<polygon points="${shape}" fill="#080b18" stroke="#03050e" stroke-width="9"/><polygon points="${shape}" fill="#101325" stroke="${color}" stroke-width="3"/>`;
  if(state==='active') b+=`<polygon points="${diamond?`${size/2},12 ${size-12},${size/2} ${size/2},${size-12} 12,${size/2}`:cut(size,12)}" fill="none" stroke="#f6dfad" stroke-width="2"/>`;
  if(state==='learnable') b+=`<path d="M${size/2-8} 5h16M5 ${size/2-8}v16M${size-5} ${size/2-8}v16M${size/2-8} ${size-5}h16" stroke="#ffe2b5" stroke-width="4"/>`;
  if(state==='locked') b+=`<path d="M${size-25} 20v-5a5 5 0 0 1 10 0v5" fill="none" stroke="#aaa1b6" stroke-width="2"/><rect x="${size-28}" y="20" width="16" height="12" fill="#aaa1b6"/><rect x="${size-21}" y="23" width="3" height="5" fill="#171629"/>`;
  if(state==='learned'||state==='active') b+=`<path d="M12 ${size-22}l5 5 11-12" fill="none" stroke="${color}" stroke-width="3"/>`;
  if(type==='keystone') b+=`<path d="M${size/2-20} 30l6 12 14-18 14 18 6-12v23h-40z" fill="${color}" opacity=".8"/>`;
  await save(`node.${type}.${state}`,size,size,b,{content_rect:diamond?[size*.27,size*.30,size*.46,size*.42]:[20,20,size-40,size-40]});
 }
}
for(const [state,color] of Object.entries(colors)) {
 const dash=state==='locked'?'stroke-dasharray="4 5"':'';
 await save('link.vertical.'+state,16,128,`<path d="M8 2v124" stroke="#080915" stroke-width="7"/><path d="M8 2v124" stroke="${color}" stroke-width="2" ${dash}/>`);
 await save('link.fork.'+state,160,64,`<path d="M80 2v22H20v38M80 24h60v38" fill="none" stroke="${color}" stroke-width="2" ${dash}/><path d="M80 16l7 8-7 8-7-8z" fill="${color}"/>`);
}
await save('choice.exclusive',160,40,'<path d="M12 20h52m32 0h52" stroke="#b58c80" stroke-width="2"/><path d="M80 6l14 14-14 14-14-14z" fill="#121325" stroke="#e0b58b" stroke-width="2"/><path d="M75 15l10 10m0-10l-10 10" stroke="#f0ddc7" stroke-width="2"/>');
for(const state of ['empty','equipped','focus']) {
 const c=state==='empty'?'#514b66':state==='focus'?'#a5ebec':'#ba8c79';
 await save('slot.'+state,256,96,`<path d="M13 5h230l8 8v70l-8 8H13l-8-8V13z" fill="#101323" stroke="${c}" stroke-width="2"/><path d="M22 16h54v64H22z" fill="#080c19" stroke="${c}" stroke-width="1"/><path d="M89 22v52M101 76h131" stroke="${c}" stroke-width="1" opacity=".5"/>`,{content_margins:[16,12,16,12]});
}
for(const state of ['idle','active']) await save('build.'+state,256,56,`<path d="M12 4h232l8 8v32l-8 8H12l-8-8V12z" fill="${state==='active'?'#26323d':'#111324'}" stroke="${state==='active'?'#ead4a3':'#6c5868'}" stroke-width="2"/>`,{patch_margins:[14,14,14,14]});
await save('panel',64,64,'<path d="M12 3h40l9 9v40l-9 9H12l-9-9V12z" fill="#101326" fill-opacity=".96" stroke="#88636c" stroke-width="2"/><path d="M17 8h30M8 17v30M56 17v30M17 56h30" stroke="#c9a287" stroke-width="1" opacity=".5"/>',{patch_margins:[18,18,18,18]});
await save('keycap',48,48,'<path d="M8 3h32l5 5v32l-5 5H8l-5-5V8z" fill="#141a2a" stroke="#bba08c" stroke-width="2"/>');
await save('points',256,72,'<path d="M16 4h224l12 12v40l-12 12H16L4 56V16z" fill="#131a2b" stroke="#d6b58e" stroke-width="2"/><path d="M24 36l10-16 10 16-10 16z" fill="#b9e8eb"/>');
for(const [id,fr,en,c] of branches) await save('heading.'+id,288,56,`<path d="M5 51h278M16 42V14h256v28" fill="#131626" stroke="${c}" stroke-width="1"/><path d="M144 3l7 7-7 7-7-7z" fill="${c}"/>`);
await save('background',1440,840,'<rect x="2" y="2" width="1436" height="836" rx="2" fill="#090e20" fill-opacity=".94"/><path d="M20 80H1420M20 770H1420M360 110V750M720 110V750M1080 110V750" stroke="#77728c" stroke-opacity=".12" stroke-width="1"/><path d="M20 16h1400v808H20z" fill="none" stroke="#9e7c8c" stroke-opacity=".3"/>');
// Le manifeste standard reste compatible : les fonds opaques ne sont pas des feuilles de sprites.
// Le fond transparent découpé garde les quatre coins transparents, comme les autres éléments.
const manifestPath=path.join(root,'assets/asset_manifest.json');
const manifest=JSON.parse(await fs.readFile(manifestPath,'utf8'));
Object.assign(manifest.entries,entries);
await fs.writeFile(manifestPath,JSON.stringify(manifest,null,'\t')+'\n');
const catalog={version:1,source:'docs/design/ARBRE_DU_CHASSEUR.md',backdrop:'res://assets/ui/menus/refuge-backdrop.png',
 reference_size:[1920,1080],states:Object.keys(colors),branches:branches.map(([id,fr,en,color])=>({id,name_fr:fr,name_en:en,color})),
 assets:entries,notes:['Les images ne contiennent aucun texte.','Aucune scène fonctionnelle d’arbre.','Les icônes définitives seront générées par le propriétaire.']};
await fs.writeFile(path.join(target,'catalog.json'),JSON.stringify(catalog,null,2)+'\n');
console.log(Object.keys(entries).length+' éléments graphiques C5 générés.');
