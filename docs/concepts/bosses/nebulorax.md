# Fiche concept — Nébulorax, le Dévoreur de dimensions

Source : planche concept fournie par le propriétaire du projet (12/10/2026). L'image n'est pas
encore versionnée : la déposer dans `assets/concepts/bosses/nebulorax/nebulorax_concept.png`.

## Identité
Entité colossale née des failles entre les mondes. Nébulorax absorbe l'énergie de tout ce qui
l'entoure et se nourrit des âmes et des souvenirs des créatures qu'il croise.

## Silhouette et lecture
- Masse spiralée d'écailles d'obsidienne en lames, ailes/tentacules de nébuleuse.
- **Cœur de l'ombre** : œil-vortex violet lumineux au centre = point faible (weak spot).
- **Cristaux de faille** : éclats violets flottants, utilisés comme dégâts/obstacles.
- Échelle : ~4 cases de haut par rapport au Chasseur (vue de dessus : ~4× la taille du joueur).
- Vue de dessus : spirale d'écailles autour du cœur, le cœur doit rester visible.

## Palette
| Rôle | Couleur |
|---|---|
| Ombre / fond | `#1B1E33` |
| Violet profond | `#3A1670` |
| Violet | `#6A1FD0` |
| Magenta lumineux | `#C040F0` |
| Lavande (éclats, lumière) | `#EBD6FA` |

## Statistiques de référence (fiche) → valeurs de jeu
| Fiche | Jeu (data/bosses/nebulorax.tres) |
|---|---|
| PV 5000 | 5000 × multiplicateurs de Tension |
| Dégâts 80 | ramenés à l'échelle du Chasseur (100 PV) : 18–30 par attaque |
| Défense 30 | 30 (formule ×100/(100+déf)) |
| Vitesse 40 | 40 px/s (phase 2 : 60) |
| Portée grande | attaques à distance + rayon |

## Rôle / comportement → mécaniques implémentées
| Fiche | Mécanique |
|---|---|
| Boss à plusieurs phases | Phase 2 à 50 % PV (60 % en Tension 3), transformation invulnérable 2 s |
| Absorbe les projectiles | *Absorption* : sphère qui avale les projectiles alliés, puis salve de retour |
| Invoque des créatures | *Invocation* : portails télégraphiés → Grouillards + Cracheur |
| Déplace l'arène | *Cristaux de faille* (phase 2) : obstacles destructibles qui pulsent |
| Vulnérable au cœur | *Cœur exposé* après l'Absorption : dégâts subis ×2 pendant 3 s |
| Vague d'ombres | Anneau en expansion avec brèches sûres |
| Phase 2 – Rayon du vide | Laser télégraphié (verrouillage 1 s) |

## Animations attendues (spritesheet)
| Animation | Frames | Clé manifeste |
|---|---|---|
| Idle | 6 | `idle` |
| Déplacement | 8 | `move` |
| Attaque principale | 6 | `attack` |
| Vague d'ombres | 8 | `shadow_wave` |
| Invocation | 8 | `summon` |
| Transformation phase 2 | 12 | `transform` |
| Attaques phase 2 | 8 | `phase2_attack` |
| Mort | 8 | `death` |

## Points d'attention pour la production des sprites
- La planche est un **concept** : les frames présentées n'ont pas une taille de cellule
  constante, et le fond n'est pas transparent. Elles ne doivent pas être découpées telles quelles.
- Produire une spritesheet par animation (ou une feuille unique, une ligne par animation),
  cellule constante (proposition : 256×256), ancre au centre du cœur, fond transparent.
- Garder la silhouette, les proportions et la palette identiques entre les frames.
