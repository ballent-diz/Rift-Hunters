# Contrôle C5-bis — nouveaux Échos

Captures natives Godot, 1280 × 720, vraie scène des Ruines des Cascades gelée avec 90 Corrompus.
Le sprite du nouvel Écho et ses effets sont ajoutés par l'outil de présentation ; son comportement
C7 n'est pas raccordé dans cette branche. Le Chasseur, Mousseroc et le HUD restent ceux de la partie.

| Écho | Capture en partie | Technique | Second sort |
|---|---|---|---|
| Pyraile | [Capture](cinderwing.png) | [Pluie de cendres](cinderwing_ash_rain.gif) | [Piqué foudroyant](cinderwing_thunder_dive.gif) |
| Scoriade | [Capture](magmander.png) | [Coulée](magmander_lava_flow.gif) | [Geyser](magmander_geyser.gif) |
| Spectrâtre | [Capture](hollowflame.png) | [Implosion](hollowflame_implosion.gif) | [Flamme errante](hollowflame_wandering_flame.gif) |
| Sporelune | [Capture](moonspore.png) | [Nuée de spores](moonspore_spore_cloud.gif) | [Bourgeon](moonspore_bud_trap.gif) |
| Gravelune | [Capture](gravishell.png) | [Singularité](gravishell_gravity_well.gif) | [Météore](gravishell_meteor.gif) |
| Sylvécaille | [Capture](grovestag.png) | [Bosquet](grovestag_healing_grove.gif) | [Ronces protectrices](grovestag_protective_thorns.gif) |
| Solgriffe | [Capture](sunclaw.png) | [Éclat solaire](sunclaw_solar_flare.gif) | [Bond lumineux](sunclaw_radiant_leap.gif) |
| Lueurine | [Capture](glowmoth.png) | [Essaim de lucioles](glowmoth_firefly_swarm.gif) | [Poudre d'ailes](glowmoth_wing_dust.gif) |
| Égidor | [Capture](stormshell.png) | [Dôme conducteur](stormshell_conductive_dome.gif) | [Décharge](stormshell_discharge.gif) |

Les trois premières images de chaque GIF montrent l'indicateur de visée ; il disparaît au lancement.
La capture fixe associe attaque, statut et technique pour examiner la palette et l'échelle.
[Planche des icônes](icones-controle.png) : 112 px et 48 px pour chaque illustration HD.

Mesures : [performance.json](performance.json). 90 Corrompus, 24 effets graphiques, 60 images par état
sans/avec effets. La géométrie est recalculée à chaque image avec le niveau de détail adaptatif de la couche.
Simulation gelée : ces mesures ne constituent pas un benchmark de toute l'IA, des collisions ou de C7.

Le contrôle de rendu signale à la fermeture des ressources retenues par la scène de partie,
comme les outils de capture précédents ; les erreurs de script et de dessin doivent rester absentes.
Contrat, palettes, paramètres et reproduction : [ECHOS_C7_EFFETS.md](../../art/ECHOS_C7_EFFETS.md).
