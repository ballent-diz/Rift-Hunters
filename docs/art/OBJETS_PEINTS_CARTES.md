# Objets peints posés sur les cartes

Lot livré le 8 novembre 2026, branche `codex/objets-peints-cartes`. Les miroirs et le mannequin adoptent une matière
peinte, une lumière haut-gauche, une ombre courte bas-droite et des repères discrets. Les scènes vectorielles actuelles
restent inchangées : Claude doit raccorder ces feuilles aux mêmes interfaces et aux mêmes règles.

## Livrables et échelle

Chaque variante possède son dossier `assets/concepts/incoming/<identifiant>/`, son `job.json`, ses cellules
normalisées `poses.webp` et une palette de couleurs natives prélevées dans le décor. Les quatre planches générées
retenues et leurs prompts exacts sont dans les sous-dossiers `source/` des quatre objets de base.

| Objet / destination | Identifiant visuel | Hauteur du corps | États |
|---|---|---:|---|
| Portail, paire sarcelle, carte14 | `object.mirror_portal` |100u|`active`, `cooldown`, `enter`, `exit`, `hidden`|
| Portail, paire sauge, carte14 | `object.mirror_portal.sage` |100u|mêmes états|
| Portail, paire or pâle, carte14 | `object.mirror_portal.pale_gold` |100u|mêmes états|
| Portail, paire gris lilas, carte14 | `object.mirror_portal.lilac_grey` |100u|mêmes états|
| Cristal, Jardins de cristal, carte13 | `object.crystal_mirror` |72u|`idle`, `charged`, `burst`, `debris`, `hidden`|
| Cristal, terrasse du Cœur des marais, carte15 | `object.crystal_mirror.marsh_heart` |72u|mêmes états|
| Mannequin d'entraînement | `object.training_dummy` |70u|`idle`, `hit`|

Toutes les cellules font256×256px, avec `scale:0.5` et ancre au pied `(128,232)`. Les ombres dépassent le pied
dans la cellule ; elles ne doivent pas déterminer l'ancrage. Le Chasseur et l'Écho des captures gardent leurs
feuilles, ancres et échelles du manifeste de référence. Les gabarits sont mesurés sur les pixels opaques du corps.

Les aliases `primed → charged` des cristaux et `hurt → hit` du mannequin conservent les appels du rendu d'entité.
`hidden` est une pose transparente. `debris`, accepté par la scène cristal existante même s'il n'est pas demandé
par le directeur habituel, conserve un petit amas peint qui s'éteint. Aucun abri séparé n'est ajouté.

## Choix de matière

- **Portails** : pierre grise érodée, petites mousses olive, vitre d'eau sombre, reflets pâles. Les quatre paires
  partagent exactement la même pierre, la même mousse et la même ombre. Seuls la petite gemme et quelques reflets
  changent de teinte. Les recharges des quatre variantes sont identiques et éteintes. Le cadre est rigoureusement
  fixe pendant les quatre animations ; la vitre seule ondule, se resserre ou se détend. Aucun grand halo.
- **Cristaux des Jardins** : quartz gris-sarcelle strié, poussière plus chaude et mousse discrète, adaptés aux
  pavés ocre de la carte13. **Terrasse** : minéral et pierre plus froids, gris-vert, adaptés aux dalles de la carte15.
  La charge reste interne. La fracture diminue réellement le corps jusqu'à un petit amas ; les deux dernières
  poses du cristal des Jardins reprennent celles de la terrasse, recalées et converties dans sa palette.
- **Mannequin** : bois brun marqué de coups, fer froid usé, pied en croix. La matière provient du refuge ; le pied
  et l'ombre restent fixes pendant la secousse. La salle actuelle n'a pas de carte peinte : sa capture reprend
  exactement son sol provisoire, sans inventer un nouveau décor.

Chaque feuille utilise au plus32 couleurs RGB. `source/palette.json` donne les pixels de prélèvement, les
fichiers de référence et leurs SHA256. Les couleurs de paire suivent celles de `PortalDirector.PAIR_COLORS`, avec
prélèvement du pixel natif le plus proche dans les tuiles de la carte14. La conversion reste limitée aux repères.

Les sources générées contenaient un résidu blanc semi-transparent. Le détourage l'enlève ; l'ombre déjà peinte,
matée sur blanc, retrouve son alpha à partir de sa luminance. Aucune ellipse de remplacement, matière, mosaïque
ou texture procédurale n'est dessinée. Le redimensionnement des sprites utilise le plus proche voisin.

## Raccordement par Claude

1. Dans `assets/vfx/objects/mirror_portal/mirror_portal.tscn` et son script, remplacer le dessin du corps par la
   feuille correspondant à la paire. Conserver `set_state`, `play`, `seek_visual`, `release`, les états et le signal
   `finished(state)`. `tint` choisit une variante ; il ne teinte pas toute la pierre. Retirer pour ces nouveaux
   sprites l'atténuation `VISUAL_MODULATE` du dessin provisoire. Le gabarit100u correspond au `radius34` utilisé
   par `PortalDirector` ; si d'autres rayons sont utilisés, l'échelle visuelle relative est `radius/34`.
2. Conserver les positions, jumeaux, déclenchements, recharge5s et durée de transit0,65s actuels. C'est la minuterie
   existante qui pilote l'état et ses signaux, pas le nombre d'images. Les six poses d'entrée/sortie peuvent être
   parcourues sur `duration` ; la recharge reste affichée tant que le directeur la demande.
