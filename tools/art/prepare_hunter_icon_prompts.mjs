// Noms de la conception validée, données de maquette et recettes d'import sans images inventées.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../../',import.meta.url));
const rows=[]; const nodes={};
function text(id,fr,en){rows.push(['C5_'+id.toUpperCase(),fr,en]);return 'C5_'+id.toUpperCase();}
function node(id,fr,en,type='passive'){nodes[id]={id,label_key:text(id,fr,en),type};return id;}
const spells=[
 ['cleaving_slash','Taille fendante','Cleaving Slash','blade','Un arc unique de katana en ivoire et or fend une mince fissure sombre. La courbe du sabre et sa direction doivent être lisibles.'],
 ['rift_leap','Bond de faille','Rift Leap','blade','Une silhouette de sabreur saute entre deux éclats de faille ; une onde d’impact au point d’arrivée. Silhouette secondaire, trajectoire dominante.'],
 ['parry','Parade','Parry','blade','Une lame inclinée intercepte une pointe ennemie ; une étincelle blanche marque le contact. Forme compacte en V, moment précis de parade.'],
 ['prismatic_lance','Lance prismatique','Prismatic Lance','prism','Une longue pointe de cristal cyan, cœur blanc, traverse deux petits anneaux de Marque ; silhouette très allongée en diagonale.'],
 ['rupture','Rupture','Rupture','prism','Trois petites Marques cyan éclatent depuis leur centre en fragments de cristal. La détonation se lit comme une étoile angulaire courte.'],
 ['refractor_crystal','Cristal réfracteur','Refractor Crystal','prism','Un cristal argent et cyan reçoit un rayon blanc unique qui ressort en trois faisceaux distincts. Lire clairement la division un-vers-trois.'],
 ['singularity','Singularité','Singularity','abyss','Un noyau noir compact cerclé d’ivoire froid attire trois fragments de pierre. Accents lilas discrets, pas de grand halo magenta.'],
 ['rift_wall','Mur de faille','Rift Wall','abyss','Une lame verticale d’énergie ivoire et lilas pâle arrête plusieurs pointes sombres. Mur mince et solide, silhouette rectangulaire brisée.'],
 ['twin_rifts','Failles jumelles','Twin Rifts','abyss','Deux petits portails sombres bordés de blanc sont reliés par un trait de lumière. Portails séparés, connexion immédiatement lisible.'],
 ['pack_call','Appel de meute','Pack Call','bond','Trois silhouettes d’Échos stylisées convergent vers une même pointe claire. Jade, argent et ivoire ; aucune créature violette dominante.'],
 ['rift_aegis','Égide de faille','Rift Aegis','bond','Un bouclier facetté ivoire et jade protège une grande silhouette et trois petites. La forme du bouclier domine, détails minimaux.'],
 ['swap','Permutation','Swap','bond','Une silhouette de Chasseur et une silhouette d’Écho échangent leurs places par deux flèches opposées d’argent et jade.'],
];
const transforms=[
 ['slashing_dash','Ruée tranchante','Slashing Dash','blade','Une courte traînée de ruée ivoire et or traverse une silhouette sombre et se termine en arc coupant.'],
 ['counter_slash','Contre-taille','Counter Slash','blade','Une lame évite de justesse une pointe sombre puis revient en contre-courbe dorée. Deux gestes très simples et une étincelle de timing.'],
 ['propagation','Propagation','Propagation','prism','Une Marque cyan brisée transmet une petite Marque intacte à une autre silhouette, reliées par un arc fin.'],
 ['split_bolt','Trait scindé','Split Bolt','prism','Un trait blanc frappe un losange de Marque cyan et se divise en deux branches nettes. Un-vers-deux, distinct du cristal un-vers-trois.'],
 ['void_wake','Sillage du vide','Void Wake','abyss','Deux traces de pas claires laissent une bande sombre et une petite entrave lilas pâle derrière elles.'],
 ['anchor','Ancre','Anchor','abyss','Des racines sombres retiennent un fragment qui s’effondre en minuscule noyau de Singularité bordé de blanc.'],
 ['close_guard','Garde rapprochée','Close Guard','bond','Un Écho argent et jade bondit devant une silhouette de Chasseur pour intercepter une pointe sombre.'],
 ['fusion','Fusion','Fusion','bond','Trois liens jade et ivoire joignent une lame et une griffe d’Écho ; un même petit sceau clair apparaît sur les deux.'],
];
const keystones=[
 ['blade_master','Maître-lame','Blademaster','blade','Trois lames ivoire et or forment une couronne triangulaire ouverte ; un petit cercle de recharge à leur base. Silhouette majestueuse.'],
 ['living_prism','Prisme vivant','Living Prism','prism','Un cristal cyan central contient un petit noyau blanc vivant ; trois éclats de tir gravitent autour, composition en couronne.'],
 ['void_master','Maître du vide','Void Master','abyss','Un anneau d’entraves et de racines encercle un noyau noir couronné d’ivoire froid. Grand contraste, accents lilas limités.'],
 ['pack_soul','Âme de meute','Soul of the Pack','bond','Trois silhouettes d’Échos forment une couronne autour d’un sceau de Chasseur ivoire et jade ; liens visibles entre les quatre.'],
];
for(const [id,fr,en] of spells) node(id,fr,en,'spell');
for(const [id,fr,en] of transforms) node(id,fr,en,'transform');
for(const [id,fr,en] of keystones) node(id,fr,en,'keystone');
const other=[
 ['vigor','Vigueur','Vigor'],['training','Entraînement','Training'],['ghost_step','Pas fantôme','Ghost Step'],['last_breath','Dernier souffle','Last Breath'],['third_seal','Troisième sceau','Third Seal'],
 ['shattering_dash','Ruée fracturante','Shattering Dash'],['melee_damage','Maîtrise du sabre','Sword Mastery'],['rift_brawler','Cogneur de faille','Rift Brawler'],
 ['rift_shooter','Tireur des Failles','Rift Shooter'],['resonance','Résonance prismatique','Prismatic Resonance'],['pyromancer','Pyromancien','Pyromancer'],['chain_reaction','Détonation en chaîne','Chain Detonation'],
 ['deep_breach','Brèche profonde','Deep Breach'],['gravity','Gravitationniste','Gravitationalist'],['control_duration','Contrôles prolongés','Longer Control'],
 ['strong_bonds','Liens solides','Strong Bonds'],['sharp_techniques','Techniques affûtées','Honed Techniques'],['lone_hunter','Chasseur solitaire','Lone Hunter'],['pack_leader','Chef de meute','Pack Leader'],
 ['whirlwind','Tourbillon','Whirlwind'],['thrust','Estoc','Thrust'],['return','Retour','Return'],['impact','Impact','Impact'],['mirror','Miroir','Mirror'],['pack_guard','Garde de meute','Pack Guard'],
 ['fan','Éventail','Fan'],['overcharge','Surcharge','Overcharge'],['reaction','Réaction','Reaction'],['inferno','Brasier','Blaze'],['double_prism','Prisme double','Double Prism'],['focus','Foyer','Focus'],
 ['horizon','Horizon','Horizon'],['collapse','Effondrement','Collapse'],['chains','Chaînes','Chains'],['burning_wall','Rempart ardent','Burning Rampart'],['loop','Boucle','Loop'],['exile','Exil','Exile'],
 ['rally','Ralliement','Rally'],['feast','Curée','Feast'],['riposte','Riposte','Riposte'],['sharing','Partage','Sharing'],['relay','Relais','Relay'],['sanctuary','Sanctuaire','Sanctuary'],
];
for(const [id,fr,en] of other) node(id,fr,en);
const copy=[
 ['title','L’ARBRE DU CHASSEUR','THE HUNTER TREE'],['refuge','LE REFUGE · ARSENAL DES FAILLES','THE REFUGE · RIFT ARSENAL'],
 ['points','POINTS DE CHASSEUR','HUNTER POINTS'],['shards','Éclats','Shards'],['build_1','Lame de faille','Rift Blade'],['build_2','Prisme errant','Wandering Prism'],['build_3','Pacte de meute','Pack Pact'],
 ['common','TRONC COMMUN','COMMON TRUNK'],['blade','LAME','BLADE'],['prism','PRISME','PRISM'],['abyss','ABÎME','ABYSS'],['bond','LIEN','BOND'],
 ['locked','Verrouillé','Locked'],['learnable','Apprenable','Learnable'],['learned','Appris','Learned'],['active','Activé dans le build','Active in build'],
 ['equipped','SORTS ÉQUIPÉS','EQUIPPED SPELLS'],['variants','VARIANTES EXCLUSIVES','EXCLUSIVE VARIANTS'],['one_variant','Une seule variante par sort','One variant per spell'],
 ['one_keystone','Une seule clé de voûte active','Only one active keystone'],['known','Connu dès le départ','Known from the start'],['activate_cost','Activation : 2 points','Activation: 2 points'],
 ['variant_cost','Variante : 1 point','Variant: 1 point'],['keystone_cost','Clé de voûte : 4 points','Keystone: 4 points'],['learn_cost','Apprendre : 150 Éclats','Learn: 150 Shards'],
 ['known_forever','Appris pour toujours','Permanently learned'],['learn','Apprendre','Learn'],['activate','Activer dans le build','Activate in build'],['remove','Retirer du build','Remove from build'],
 ['chapter_1','Après le chapitre 1','After Chapter 1'],['chapter_2','Après le chapitre 2','After Chapter 2'],['free_change','Modification gratuite au refuge','Free changes at the Refuge'],
 ['select_node','TAILLE FENDANTE','CLEAVING SLASH'],['slash_desc','Arc de lame : portée 150 · recharge 4 s','Blade arc: range 150 · cooldown 4 s'],
 ['whirlwind_desc','Cercle complet autour du Chasseur.','A full circle around the Hunter.'],['thrust_desc','Ligne étroite et perçante : portée 320.','A narrow piercing line: range 320.'],
 ['trunk_note','Apprendre avec les Éclats · activer avec les points','Learn with Shards · activate with points'],['states_title','ÉTATS ET CHOIX DU BUILD','BUILD STATES AND CHOICES'],
 ['focus_title','VOIE DE LA LAME','PATH OF THE BLADE'],['states_note','Les états restent identifiables par leur forme.','States remain identifiable by shape.'],
 ['exclusive_ab','A ou B','A or B'],['prototype_note','Maquette de composition · icônes définitives à illustrer','Layout mockup · final icons to be illustrated'],
 ['vfx_title','EFFETS DU CHASSEUR · PREMIER LOT','HUNTER EFFECTS · FIRST DELIVERY'],['vfx_note','Effets autonomes · aucune logique de combat','Standalone effects · no combat logic'],
 ['base','Base','Base'],['charge','Charge','Charge'],['release','Libération','Release'],['radius_150','Portée 150','Range 150'],['range_320','Portée 320','Range 320'],['range_700','Portée 700 · vitesse 950','Range 700 · speed 950'],
];
for(const a of copy) text(...a);
const paths=[
 {id:'blade',rows:[['shattering_dash','melee_damage','rift_brawler'],['cleaving_slash','slashing_dash'],['whirlwind','thrust','rift_leap'],['return','impact','parry','counter_slash'],['mirror','pack_guard','blade_master']]},
 {id:'prism',rows:[['rift_shooter','resonance','pyromancer','chain_reaction'],['prismatic_lance','propagation'],['fan','overcharge','rupture'],['reaction','inferno','refractor_crystal','split_bolt'],['double_prism','focus','living_prism']]},
 {id:'abyss',rows:[['deep_breach','gravity','control_duration'],['singularity','void_wake'],['horizon','collapse','rift_wall'],['chains','burning_wall','twin_rifts','anchor'],['loop','exile','void_master']]},
 {id:'bond',rows:[['strong_bonds','sharp_techniques','lone_hunter','pack_leader'],['pack_call','close_guard'],['rally','feast','rift_aegis'],['riposte','sharing','swap','fusion'],['relay','sanctuary','pack_soul']]},
];
const active=['vigor','training','cleaving_slash','slashing_dash','whirlwind','rift_leap','blade_master','prismatic_lance','rupture','propagation','resonance'];
const learned=['ghost_step','last_breath','parry','return','impact','thrust','mirror','pack_guard','fan','overcharge','living_prism','void_master','pack_soul','pack_call'];
const state=id=>active.includes(id)?'active':learned.includes(id)?'learned':(['twin_rifts','swap','loop','exile','relay','sanctuary','anchor','fusion'].includes(id)?'locked':'learnable');
for(const n of Object.values(nodes)) n.state=state(n.id);
await fs.writeFile(path.join(root,'assets/ui/hunter_tree/mockup_data.json'),JSON.stringify({nodes,paths,trunk:['vigor','training','ghost_step','last_breath','third_seal'],build_points:[20,20],slots:['cleaving_slash','prismatic_lance','rift_leap','rupture']},null,2)+'\n');
const promptRoot=path.join(root,'assets/concepts/incoming/ui.hunter_tree_icons');await fs.mkdir(promptRoot,{recursive:true});
const prefix='Icône pour Rift Hunters, dark fantasy de samouraï des Failles. Pixel art net pensé pour une cellule de 64 × 64 : contours francs, silhouette lisible à 48 × 48, masse principale centrée dans 50 × 50, marge transparente. Une seule icône isolée, aucun cadre, aucun texte, aucune lettre, aucun chiffre, aucune interface, aucune ombre portée au sol. Fond réellement transparent. Palette de 24 à 32 couleurs, rampes de 7 tons, ombres bleu-violet, contour sélectif #0e0a17 côté ombre et fin liseré #b56cf0 en bas à droite. Lumière principale en haut à gauche ; accents lumineux limités à 1–2 pixels à l’échelle 64. Pas de flou, pas d’anticrénelage doux, pas de dégradé lisse. Le blanc et le cyan restent la signature alliée ; éviter un halo magenta de danger. ';
const prompts=[];
for(const [type,list] of [['spell',spells],['transform',transforms],['keystone',keystones]])for(const [id,fr,en,branch,subject] of list){
 const visual='icon.hunter.'+id; const dir=path.join(root,'assets/concepts/incoming',visual);await fs.mkdir(path.join(dir,'source'),{recursive:true});
 const hasSource=await fs.access(path.join(dir,'source/icon.png')).then(()=>true,()=>false);
 const job={visual_id:visual,cell:[512,512],anchor:[256,256],scale:1,target_height:400,status:'final',background:'alpha',colors:0,outline:false,resample:'lanczos',preserve_alpha:true,icon_size:512,preview_zoom:1,anchor_mode:'mass',animations:[{name:'idle',source:'source/icon.png',frames:1,fps:1,loop:true,layout:'row'}]};
 const existingJob=await fs.readFile(path.join(dir,'job.json'),'utf8').then(JSON.parse).catch(()=>({}));
 Object.assign(job,existingJob);
 await fs.writeFile(path.join(dir,'job.json'),JSON.stringify(job,null,2)+'\n');
 prompts.push({id,visual_id:visual,name_fr:fr,name_en:en,type,branch,prompt:prefix+subject,source:'assets/concepts/incoming/'+visual+'/source/icon.png',job:'assets/concepts/incoming/'+visual+'/job.json',state:hasSource?'source_ready':'awaiting_source'});
}
await fs.writeFile(path.join(promptRoot,'prompts.json'),JSON.stringify({reference:'docs/ART_BIBLE.md',generator:'Codex (imagegen), autorisé par le propriétaire le 16 octobre 2026',icons:prompts},null,2)+'\n');
let md='# Prompts des icônes du Chasseur — C5\n\n24 icônes : 12 sorts, 8 transformants, 4 clés de voûte. Génération confiée à Codex par le propriétaire le 16 octobre 2026. Les originaux restent dans les dossiers source/ et les sorties passent par le pipeline commun. Joindre la Bible graphique et une icône du jeu comme références de style. Les variantes A/B réutilisent l’icône du sort avec un badge de variante.\n\n';
for(const p of prompts)md+=`## ${p.name_fr}\n\n${p.prompt}\n\nFichier attendu : \`${p.source}\`\n\nImport : \`python tools/art/import_sheet.py ${p.job}\`\n\n`;
await fs.writeFile(path.join(promptRoot,'PROMPTS.md'),md.trimEnd()+'\n');
let csv=await fs.readFile(path.join(root,'i18n/strings.csv'),'utf8');
csv=csv.replaceAll('\r\n','\n').split('\n').filter(l=>!l.startsWith('C5_')&&!l.startsWith('"C5_')).join('\n').trimEnd()+'\n';
const quote=s=>'"'+String(s).replaceAll('"','""')+'"';
csv+=rows.map(row=>row.map(quote).join(',')).join('\n')+'\n';
await fs.writeFile(path.join(root,'i18n/strings.csv'),csv);
console.log(`${prompts.length} prompts et recettes ; ${rows.length} textes FR/EN de maquette.`);
