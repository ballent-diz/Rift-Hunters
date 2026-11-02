# Chapitre 4 — Glacier silencieux : production des sprites (proposition)

**Statut : catalogue de production, non validé artistiquement.** Travail préparatoire sur une branche distincte : aucun sprite ni comportement n'est déclaré livré. Les images n'entrent au manifeste que lorsque les planches, l'import et les contrôles Godot sont conformes.

Références obligatoires : `docs/design/MONSTRES.md`, `docs/ART_BIBLE.md`, `docs/design/CARTES.md`, `assets/concepts/incoming/README.md`. Le chapitre 4 comprend les cartes 16 à 20 : glace glissante, chaleur des braseros, blizzard, banquise fracturée et écho des sorts. Deux familles de 7 ennemis sont proposées, dont 4 normaux et 3 élites chacune, selon la progression des chapitres 2 et 3.

## Famille A — Veilleurs du givre (cartes 16–18)

| Rang | Nom (nom de travail) | Silhouette / palette | Attaque et animation |
|---|---|---|---|
| Normal | **Mordegivre** | Lézard trapu à six pattes, mâchoire cristalline, ventre cobalt, dos blanc et cyan | Morsure en avant ; technique 1 : glissade courte sur glace |
| Normal | **Lancefrimas** | Arthropode fin à deux paires de pattes, longue lance d'ivoire sur le front, plaques bleu acier | Estoc ; technique 1 : percée droite télégraphiée |
| Normal | **Harfang d'éclat** | Rapace volant compact, ailes anguleuses blanc neige et indigo, serres lumineuses | Coup d'aile ; technique 1 : piqué sur position marquée |
| Normal | **Crapaud de givre** | Amphibien bleu pastel, dos en bouclier de glace et gorge turquoise | Projection de givre ; technique 1 : bond laissant une surface glissante |
| Élite | **Bastion du pergélisol** | Colosse bipède d'armure givrée, poings gigantesques, cœur cyan | Écrasement ; techniques : rempart de glace, onde de fissures, charge du bouclier |
| Élite | **Traqueuse de givre** | Félin quadrupède aux longues patins de glace, crinière turquoise et quatre yeux or | Lacération ; techniques : triples charges, clones de neige, chasse sous blizzard |
| Élite | **Sage des braises pâles** | Silhouette flottante de glaçons ivoire autour d'un noyau bleu, silhouette cérémonielle | Trait froid ; techniques : vol de chaleur, avalanche conique, halo gelant |

## Famille B — Échos de l'aurore (cartes 19–20)

| Rang | Nom (nom de travail) | Silhouette / palette | Attaque et animation |
|---|---|---|---|
| Normal | **Miroir polaire** | Scarabée hexagonal rose clair et glace opaline, antennes en arc | Rayon bref ; technique : reflet de projectile |
| Normal | **Fendrebanquise** | Prédateur fuselé turquoise et corail, grandes griffes de patinage | Charge ; technique : rupture du sol derrière lui |
| Normal | **Luciole boréale** | Petite raie aérienne transparente, ailes vert menthe et rose, centre opalin | Éclair ; technique : double rafale |
| Normal | **Épine astrale** | Plante cristalline mobile à quatre racines articulées, corps turquoise et lilas | Épine ; technique : gerbe circulaire de pointes |
| Élite | **Reine du halo** | Insecte royal ailé, thorax doré, ailes opalescentes en rayons, corps magenta discret | Fouet d'aile ; techniques : couronne tournante, miroir de sort, chute en piqué |
| Élite | **Arpenteur des failles froides** | Géant quadrupède aux jambes longues, masque ivoire, fissures bleues et or | Balayage ; techniques : téléportation glaciale, marquage différé, brisure de terrain |
| Élite | **Oracle des neiges** | Gardien flottant, anneaux de cristal en orbite, noyau cyan et lilas | Projectile ; techniques : écho d'un sort, pluie d'aiguilles, mur de prismes |

## Production et animation

- Planche de référence isolée : 3/4 légèrement plongé, regard vers la droite, fond **#00FF00** plat, silhouette lisible en jeu ; référence indépendante de toute autre licence.
- À partir du chapitre 4, **deux techniques peintes par normal** et **trois techniques par élite**, si et seulement si elles sont reliées à des comportements définis. La table ci-dessus décrit un premier noyau : la seconde technique de chaque normal doit être décidée en données avant génération.
- Les planches A : **6 colonnes × 2 rangées** pour les normaux (move, attack), et **6 colonnes × 3 rangées** pour les élites (move, attack, death).
- Techniques supplémentaires : planches B et C d'au plus trois rangées, six poses par animation, anticipation → frappe → récupération.
- Couleurs : cyan, glacier, bleu nuit, menthe, ivoire, lilas et touches corail/ambre. Aucune répétition de la silhouette des Enlisés ou des Reflets du chapitre 3.
- Fond source vert uniformément #00FF00 ; après détourage et import, fond transparent, aucun halo hors cellule, aucune ombre au sol ; éclairage haut-gauche et filet violet bas-droite discret.
- Le pipeline doit préserver la taille, l'ancre et le cadre de chaque frame, et préparer les `job.json`, empreintes et contrôles Godot avant statut `final`.

## Jalons avant intégration

1. Valider les noms, les silhouettes et les comportements des quatorze ennemis avec l'identité du Glacier silencieux.
2. Produire une **image de référence** par ennemi, puis les planches A et techniques, une famille à la fois.
3. Générer les fichiers d'import et réaliser un audit des frames, bords, fonds et échelles.
4. Exécuter l'import Godot headless et les contrôles ciblés assets/art ; produire une capture de lisibilité en jeu.
5. Préparer les `EnemyData` et mécaniques avec Claude sur une branche distincte, sans faire apparaître de rangée inactive.

**Important :** ce document est un brief de conception, pas une livraison de sprites. Ne pas le fusionner comme un lot artistique achevé.
