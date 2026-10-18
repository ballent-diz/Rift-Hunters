# Animations des seize Échos — reprise Godot

[Vue d’ensemble des seize Échos](planche.png). Chaque vignette renvoie ci-dessous à sa capture complète.

Rendus natifs 1280 × 720 dans une vraie partie gelée, avec 90 Corrompus, profil isolé en lecture seule.
Le présentateur déclenche les effets sans dégâts ; les raccordements C7 encore absents restent à Claude.
Exports sans son, fenêtres fermées automatiquement à la fin.

| Écho | Capture | Attaque | Technique | Second sort |
|---|---|---|---|---|
| Cendrelame | [Image](ashblade.png) | [Attaque](ashblade_attack.gif) | [ash_dance](ashblade_ash_dance.gif) | [cinder_dash](ashblade_cinder_dash.gif) |
| Mousseroc | [Image](mossback.png) | [Attaque](mossback_attack.gif) | [gravity_well](mossback_gravity_well.gif) | [stone_taunt](mossback_stone_taunt.gif) |
| Lucivelle | [Image](glimmerwing.png) | [Attaque](glimmerwing_attack.gif) | [prism_flare](glimmerwing_prism_flare.gif) | [spark_rain](glimmerwing_spark_rain.gif) |
| Ronceline | [Image](thornweave.png) | [Attaque](thornweave_attack.gif) | [briar_wall](thornweave_briar_wall.gif) | [bloom](thornweave_bloom.gif) |
| Fulgurine | [Image](voltwisp.png) | [Attaque](voltwisp_attack.gif) | [ion_storm](voltwisp_ion_storm.gif) | [chain_arc](voltwisp_chain_arc.gif) |
| Gueule-d’ombre | [Image](gloommaw.png) | [Attaque](gloommaw_attack.gif) | [feast](gloommaw_feast.gif) | [maw_pit](gloommaw_maw_pit.gif) |
| Mirelle | [Image](mirrorling.png) | [Attaque](mirrorling_attack.gif) | [reflection](mirrorling_reflection.gif) | [mirror_shards](mirrorling_mirror_shards.gif) |
| Pyraile | [Image](cinderwing.png) | [Attaque](cinderwing_attack.gif) | [ash_rain](cinderwing_ash_rain.gif) | [thunder_dive](cinderwing_thunder_dive.gif) |
| Scoriade | [Image](magmander.png) | [Attaque](magmander_attack.gif) | [lava_flow](magmander_lava_flow.gif) | [geyser](magmander_geyser.gif) |
| Spectrâtre | [Image](hollowflame.png) | [Attaque](hollowflame_attack.gif) | [implosion](hollowflame_implosion.gif) | [wandering_flame](hollowflame_wandering_flame.gif) |
| Sporelune | [Image](moonspore.png) | [Attaque](moonspore_attack.gif) | [spore_cloud](moonspore_spore_cloud.gif) | [bud_trap](moonspore_bud_trap.gif) |
| Gravelune | [Image](gravishell.png) | [Attaque](gravishell_attack.gif) | [gravity_well](gravishell_gravity_well.gif) | [meteor](gravishell_meteor.gif) |
| Sylvécaille | [Image](grovestag.png) | [Attaque](grovestag_attack.gif) | [healing_grove](grovestag_healing_grove.gif) | [protective_thorns](grovestag_protective_thorns.gif) |
| Solgriffe | [Image](sunclaw.png) | [Attaque](sunclaw_attack.gif) | [solar_flare](sunclaw_solar_flare.gif) | [radiant_leap](sunclaw_radiant_leap.gif) |
| Lueurine | [Image](glowmoth.png) | [Attaque](glowmoth_attack.gif) | [firefly_swarm](glowmoth_firefly_swarm.gif) | [wing_dust](glowmoth_wing_dust.gif) |
| Égidor | [Image](stormshell.png) | [Attaque](stormshell_attack.gif) | [conductive_dome](stormshell_conductive_dome.gif) | [discharge](stormshell_discharge.gif) |

## Contrôles et limites

Les deux contrats couvrent 77 scènes : 16 attaques, 32 sorts, 13 statuts et 16 indicateurs.
Plafond commun de 24 émetteurs ; niveau de détail réduit au-delà de 6 effets, sans changement des règles.
performance.json conserve les mesures hors écran sur Intel Iris Xe, 90 Corrompus et 24 effets.
Elles incluent les attentes d’affichage et ne valident pas 60 images/s ni le coût de l’IA en partie.
[Détail de la reprise](../../art/ANIMATIONS_ECHOS_VISIBILITE.md).
