# Compétences, arbres et builds

Statut : **validé le 14 octobre 2026**, réalisation à venir (après le mode vagues par zone).
Inspiration principale : **Hades** (profondeur de build, difficulté exigeante mais juste, rejouabilité).

## Deux couches de progression, bien distinctes

| Couche | Où | Persistance | Rôle |
|---|---|---|---|
| **Build** | Refuge, avant le départ | **Permanent** : conservé d'une expédition à l'autre | Décide quels sorts et passifs le joueur possède |
| **Montées de niveau** | Pendant l'expédition | Temporaire : remis à zéro à la fin de la partie | Renforcent le build (dégâts, effets bonus, raretés) ; rendent chaque expédition différente |

### Le build (permanent)

- **Arbre du Chasseur** et **un arbre par Écho** : chacun débloque des **passifs** et des **compétences**.
- **Points limités** : impossible de tout débloquer ; branches mutuellement exclusives (A *ou* B).
  Le joueur construit son build au fil des expéditions.
- **Réversible** au refuge (comme le Miroir de la Nuit de Hades), pour expérimenter.
- **Plusieurs builds enregistrables** : le joueur peut garder d'autres builds à côté et choisit lequel
  emporter depuis le menu avant le départ.
- Remplace à terme l'arbre du Chasseur actuel (5 branches, 27 nœuds) en reprenant ses bons nœuds.

### Les montées de niveau (en partie)

- Les cartes de choix au passage de niveau sont conservées.
- Elles renforcent les sorts et passifs du build (équivalent des bienfaits de Hades), avec des
  **raretés** (commun → rare → épique → héroïque).
- Les synergies entre Échos jouent le rôle des bienfaits « duo ».

## Commandes (validées)

| Action | Touche |
|---|---|
| Déplacement | Z Q S D (AZERTY ; touches physiques, donc W A S D en QWERTY) |
| Attaque de base | **Automatique** |
| Ruée (esquive) | Espace / Maj (inchangé) |
| Sorts du Chasseur | **A, E, R, F** |
| Sorts des Échos | **1, 2, 3…** (un par Écho de l'équipe) |
| Visée | Le curseur de la souris |

- **Lancement** : le joueur vise avec la souris ; **appuyer sur la touche lance immédiatement le sort
  vers le curseur** (pas de clic). Un indicateur au sol montre la portée / la zone visée.
- Toutes les touches seront **reconfigurables** dans les options.
- Manette : stick droit pour viser, boutons pour les sorts (à détailler).
- Les sorts des Échos remplacent les « techniques » actuelles déclenchées par 1 / 2 / 3, en leur
  ajoutant la visée au curseur.

## Difficulté façon Hades

- Ennemis qui **télégraphient** leurs attaques et demandent d'esquiver, plutôt que des sacs à PV.
- Élites à modificateurs (existant), boss à phases (Nébulorax : 2 phases).
- Tension et pactes de risque (existants) étendus en vrai « Pacte » : malus au choix qui augmentent
  les récompenses (voir [LONGEVITE.md](LONGEVITE.md)).

## Contenu à créer

- Chasseur : 6 à 8 sorts + passifs, répartis dans son arbre.
- Chaque Écho : un arbre avec passifs + 2 ou 3 compétences actives (7 Échos à terme).
- Pour chaque sort : textes FR/EN, effets visuels, icône (générée par le propriétaire).

## Découpage prévu (livrable par étapes)

1. Visée au curseur et lancement de 2 sorts du Chasseur (A, E).
2. Arbre du Chasseur v2 + builds enregistrés au refuge.
3. Arbres des Échos et sorts des Échos visés (1, 2, 3).
4. Raretés des choix de niveau.

## Questions ouvertes

- Liste et effets des sorts du Chasseur et des Échos (à proposer au propriétaire).
- Nombre d'emplacements de sorts équipables par build.
- Monnaie et coût des points d'arbre (éclats actuels ou nouvelle ressource).