3. Dans `mirror_crystal.tscn`, conserver `MirrorCrystalVisual`, `play`, `set_state`, `seek_visual`, `release`,
   `finished` et `animation_finished(animation)`, ainsi que les propriétés publiques existantes. Choisir
   `object.crystal_mirror` pour `crystal_gardens`, sa variante `marsh_heart` pour la carte15. Le gabarit72u
   correspond au rayon30 et à `idle_height72`. Garder le choix de direction, la portée des rayons, les dégâts,
   la charge0,9s et la repousse18s existants. La durée d'éclatement utilisée par le directeur reste0,5s.
4. Les sprites de cristal ne contiennent **aucun rayon, télégraphe ou zone au sol**. Conserver leur rendu séparé,
   notamment les trois rayons de `burst`. Ne pas superposer aux fragments peints un second corps ou les anciens
   débris vectoriels. Le directeur habituel passe de `burst` à `hidden` comme auparavant.
5. Brancher `hit`/`hurt` du mannequin sur la réaction visuelle existante, sans modifier ses PV, son immobilité ou
   les règles d'entraînement. Les objets contiennent leur ombre peinte : éviter de leur ajouter une seconde ombre.
6. Les prochains abris sont peints dans les décors. Les anciennes entrées d'abris et les cartes existantes ne
   changent pas dans ce lot.

Les scènes, `src/`, `data/`, les fonds de carte et les collisions n'ont pas été modifiés. Seules les deux entrées
provisoires `object.training_dummy` et `object.crystal_mirror` deviennent finales ; cinq identifiants sont ajoutés.

## Import et contrôles reproductibles

```bash
python3 tools/art/import_painted_objects.py
python3 tools/art/check_painted_objects.py --reference-root /chemin/vers/la/copie/de/reference
godot --headless --import --path .
godot --path . res://tools/art/preview_painted_objects.tscn -- --assets-root=/chemin/vers/la/copie/de/reference
```

L'import collectif refait le détourage des quatre sources retenues, le calage, les variantes, les débris, les
icônes complètes et les sept jobs. Les jobs normalisés se réimportent aussi individuellement avec
`import_sheet.py`. Deux options de cet importeur sont utilisées : `registered_cells` garde les positions des
cellules déjà normalisées ; `preserve_alpha` conserve aussi les faibles opacités dès la lecture de la source.
Les anciennes valeurs par défaut restent identiques ; le test de régression existant est conforme.

Contrôles finaux : sept variantes validées par `AssetValidator`,14 textures runtime importées par Godot4.3,
audit des palettes/états/ancres/marges et sources conforme, cadre des portails et pied du mannequin fixes,
tests de conservation de l'alpha et de cellules enregistrées conformes, compilation Python et lint GDScript
conformes. Un projet Godot isolé sans autoload ni profil a servi au contrôle ciblé ; aucune partie n'a été jouée.

## Captures

[Rapport de livraison](../previews/objets-peints/controle_livraison.json) ·
[Audit des sprites](../previews/objets-peints/audit_sprites.json).

Onze captures1280×720 sont faites au zoom réel1,3333 avec le Chasseur et un Écho inchangés. Les captures isolées
utilisent un emplacement réel du premier portail de la carte14 et d'un cristal des cartes13/15. Les vues
de comparaison des états et des quatre paires regroupent les objets sur le sol de leur carte pour la revue,
sans prétendre représenter leurs positions de gameplay.

| Objet | Capture peinte | Comparaison / états | Mouvement |
|---|---|---|---|
| Portail carte14 | [peint](../previews/objets-peints/portail_peint_zoom_jeu.png) | [original](../previews/objets-peints/portail_original_zoom_jeu.png), [quatre paires](../previews/objets-peints/portails_quatre_paires_zoom_jeu.png), [états](../previews/objets-peints/portails_etats_zoom_jeu.png) | [GIF](../previews/objets-peints/portails_mouvement.gif) |
| Cristal carte13 | [peint](../previews/objets-peints/cristal_13_peint_zoom_jeu.png) | [original](../previews/objets-peints/cristal_13_original_zoom_jeu.png), [états](../previews/objets-peints/cristal_13_etats_zoom_jeu.png) | [GIF](../previews/objets-peints/cristal_13_mouvement.gif) |
| Cristal carte15 | [peint](../previews/objets-peints/cristal_15_peint_zoom_jeu.png) | [original](../previews/objets-peints/cristal_15_original_zoom_jeu.png), [états](../previews/objets-peints/cristal_15_etats_zoom_jeu.png) | [GIF](../previews/objets-peints/cristal_15_mouvement.gif) |
| Mannequin | [idle et hit](../previews/objets-peints/mannequin_idle_hit_zoom_jeu.png) | sol actuel de la salle | [GIF](../previews/objets-peints/mannequin_mouvement.gif) |

Les quatre GIF feuillettent les six poses à160ms pour inspecter le mouvement ; leurs durées ne constituent pas
les minuteries de gameplay. Les avant/après isolés ont les mêmes positions, personnages, caméra et fond.
Les sources et prompts complets sont conservés dans le dépôt ; les essais et captures intermédiaires restent
hors Git. Aucun rendu vectoriel de remplacement ou grand halo n'est ajouté.
