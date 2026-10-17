# Équilibrage

## Où sont les réglages
| Fichier | Contenu |
|---|---|
| `data/balance/balance_config.tres` | Chasseur, arme, XP, croissance des ennemis, élites, récompenses, capture, boss (plafond d'ennemis, enragement), zoom |
| `data/arenas/*.tres` | Durée avant le boss, vagues (ennemis, poids, débit, densité max), événements, élites, obstacles, règle d'arène |
| `data/difficulties/normal.tres`, `nightmare.tres` | Multiplicateurs du Normal et du Cauchemar, affixes d'élite, seuil de phase 2 du boss, récompenses |
| `data/modifiers/*.tres` | Pactes de risque (multiplicateurs + bonus de récompenses) |
| `data/monsters`, `enemies`, `bosses`, `upgrades`, `relics` | Valeurs de chaque entité |

Aucune valeur d'équilibrage n'est codée en dur dans le combat.

## Méthode : simulations par bot
Le bot (`AutopilotBrain`) esquive les ennemis, les projectiles, les charges, les zones et les obstacles,
utilise la Ruée et les Techniques, ordonne le focus sur le boss et choisit ses cartes au hasard.
Il joue **moins bien** qu'un humain : ses taux de victoire sont un plancher.

```bash
tools/balance_sim.sh "mossback ashblade" "fractured_plain three_rifts" "normal nightmare" 3
META=veteran tools/balance_sim.sh ...   # bonus d'arbre typiques après ~10 parties (expert : ~30 parties)
JOBS=4 ...                               # parties en parallèle
```
Chaque ligne donne : victoire, durée, niveau, éliminations, durée du combat de boss, PV restants
du boss, dégâts subis et nombre d'erreurs de script (doit rester à 0).

## Résultats de référence (12/10/2026, 1 à 2 graines par configuration)
| Contenu | Profil | Victoires du bot |
|---|---|---|
| Plaine fracturée, Tension 0 | sans arbre | 5/7 Échos de départ (≈ 50-70 %) |
| Plaine fracturée, Tension I-II | vétéran | 6/8 |
| Plaine fracturée, Tension I-II | sans arbre | 1/8 (attendu : ces niveaux se débloquent après progression) |

Repères observés : niveau 25-35 à la fin d'une partie gagnée, combat de boss de 30 s à 2 min,
200 à 400 dégâts encaissés par partie.

## Garde-fous
- Combat de boss : 90 ennemis au maximum (vagues, invocations et Nuées-mères comprises).
- Enragement du Dévoreur après 3 minutes de combat (dégâts ×1,6, vitesse ×1,4) : une partie se termine toujours.
- Plafond global : 450 ennemis ; test de charge : < 10 ms de simulation par frame avec ~370 ennemis et 100 projectiles.

## Pistes pour la suite
- Lucivelle, Mirelle et Fulgurine sont plus faibles comme Écho de départ que comme recrue : à surveiller en tests humains.
- Tensions III à V : non simulées en profondeur (nécessitent le profil expert).
