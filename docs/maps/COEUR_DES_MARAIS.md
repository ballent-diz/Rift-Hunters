# Cœur des marais — composition de la carte 15

Chapitre3, monde prévu **3344 × 5016 unités**, portrait2:3. Composition seulement, **pas de régions ni de niveau jouable**. Image retenue : incoming/map.marsh_heart/composition.png ; carte entière et plan annoté dans docs/previews/marsh-heart/.

## Parcours et mécaniques à raccorder par Claude

Départ sud (50%,96%) ; grande clairière vaseuse (50%,79%) ; temple central (50%,55%) ; grande terrasse supérieure de Glauquemire (50%,23%). Vagues par zone puis Dévoreur en trois phases. Eau turquoise profonde infranchissable, mousse émeraude et pierre cyan, pas de lave ou d’orange. Décor et colonnes en bordure, sol libre dans les combats.

Les nappes de vase gris-olive du bas sont praticables : centres approximatifs (28%,74%), (47%,83%), (68%,82%). Ces repères ne sont pas des masques ni des collisions.

Deux chaussées hautes, rectangles en % (x,y,largeur,hauteur) : ouest(18,47,20,3), est(62,47,20,3). Elles sont destinées à la marée. Deux ponts plus bas restent secs : ouest(18,59,20,3), est(62,59,20,3). Le sol central et les berges latérales relient ces accès ; ne jamais noyer tout le parcours. Le matériau mouillé reste à renforcer si nécessaire lors du détail après validation.

## Arène

L’arène supérieure a été approfondie lors de la retouche. Emprise visuelle indicative x12..88%,y6..39%, soit environ2541 ×1655unités. La profondeur réellement praticable et les coins libres restent à vérifier lors de la peinture : **ne pas certifier automatiquement la compatibilité avec un rayon950**. Le propriétaire et Claude devront contrôler ce réglage du boss sur le masque. Trois accès visibles, sols libres autour du centre ; aucun cercle peint, aucun miroir/cristal interactif dessiné. Quatre emplacements de miroirs pourront être placés sur le sol libre vers (38,19),(62,19),(38,28),(62,28)%, à confirmer au raccordement.

## Mesures / contrôle de composition

| Critère | État |
|---|---|
| Format |2:3,3344×5016prévu|
| Départ et progression |Sud vers nord, continuité visuelle inspectée|
| Routes≥4%,passages≥2,5% |Objectifs du prompt, mesures définitives à la peinture|
| Sol praticable≥55% |Visé ; part exacte non mesurée, ne pas prétendre certifiée|
| Marée |Deux raccourcis bas et alternatives sèches proposées ; navigation à tester|
| Arène libre |Agrandie, sans obstacle central ni grand cercle ; taille utile à valider|
| Bords |Fermés par eau/racines/ruines ; départ fermé côté extérieur|

- [x] Composition entière, plan annoté, sources/prompts/SHA.
- [x] Inspection visuelle de la continuité des accès.
- [ ] Validation du propriétaire ; collisions peintes ensuite par lui.
- [ ] Passe de régions uniquement après validation.
- [ ] Raccordement vagues, vase, marée, miroirs et gardien par Claude.

Aucun src/,data/,collision ni manifeste runtime modifié. Les références Puits/Ruines servent aux matières, pas au plan. Une première composition trop peu profonde et une retouche échouée pour connexion ont précédé la sortie retenue ; essais exclus de Git. La version de travail n’est pas un détail final conforme.
