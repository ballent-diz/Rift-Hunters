# Bois des Lucioles — carte 3 du Val des Cascades

**Brouillon de revue, 19 octobre 2026.** Image et sources publiées à la demande du propriétaire avant la finition.
La carte n'est pas encore intégrée à la campagne et ne possède pas de collisions. La netteté uniforme,
l'échelle de certaines ruines et les mesures finales restent à valider ; ne pas considérer ce lot comme terminé.

## Images et fabrication

- Image entière de présentation : [vue complète](../previews/bois-des-lucioles/bois-carte-entiere.png).
- Image détaillée candidate : `assets/environments/firefly_woods/map.webp`, 6270 × 4180 pixels.
- Image à peindre : `assets/concepts/incoming/map.firefly_woods/collision/reference.webp`, **5016 × 3344**,
  soit un pixel par unité du monde, format 6 cases / 3:2.
- Sources, prompts exacts, sommes SHA256 : `assets/concepts/incoming/map.firefly_woods/source/`.
- Recette et état réel : `job.json`. Les neuf régions de détail sont assemblées sur une seule composition ;
  une finition supplémentaire à l'échelle de la caméra est présente uniquement dans le secteur `fine/1_1`.
  La taille 6270 × 4180 de la candidate ne signifie donc pas que toute sa surface a reçu cette dernière finition.
- Générateur intégré image_gen, images originales conservées ; aucune ressource tierce.
  Les trois images demandées (Plaine, Cascades, Hautes Terres) ont été jointes aux générations.

La conception `docs/design/CARTES.md` était absente de main au démarrage : lecture sur
`origin/claude/utiliser-mon-git-oofk0o`, sans modifier cette branche.

## Plan de travail

[Plan annoté](../previews/bois-des-lucioles/bois-plan-annote.png). Origine au coin supérieur gauche ;
X en pourcentage de la largeur, Y en pourcentage de la hauteur. Coordonnées arrondies sur l'image actuelle.

| Repère | Élément | X % | Y % |
|---|---|---:|---:|
| D | Départ sur la petite place sud-ouest | 10 | 81 |
| Z1 | Grande prairie du sous-bois | 42 | 71 |
| G | Gué large de l'affluent | 19 | 61 |
| P1 | Route courte entre les deux troncs creux | 26 | 39 |
| Z2 | Clairière haute, sanctuaire en bordure nord | 45 | 23 |
| P2 | Pont de bois et ses deux appuis | 63,5 | 46,5 |
| Z3 | Plateau oriental de mousse | 84 | 63 |
| F | Clairière du gardien sous l'arbre-monde | 82 | 25 |

Une crête de pierre et de racines relie le tronc central à la rivière afin de séparer les prairies basse et haute.
Le sanctuaire possède deux approches ouvertes qui rejoignent l'accès occidental du pont.
Ces repères constituent une proposition à reprendre lors du placement des zones par Claude, après la peinture.

| Clairière de lucioles | Zone proposée | X % | Y % |
|---|---:|---:|---:|
| L1 | 1 | 27 | 80 |
| L2 | 1 | 31 | 55 |
| L3 | 2 | 14 | 18 |
| L4 | 2 | 44 | 28 |
| L5 | 3 | 85 | 47 |
| L6 | 3 | 84 | 69 |

Lumière de fin de jour lisible, centres de clairières libres ; émission jaune-vert en bordure.
Aucun voile nocturne, système d'éclairage ou gardien n'est ajouté.

## Mesures et limites actuelles

| Élément | Minimum demandé | État du brouillon |
|---|---|---|
| Monde / format | 5016 × 3344, 3:2 | Dimensions vérifiées |
| Route principale | 200 unités / 4 % largeur | Relevé précis à terminer |
| Passage / pont / escalier | 120 unités et 2,5 % largeur (125,4 unités ici) | Pont élargi après constat d'un tablier trop étroit ; mesure finale entre garde-corps à confirmer |
| Clairière de combat | 750 unités / 15 % largeur | Grandes prairies présentes ; gabarits à terminer |
| Clairière du gardien | 900 unités / 18 % largeur | Place vide présente ; gabarit utilisable à confirmer |
| Sol praticable visuel | 55 % surface | **55,28 % environ** sur le relevé manuel ; incertitude de quelques points, seuil non certifié |
| Collisions / navigation | Détourage du propriétaire | Aucun masque ni test de circulation produit |

Le [relevé de surface](../previews/bois-des-lucioles/surface-releve.png) et ses polygones dans `survey.json`
servent uniquement à mesurer l'image. Ils **ne sont jamais convertis en collisions**.
Les petits cailloux et les détails de sol doivent rester traversables.

## Comparaison à la caméra réelle

[Comparaison côte à côte](../previews/bois-des-lucioles/comparaison-quatre-cartes.png).
Captures individuelles 1280 × 720, même zoom 1,3333, vrai Chasseur et Écho Mousseroc instanciés dans une partie gelée.
Le sol du Bois est remplacé uniquement par l'outil de capture ; aucune modification de `src/` ou de données de jeu.

Les premières captures ont montré que la vue complète était plus convaincante que le rendu à la caméra :
la correction de finesse du seul secteur `fine/1_1` est visible dans la capture du Bois.
Cette comparaison documente l'état du travail, pas une validation finale de toute la carte.

## Contrôle effectué pour cette publication

- Import Godot 4.3 effectué ; import final sans erreur de cache après exécution hors restriction de cache Windows.
- Chargement des quatre décors et captures à la caméra réelle : effectué.
- Avertissement résiduel à la fermeture de l'outil : une ressource encore référencée ; à corriger dans l'outil de
  capture avant validation finale. Le processus Godot est fermé et les captures sont produites.
- Pas de suite complète : lot d'image, cadence proportionnée demandée par le propriétaire.
- Prompts et fichiers sources conservés ; aucune `.import` ajoutée au dossier incoming.

## Checklist du guide, à la publication du brouillon

- [x] Format exact 3:2, sans bord, texte ni personnage dans l'image de carte.
- [ ] Chaque zone a une grande clairière ; largeurs finales mesurées et confirmées.
- [ ] Passages courts : fermeture et absence de contournement à confirmer après détourage.
- [ ] Clairière du gardien : diamètre utilisable mesuré et confirmé.
- [x] Centres ouverts ; pont intact avec appuis ; bords entourés de décor.
- [ ] Dernier contrôle des raccords et de l'échelle architecturale.
- [ ] Netteté comparable à la Plaine au même zoom sur toute la carte.

## Peinture et transfert

Ouvrir `collision/reference.webp`, peindre en rouge translucide les endroits bloqués, enregistrer
`collision/painted.webp` au même cadrage. Ne pas peindre les petits cailloux des chemins.
Garder le gué plat et le tablier du pont ouverts. Voir [méthode carte peinte, § 3 bis](DE_L_IMAGE_AU_NIVEAU.md).

Claude pourra ensuite déclarer l'environnement dans le manifeste, créer l'arène et construire les collisions
depuis la peinture du propriétaire, puis les zones, l'obscurité B2 et le gardien. Ne pas employer le relevé visuel
comme masque automatique ni annoncer cette image comme un niveau déjà jouable.
