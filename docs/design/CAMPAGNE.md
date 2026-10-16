# Campagne, cartes et déblocages

Statut : **validé le 14 octobre 2026**. Structure de la progression d'une carte à l'autre.

## Structure : chapitres de cartes

- La campagne est découpée en **chapitres**, un par région / ambiance (Ruines des Cascades, puis les
  cartes « plus colorées » préparées par le propriétaire…).
- Chaque chapitre compte **2 à 3 cartes** (piste : 5 chapitres, voir « Volume visé »). La **dernière carte** de chaque chapitre se termine par un
  **Dévoreur** (boss de chapitre), précédé de zones de vagues.
- **Déblocage en avançant** : finir une carte débloque la suivante ; battre le Dévoreur débloque le
  chapitre suivant. Au refuge, la liste des chapitres (ou une carte du monde) montre les cartes
  verrouillées en grisé.
- Une expédition = une carte (environ 10-12 minutes).

## Rejouabilité

- **Toute carte débloquée est rejouable à l'infini** (gagner des points d'arbre, tester un build,
  viser un trophée).
- **3 objectifs par carte en Normal, 3 en Cauchemar** (façon étoiles) : par exemple terminer ; terminer sans
  dépasser X dégâts subis ; vaincre le boss en moins de 2 min. Ils alimentent les trophées et le platine.
- **Récompenses dégressives** : la première victoire rapporte beaucoup, les suivantes moins, sauf en
  Cauchemar avec un score de Pacte plus élevé (évite le farm abusif).
- **Deux difficultés par carte** : Normal, puis **Cauchemar** une fois le jeu fini, avec le **Pacte** (malus au
  choix). La Tension est supprimée. Détail : [LONGEVITE.md](LONGEVITE.md).
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

Décision du 16 octobre 2026 : **un jeu plus court, très rejouable**.

- Campagne de **3 à 6 heures** (échecs compris). Piste actuelle : **5 chapitres** de 2 à 3 cartes (rien n'est figé).
- Puis Cauchemar, Pacte, objectifs, prophéties et trophées : **20 à 30 heures** pour le platine.

## Contenu actuel

| Carte | Rôle |
|---|---|
| Ruines des Cascades (`three_rifts`) | Chapitre 1, carte finale (zones puis Nébulorax) — premier niveau en vagues par zone |
| Plaine fracturée (`fractured_plain`) | Mode Survie, hors campagne |

Les cartes suivantes du chapitre 1 et le chapitre 2 (cartes colorées) restent à produire.

## Conception technique (prévue)

- Données : une ressource **chapitre** (liste ordonnée de cartes, Dévoreur, ambiance) et, par carte,
  son **mode**, ses **3 objectifs**, ses récompenses (première victoire / suivantes).
- Sauvegarde : cartes débloquées, objectifs obtenus, Cauchemar débloqué et meilleur score de Pacte par carte (migration du profil
  versionné ; les arènes déjà débloquées restent débloquées).
- Refuge : l'onglet Expédition devient une sélection chapitre → carte, avec les objectifs visibles.

## Questions ouvertes

- Nom et thème des chapitres 1 et 2, ordre des cartes à l'intérieur.
- Valeurs exactes des récompenses dégressives.

## Paysages et formats des cartes

Décision du propriétaire après les essais : chaque changement de chapitre doit proposer un autre type de décor, reconnaissable par son terrain, son architecture, sa végétation et sa palette. Les trois formats standards sont 3, 6 et 9 cases ; les règles de netteté, de circulation et d’échelle se trouvent dans ../MAP_GUIDELINES.md. La Plaine fracturée reste la référence visuelle et de proportions, indépendamment du thème du chapitre.
