# Reprise des animations des seize Échos — lisibilité en partie

Suite demandée par le propriétaire après C5-ter et les trente icônes du Chasseur : rapprocher la finition
des effets des compétences du Chasseur et rendre les attaques visibles à la taille réelle de la partie.
Les livraisons précédentes restent accessibles en PR #32 et #33. La branche reprend leur historique pour
éviter les conflits du manifeste et de la feuille de route ; fusionner ces PR avant celle de cette reprise.

## Rendu natif Godot

Les 77 scènes existantes gardent leurs chemins et leur contrat C7 : 16 attaques, 32 sorts, 13 statuts,
16 indicateurs. Aucun changement de src/, des données, collisions, dégâts, soins, cibles ou cadences.
radius, visual_duration, travel_distance, direction, target_shape, play/release et les positions secondaires
gardent leur sens. La garde de Mirelle boucle jusqu’au retrait décidé par le gameplay.

painted_stroke.gd forme un ruban volumétrique avec une rampe de pigment et une brosse texturée.
Les triangles sont envoyés ensemble à RenderingServer : deux commandes par ruban détaillé, quel que soit
le nombre de segments. Sous forte superposition, une ligne de pigment conserve sa silhouette à faible coût.
Aucun nœud ajouté par particule ; chaque effet reste un seul Node2D dans la couche commune plafonnée à 24.

La matière reprend la texture du Chasseur en luminance : elle ne teinte plus de cyan les palettes des Échos.
Les contours des trajectoires sont plus épais, les noyaux des projectiles plus présents et les éclats plus grands.
La fin des effets laisse davantage de temps lisible avant la dissipation, dans la durée fournie par C7.
Pas d’addition globale, de grand cercle lumineux ni de changement du placement sous les personnages.

| Écho | Reprise |
|---|---|
| Cendrelame | Croissants orange pleins, bord ivoire, traînée de braises et impact. Version légère à deux arcs en cas de saturation. |
| Mousseroc | Fractures à liseré sombre, fissures plus épaisses, fragments plus massifs et aspiration plus lisible. Palette volcanique du sprite conservée. |
| Lucivelle | Cœur prismatique agrandi, traînées cyan épaisses, détonations et cristaux descendants renforcés. |
| Ronceline | Branches plus épaisses, feuilles plus grandes et moins nombreuses, fleurs plus présentes ; cinq zones du mur conservées. |
| Fulgurine | Rubans électriques plus larges, cœur clair et contacts d’orage accentués ; les rebonds utilisent toujours les cibles fournies. |
| Gueule-d’ombre | Mâchoires et dents plus lisibles, langues d’aspiration plus épaisses ; palette ombre/lilas sans magenta. |
| Mirelle | Éclats plus larges, sillage argent, cinq branches d’éventail conservées et garde à facettes. |
| Pyraile | Plumes plus amples, nervures contrastées, sillages de chute et piqué plus présents. |
| Scoriade | Morsure dentée, cœur de lave visible dans les croûtes, fissures et geyser épaissis. |
| Spectrâtre | Enveloppe de flamme élargie, cœur sombre conservé, aspiration à fragments et langues de matière. |
| Sporelune | Spores en capsules plutôt que simples points, gonflement, graine plus ample et lumière ponctuelle. |
| Gravelune | Fragments orbitaux plus massifs, sillons de gravité plus visibles, météore et traînée renforcés. |
| Sylvécaille | Pousses ramifiées, feuilles plus amples et liens de soin plus nets ; garde simplifiée seulement sous forte superposition. |
| Solgriffe | Griffes plus larges et balayage allongé, rayons solaires plus denses, bond à traînée pleine. |
| Lueurine | Corps lumineux plus présents, ailes dessinées dont l’amplitude bat au cours de l’animation. |
| Égidor | Décharges à cœur clair plus épais ; coque électrique allégée en faible détail, sans remplissage masquant. |

## Présentation et reproduction

tools/art/echo_polish_preview.tscn réutilise le présentateur de la vraie partie pour les seize Échos.
Les noms, sprites et poses viennent du roster réel ; aucun faux Écho ajouté pour les images.
Le profil est isolé, en lecture seule. Le son est coupé dans les outils, et les exports utilisent également
le pilote audio Dummy. Les fenêtres sont hors écran, sans prise de focus, et se ferment après export.
Les paramètres sonores enregistrés du joueur ne changent pas.

Le présentateur accepte --only=<identifiants séparés par des virgules>, --shots-only, --metrics-only et
--skip-metrics. ORIGIN_FRAME_DIR désigne le dossier temporaire des images d’animation ; les processus de la
partie sont alors désactivés et les poses sont pilotées explicitement pour conserver un décor figé.
Les effets restent animés par leur temps visuel, pas par des dégâts simulés.

encode_origin_effects.py accepte plusieurs --catalog (origin_scenes.json et effects_catalog.json),
--out docs/previews/echos-animations et --frames <dossier>. Il exporte 48 GIF à la durée propre des scènes.
echo_polish_report.py contrôle leurs dimensions, leur animation et leurs durées, puis crée la planche et les liens.
L’option --delta garde les pixels du décor déjà affichés au lieu de les répéter dans chaque image.
Le décodage est comparé aux images quantifiées de référence et les durées sont vérifiées, même lorsque
le format GIF fusionne des images identiques. Les 48 GIF passent ainsi de 324 à 48,4 Mo, en restant en 1280 × 720.

Les [captures complètes et GIF](../previews/echos-animations/README.md) servent à la validation artistique
du propriétaire. Les sorts encore absents du raccordement C7 restent à brancher par Claude ; le présentateur
peut montrer une ressource disponible avant que son appel soit ajouté au gameplay.

## Contrôles et performances

Contrôles ciblés conformément à AGENTS.md pour une retouche visuelle : chargement et cycle des 77 scènes,
plafond et boucle miroir, lint des scripts modifiés, export natif des phases d’animation et validation du manifeste.
Pas de nouvelle suite complète à chaque retouche : celle des lots précédents est déjà verte (231 tests).

performance.json mesure 60 images sans/avec 24 émetteurs, géométrie animée, sur Intel Iris Xe et 90 Corrompus gelés.
Médianes observées avec effets : 35,9–47,0 ms ; le témoin sans effets varie aussi, de 32,2 à 45,9 ms selon le passage.
Le temps mesuré inclut l’attente entre deux images hors écran : il ne mesure pas isolément le GPU et ne valide
pas 60 images/s. L’IA et les collisions restent gelées. Les détails décoratifs sont réduits dès sept effets,
avec particle_budget réglé à quatre au-delà de douze, et les émissions au-delà de 24 sont refusées sans changer le jeu.

Résultats des 18–19 octobre : les contrôles C5-bis (45 scènes) et C5-ter (32 scènes) passent ; import Godot 4.3 et
311 ressources sans erreur. Lint ciblé des trois renderers et des outils modifiés réussi. Les 16 captures,
48 GIF animés et leurs durées sont contrôlés ; aucune erreur de dessin ou de shader dans l’export natif.
Le présentateur conserve le message de ressources en usage à sa fermeture déjà observé dans les lots précédents ;
les contrôles autonomes des scènes, de leur fin de vie et du plafond ne signalent pas d’erreur.
