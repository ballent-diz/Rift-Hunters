# Les Sifflants — 11 techniques à raccorder dans draft3d/

**Design uniquement** : aucune attaque n'est implantée tant que Claude n'a pas raccordé le code et les données du bestiaire. Dégâts et recharges à tester en partie par le propriétaire.

| Porteur | Clip / technique | FX dédié | Mécanique et contre-jeu proposés |
|---|---|---|---|
| gust_engine | `gust_burst` | `enemy_gust_engine_burst` | Souffle en cône annoncé 0,6 s ; recul limité à 1,5 m |
| shale_bastion | `brace_shield` | `enemy_shale_brace` | Garde frontale 2 s ; dos vulnérable |
| shale_bastion | `cleaver_fall` | `enemy_shale_cleaver` | Frappe de hache en bande, préparation 0,8 s |
| wind_cantor | `dirge_tone` | `enemy_wind_dirge` | Une onde circulaire ralentissante ; ralentissement non cumulable |
| wind_cantor | `whistle_snare` | `enemy_wind_snare` | Deux lignes convergentes annoncées ; ralentissement sans immobilisation forcée |
| ravine_ram | `cliff_charge` | `enemy_ram_charge` | Charge rectiligne après 0,7 s d'annonce ; stop sur décor |
| ravine_ram | `horn_sweep` | `enemy_ram_horn` | Large balayage frontal ; récupération 0,8 s |
| veilarc P1 | `gale_cleaver` | `boss_veilarc_gale_cleaver` | Lame en arc ; zone sûre derrière le boss |
| veilarc P1 | `chime_cage` | `boss_veilarc_chime_cage` | Anneaux de cloches fermant par segments, brèche atteignable |
| veilarc P2 | `tempest_reversal` | `boss_veilarc_tempest_reversal` | Deux bandes de vent alternées, intervalle sûr |
| veilarc P2 | `rift_maelstrom` | `boss_veilarc_maelstrom` | Aspiration centrale courte coupée par des abris ; pas de chute inévitable |

## Raccordement attendu

- Respecter `DraftPixelFx.dedicated`, `UNDER_TELEGRAPHS`, `sight_clear()`, navigation 3D, altitude et plateformes.
- FX décoratifs uniquement : dégâts, collisions et hitboxes sont déterminés par les scripts.
- `transform` à 50 % PV provisoires, puis alternance de clips `phase2_idle` et `phase2_move`.
- Pas d'effet de contrôle permanent ni de trajectoire sans zone de fuite.
- Les noms des animations et chemins d'assets sont fixés dans le fragment `assets/manifest_sifflants_fragment.json` livré avec les PNG.
- Avant validation : import Godot, animations de 6 frames, ancrage, télégraphes, tests techniques et captures en jeu.
