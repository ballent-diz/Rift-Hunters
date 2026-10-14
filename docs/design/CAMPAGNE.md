# Campagne, cartes et déblocages

Statut : **validé le 14 octobre 2026**. Structure de la progression d'une carte à l'autre.

## Structure : chapitres de cartes

- La campagne est découpée en **chapitres**, un par région / ambiance (Ruines des Cascades, puis les
  cartes « plus colorées » préparées par le propriétaire…).
- Chaque chapitre compte **3 à 4 cartes**. La **dernière carte** de chaque chapitre se termine par un
  **Dévoreur** (boss de chapitre), précédé de zones de vagues.
- **Déblocage en avançant** : finir une carte débloque la suivante ; battre le Dévoreur débloque le
  chapitre suivant. Au refuge, la liste des chapitres (ou une carte du monde) montre les cartes
  verrouillées en grisé.
- Une expédition = une carte (environ 10-12 minutes).

## Rejouabilité

- **Toute carte débloquée est rejouable à l'infini** (gagner des points d'arbre, tester un build,
  viser un trophée).
- **3 objectifs par carte** (façon étoiles) : par exemple terminer ; terminer sans dépasser X dégâts
  subis ; terminer en Tension II ou plus. Ils alimentent les trophées et le platine.
- **Récompenses dégressives** : la première victoire rapporte beaucoup, les suivantes moins, sauf en
  montant la Tension (évite le farm abusif).
- **Tension choisie par carte** : refaire une carte connue en plus difficile.
- Plus tard (option) : **carte du jour**, même carte et mêmes modificateurs pour tous, avec classement.

## Répartition des modes

| Part | Mode | Où |
|---|---|---|
| ~70 % | **Vagues par zone** (mode principal, identité du jeu) | La majorité des cartes de campagne ; toujours sur la dernière carte d'un chapitre (zones puis Dévoreur) |
| ~30 % | Variantes : défense d'autel, fermeture de failles, zone qui se resserre… | Au moins une par chapitre, pour casser le rythme |
| Hors campagne | **Survie au chrono** | La **Plaine fracturée**, épreuve d'endurance pour le score, accessible à tout moment |

Un mode différent par carte est écarté : le joueur n'aurait pas le temps de maîtriser un mode, et
chaque mode coûte cher à développer et à équilibrer. Détail des modes : [LONGEVITE.md](LONGEVITE.md).

## Volume visé

- 4 chapitres × 4 cartes = **16 cartes**, soit **6 à 10 heures** pour finir la campagne (échecs compris).
- Puis objectifs de cartes, Tension, New Game+ et trophées : **plusieurs dizaines d'heures** pour le platine.

## Contenu actuel

| Carte | Rôle |
|---|---|
| Ruines des Cascades (`three_rifts`) | Chapitre 1, carte finale (zones puis Nébulorax) — premier niveau en vagues par zone |
| Plaine fracturée (`fractured_plain`) | Mode Survie, hors campagne |

Les cartes suivantes du chapitre 1 et le chapitre 2 (cartes colorées) restent à produire.

## Conception technique (prévue)

- Données : une ressource **chapitre** (liste ordonnée de cartes, Dévoreur, ambiance) et, par carte,
  son **mode**, ses **3 objectifs**, ses récompenses (première victoire / suivantes).
- Sauvegarde : cartes débloquées, objectifs obtenus et meilleure Tension par carte (migration du profil
  versionné ; les arènes déjà débloquées restent débloquées).
- Refuge : l'onglet Expédition devient une sélection chapitre → carte, avec les objectifs visibles.

## Questions ouvertes

- Nom et thème des chapitres 1 et 2, ordre des cartes à l'intérieur.
- Valeurs exactes des récompenses dégressives.

## Paysages et formats des cartes

Décision du propriétaire après les essais : chaque changement de chapitre doit proposer un autre type de décor, reconnaissable par son terrain, son architecture, sa végétation et sa palette. Les trois formats standards sont 3, 6 et 9 cases ; les règles de netteté, de circulation et d’échelle se trouvent dans ../MAP_GUIDELINES.md. La Plaine fracturée reste la référence visuelle et de proportions, indépendamment du thème du chapitre.
