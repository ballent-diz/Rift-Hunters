// Fabrique les scènes d'effets et leur contrat ; réutilise les textures C5 déjà présentes.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../../',import.meta.url));
const shared='res://assets/vfx/hunter/spell_vfx.gd';
const brush='res://assets/vfx/hunter/cleaving_slash/textures/blade-ribbon.png';
const definitions=[
 {id:'rift_leap',name_fr:'Bond de faille',range:380,destination:[380,0],variants:{base:.85,return:.85,impact:1.05},
  bounds:[-180,-220,740,440],contract:'Le combat déplace le Chasseur. La scène relie départ et arrivée ; Impact agrandit seulement l’onde visuelle.'},
 {id:'parry',name_fr:'Parade',range:65,destination:[260,0],variants:{base:.70,mirror:.70,pack_guard:.70},
  bounds:[-110,-120,480,240],contract:'Garde visible 0,4 s. trigger_pulse est réservé à une parade confirmée. Garde de meute reçoit les positions réelles des alliés.'},
 {id:'rupture',name_fr:'Rupture',range:220,destination:[220,0],variants:{base:.85,reaction:1.10,inferno:3.65},
  bounds:[-260,-260,520,520],contract:'Réaction reçoit les positions réelles des Marques secondaires ; Brasier ajoute une persistance visuelle de trois secondes.'},
 {id:'refractor_crystal',name_fr:'Cristal réfracteur',range:260,destination:[90,0],active:8,variants:{base:8.65,double_prism:8.65,focus:8.65},
  bounds:[-60,-100,420,200],contract:'trigger_pulse suit une vraie traversée de projectile. Destination = second cristal pour Prisme double, cible pour Foyer.'},
 {id:'singularity',name_fr:'Singularité',range:220,destination:[220,0],variants:{base:3.65,horizon:3.65,collapse:2.15},
  bounds:[-330,-330,660,660],contract:'Rayon visuel proposé 220 ; Horizon ×1,4 ; Effondrement à 1,5 s. Aucune attraction ou collision appliquée.'},
 {id:'rift_wall',name_fr:'Mur de faille',range:260,destination:[260,0],active:4,variants:{base:4.60,chains:4.60,burning_wall:4.60},
  bounds:[-70,-160,140,320],contract:'Direction = normale du mur. Largeur 260. Chaînes reçoit les points réels d’entrave ; trigger_pulse souligne un contact confirmé.'},
 {id:'twin_rifts',name_fr:'Failles jumelles',range:240,destination:[240,0],active:4,variants:{base:4.60,loop:4.60,exile:4.60},
  bounds:[-65,-65,370,130],contract:'Durée active visuelle de référence 4 s, à remplacer par C1. Les portails et transferts réels sont gérés par le combat.'},
 {id:'pack_call',name_fr:'Appel de meute',range:240,destination:[240,0],variants:{base:.90,rally:1.30,feast:.90},
  bounds:[-80,-100,420,200],contract:'Jusqu’à trois positions et palettes d’Échos réels ; aucun sprite de créature inventé. Le combat anime leurs vrais modèles.'},
 {id:'rift_aegis',name_fr:'Égide de faille',range:45,destination:[45,0],active:4,variants:{base:4.50,riposte:4.50,sharing:4.50},
  bounds:[-195,-195,390,390],contract:'Bouclier autour du Chasseur et des alliés fournis. Riposte attend un trigger_pulse confirmé ; aucune protection ou guérison appliquée.'},
 {id:'swap',name_fr:'Permutation',range:240,destination:[240,0],variants:{base:.85,relay:.85,sanctuary:1.35},
  bounds:[-100,-100,440,200],contract:'Deux positions réelles ; échange uniquement illustré. Relais attend le signal du vrai sort de l’Écho. Sanctuaire est un accent visuel.'}
];
const manifestPath=path.join(root,'assets/asset_manifest.json');
const manifest=JSON.parse(await fs.readFile(manifestPath,'utf8'));
for(const d of definitions){
 const folder=path.join(root,'assets/vfx/hunter',d.id);
 await fs.mkdir(folder,{recursive:true});
 const scene='res://assets/vfx/hunter/'+d.id+'/'+d.id+'.tscn';
 const source='[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="'+shared+'" id="1"]\n\n'+
  '[node name="'+d.id+'" type="Node2D"]\ntexture_filter = 1\nscript = ExtResource("1")\n'+
  'effect_kind = &"'+d.id+'"\nspell_range = '+d.range+'.0\ndestination_offset = Vector2('+d.destination.join(', ')+')\n'+
  (d.active!==undefined?'active_duration = '+d.active+'.0\n':'');
 await fs.writeFile(path.join(folder,d.id+'.tscn'),source);
 manifest.entries['vfx.hunter.'+d.id]={status:'wip',kind:'effect_scene',scene,sheet:brush,
  cell:[2172,724],anchor:[1086,362],scale:1,animations:{idle:{row:0,frames:1,fps:1,loop:false}},
  variants:Object.fromEntries(Object.entries(d.variants).map(([name,duration])=>[name,{duration_seconds:duration}])),
  visual_range:d.range,destination_offset:d.destination,bounds:d.bounds,
  bounds_policy:'Enveloppe indicative ; les positions secondaires et la destination peuvent l’étendre.',
  active_duration:d.active??null,contract:d.contract,
  runtime_palette:'res://assets/vfx/hunter/cel_paint.gdshader',
  notes:'sheet = texture de travail réutilisée au rendu, pas une icône ni une planche animée. Charger scene.'};
}
await fs.writeFile(manifestPath,JSON.stringify(manifest,null,'\t')+'\n');
const catalog={version:1,source:'docs/design/ARBRE_DU_CHASSEUR.md',status:'wip',shared_script:shared,
 texture:brush,notes:['Aucune nouvelle image générée pour ce lot.','Aucun src/ modifié.','Les variantes ne changent que la présentation.'],
 effects:definitions};
await fs.writeFile(path.join(root,'assets/vfx/hunter/remaining_catalog.json'),JSON.stringify(catalog,null,2)+'\n');
console.log('10 scènes autonomes, 30 configurations et manifeste enregistrés.');
