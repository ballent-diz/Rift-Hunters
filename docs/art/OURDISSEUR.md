# L’Ourdisseur, Dévoreur des Linceuls

Ce Dévoreur prolonge la famille des Rapiécés. Deux montants de noyer émergent de son dos.
Les bandes tendues entre ces montants forment une trame ivoire qui se soulève à chaque pas.
Le lin carmin et indigo se déploie lors du passage en phase 2, quand la traverse pivote
et ouvre la silhouette derrière les épaules.

**Le Barrage de chaîne** est la mécanique phare proposée. L'Ourdisseur prépare au bras deux
fils qui s'accrochent à des points du décor. Le joueur prend le passage entre les fils avant leur
mise en tension. En phase 2, **Trame inversée** changerait le sens de fermeture. Les gestes du
boss annoncent l'orientation. Les ancrages, fils et zones dangereuses seront dessinés par le jeu.

| Planche | Clips | Geste |
| --- | --- | --- |
| A, 6 × 3 | `idle`, `move`, `attack` | Repos, marche sur tenons et balayage du bras. |
| B, 6 × 2 | `warp_gate`, `shuttle_reel` | Écarte les bras pour tendre les fils, puis tire la traverse vers lui dans l'autre clip. |
| C, 6 × 3 | `transform`, `phase2_idle`, `phase2_move` | Déploie ses panneaux, puis repose et marche dans sa nouvelle silhouette. |
| D, 6 × 3 | `reverse_weave`, `bobbin_throw`, `death` | Bascule de traverse, jet de canette et effondrement du métier. |

Les quatre planches de production contiennent 66 poses. `boss.loom_devourer` regroupe leurs onze
clips dans un seul atlas, à l'échelle de manifeste 0,5 et avec un maximum de 32 couleurs.
La marche tourne à 9 i/s, le repos à 7 i/s et les actions à 10 i/s. Les sources retenues et les prompts
ImageGen sont classés dans `assets/concepts/incoming/boss.loom_devourer/source/`.

```sh
python3 tools/art/import_ourdisseur.py --preview-dir <dossier>
```

[Comparaison des phases](../previews/ourdisseur/ourdisseur.webp) · [Aperçu animé](../previews/ourdisseur/animations.gif)

Les aperçus du [Sanctuaire en phase 1](../previews/ourdisseur/phase_1.webp) et
de la [phase 2](../previews/ourdisseur/phase_2.webp) utilisent le zoom du mode 2D,
avec le Veilleur et un Écho comme repères. Les clips sont prêts pour le raccordement du
boss et des techniques. Le comportement du Barrage et ses ancrages restent à éprouver en combat.

Cellules de 448 × 304, ancre au sol sur (224, 280) et hauteur cible de 238 pixels.
L’import et le validateur du projet passent dans le banc Godot 4.3. [Contrôles et empreintes](../previews/ourdisseur/controle.json).
