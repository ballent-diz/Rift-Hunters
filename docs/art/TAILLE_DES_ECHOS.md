# Taille des Échos par rapport au Chasseur (9 novembre 2026)

Retour du propriétaire : certains Échos paraissent immenses à côté du Chasseur. Règle : un Écho ne dépasse pas
**environ 1,3 fois le Chasseur** ; les petits Échos restent tels quels. Seule l'échelle visuelle change (champ `scale`
du manifeste `assets/asset_manifest.json`, repris dans le `job.json` d'import) : hitbox, portée et équilibrage
inchangés.

Mesure (`idle`, pixels opaques, × `scale` du manifeste, unités du monde) : la hauteur seule ne dépassait nulle part
1,21× ; l'effet « immense » venait de la **masse** (Magmander 3,2× plus large que le Chasseur). Le critère retenu est
la taille linéaire apparente = √(surface opaque de l'Écho / surface du Chasseur), plafonnée à 1,30.
Référence : Chasseur 43,6 de haut, 31,9 de large, 779 u² (échelle 0,65).

| Écho | Échelle avant → après | Hauteur avant → après | Largeur avant → après | Taille apparente avant → après |
|---|---|---|---|---|
| Magmander | 0,75 → 0,51 | 48,8 → 33,1 | 102,8 → 69,9 | 1,92 → 1,31 |
| Stormshell | 0,75 → 0,52 | 50,2 → 34,8 | 79,5 → 55,1 | 1,87 → 1,30 |
| Gravishell | 0,75 → 0,55 | 46,5 → 34,1 | 73,5 → 53,9 | 1,77 → 1,29 |
| Cendrelame (Ashblade) | 0,75 → 0,65 | 49,5 → 42,9 | 61,5 → 53,3 | 1,50 → 1,30 |
| Grovestag | 0,75 → 0,70 | 51,8 → 48,3 | 57,8 → 53,9 | 1,40 → 1,30 |
| Sunclaw | 0,75 → 0,74 | 50,2 → 49,6 | 52,5 → 51,8 | 1,31 → 1,29 |
| Mossback | 0,65 (inchangé) | 52,6 | 39,6 | 1,30 |
| Thornweave | 0,65 (inchangé) | 51,4 | 36,4 | 1,15 |
| Moonspore | 0,75 (inchangé) | 46,5 | 45,8 | 1,24 |
| Glimmerwing, Voltwisp, Gloommaw, Mirrorling, Cinderwing, Hollowflame, Glowmoth | inchangés | 38 à 49 | 34 à 47 | 0,98 à 1,18 |

Les évolutions de Cendrelame (feuilles `wip` 64 px) mesurent déjà 0,9 fois le Chasseur. Un nouvel Écho importé
doit respecter le même plafond : mesurer avec la surface opaque de son `idle`, pas seulement la hauteur.
Captures avant/après en jeu : `docs/previews/arbre_plein_ecran/echos_taille_avant_apres.png` (à gauche avant, à droite après ; Magmander, Stormshell, Cendrelame, Gravishell et le Chasseur).
