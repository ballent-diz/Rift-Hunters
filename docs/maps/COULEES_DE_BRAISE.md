# Coulées de braise — composition de la carte 9

Chapitre 2, monde **5016 × 1672**, panorama **1536 × 512**. Cette PR livre une
**composition validée le 24 octobre 2026, à conserver telle quelle**, pas une texture finale ni un niveau jouable. Les régions,
la netteté au zoom du jeu et les collisions restent à réaliser sur ce plan désormais figé.

![Composition entière](../previews/ember-flows/composition.png)

## Parcours et repères à confirmer

Trois chenaux obliques, sept ponts de basalte, déplacement de droite à gauche.
Le chenal occidental se divise autour d'une île reliée aux deux rives. Le combat
final utilise l'étendue libre occidentale, sans arène construite ni cercle peint.
Les failles restent des objets du jeu : aucune n'est dessinée dans la composition.

Les coordonnées sont en pourcentage depuis le coin supérieur gauche. Le générateur
a déplacé certains repères : les positions ci-dessous proposent du sol libre dans
l'image livrée. Elles **ne remplacent pas silencieusement le brief** et doivent être
confirmées avant de figer le plan.

| Repère | Brief | Proposition sur l'image |
|---|---|---|
| Départ | 92,55 | 94,36 : replat oriental, éloigné du bloc-abri |
| Faille 1 | 74,35 | 83,32 : rive orientale sûre |
| Faille 2 | 55,70 | 63,66 : cuvette à l'est du chenal médian |
| Faille 3 | 36,30 | 30,31 : île, ruines retirées par retouche |
| Faille 4 | 18,65 | 18,50 : étendue près des ruines occidentales |
| Gardien | 8,40 | 8,40 : terrain naturel libre |

Ponts observés : chenal oriental vers (71,23) et (77,79), médian vers (56,23)
et (56,74), occidental vers (24,31), (36,31) et (28,73). Chaque chenal possède
donc plusieurs traversées permanentes ; le masque de débordement n'inclut aucun pont.
Quatre blocs-abris sont visibles vers (18,16), (42,73), (63,26), (88,62), loin
des tabliers. Leur échelle précise sera vérifiée à la passe de régions.

## Plan validé et masques à préparer

Le propriétaire a choisi l'image jointe le 24 octobre : elle correspond exactement
à `source/retouche_ile.png`, pas à la dernière version aux bandes élargies.
`source/composition_validee.png` conserve ses octets sans aucune retouche.
`VALIDATION_PROPRIETAIRE.json` enregistre son SHA256 et la demande « on garde aussi
celle la telle quel ». La composition de travail est seulement réduite à 1536 × 512.

Les masques et chiffres de l'autre version ne décrivent pas cette image. Ils sont
archivés dans `source/essai_non_retenu/` et ne sont plus désignés par le job.
Le masque des six lits doit être retracé sur ce plan sans élargir ou déplacer les
bandes dans l'image. Les anciennes mesures restent historiques, pas certifiées ici.
Les coordonnées de failles ci-dessus sont des propositions d'intégration : aucun
objet de gameplay ni aucune collision n'est ajouté par cette validation visuelle.

## Sources et contrôles

Les sources brutes 2172 × 724, trois essais précédents, les quatre prompts exacts,
les références de style et leurs SHA256 sont dans `source/`. `composition.png`
est une réduction de format de la source choisie par le propriétaire ; aucun agrandissement n'est
présenté comme une carte détaillée. Les références ne servent pas de plan.

Contrôle ciblé : lecture des PNG, dimensions, couleurs du masque, composantes,
polygones et absence de modification dans `src/`, `data/` ou les collisions.
Les ressources restent dans `incoming/` sous `.gdignore`, sans entrée de décor
jouable au manifeste tant que le propriétaire n'a pas validé et peint ses collisions.

- [x] Composition entière et provenance conservées.
- [ ] Masque provisoire à retracer sur la version choisie ; essai antérieur archivé.
- [x] Chenaux traversés par plusieurs ponts, espace final sans arène imposée.
- [x] Composition choisie par le propriétaire, sans retouche ; plan figé.
- [ ] Mesures des lits et repères d’intégration à vérifier sur cette version.
- [ ] Régions, rapport de qualité conforme, chaleur de netteté et captures au zoom réel.
- [ ] Collisions peintes et intégration du mode par Claude.
