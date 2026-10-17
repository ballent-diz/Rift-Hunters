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

| Chapitre | Carte | Rôle |
|---|---|---|
| 1 — Le Val des Cascades | Ruines des Cascades (`three_rifts`) | Carte 1 (zones puis Nébulorax) — premier niveau en vagues par zone |
| 1 — Le Val des Cascades | Hautes Terres d'Orage (`storm_highlands`) | Carte 2 (Astravorn) ; la gagner termine la campagne actuelle et débloque le Cauchemar |
| Hors campagne | Plaine fracturée (`fractured_plain`) | Mode Survie, toujours accessible |

Nom du chapitre provisoire. Les autres cartes du chapitre 1 et le chapitre 2 restent à produire (lot B3) : il suffit
d'ajouter une carte à la liste `maps` de son chapitre, dans l'ordre, ou un fichier par nouveau chapitre.

## Réalisation (lot B1, 17 octobre 2026)

- **Données** : un fichier par chapitre dans `data/chapters/` (`ChapterData` : rang, nom, couleur d'ambiance, cartes
  dans l'ordre). Chaque carte (`CampaignMapData`) nomme son arène, sa prime de première victoire (Normal / Cauchemar)
  et ses 3 + 3 objectifs (`MapObjectiveData` : compteur de partie, seuil « au moins » ou « au plus », Éclats). Le mode
  de jeu et le Dévoreur restent ceux de l'arène. Les fichiers d'arène ne changent pas.
- **Règles** : `src/progression/campaign.gd`. La première carte est ouverte ; gagner une carte en Normal ouvre la
  suivante (et annonce le nouveau chapitre) ; gagner la dernière carte débloque le Cauchemar sur toutes les cartes.
  Les arènes hors chapitre (Survie) gardent leur réglage `unlocked_by_default`.
- **Objectifs de carte** : évalués sur une victoire dans la difficulté jouée ; chacun rapporte des Éclats et compte
  pour les Points de Chasseur (avec les objectifs du jeu : +1 point tous les 3).
- **Récompenses** : prime de première victoire (150 / 250 Éclats aux Ruines, 200 / 300 aux Hautes Terres), puis
  récompenses de partie ×0,8 par victoire déjà obtenue dans la difficulté, plancher ×0,4
  (`balance_config` : `map_repeat_decay`, `map_repeat_floor`). En Cauchemar, battre son meilleur score de Pacte rend le
  plein tarif. Score de Pacte provisoire : nombre de pactes choisis (lot D3).
- **Première victoire en Cauchemar** sur une carte : +1 Point de Chasseur, comme la première victoire en Normal.
- **Sauvegarde v3** : section `campaign` (victoires et objectifs par carte et difficulté, meilleur Pacte, Cauchemar
  débloqué). Migration : les cartes déjà gagnées comptent une victoire en Normal ; elles et la dernière arène choisie
  restent débloquées ; une préférence de Tension devient Normal.
- **Refuge** : l'onglet Expédition propose Normal / Cauchemar et liste les cartes par chapitre (verrouillées en grisé,
  objectifs obtenus « ★ n/3 » et détail en infobulle), puis la Survie. Les pactes n'apparaissent qu'en Cauchemar.
  L'interface définitive (chapitre → carte, objectifs visibles) est le lot B2.

## Questions ouvertes

- Nom et thème des chapitres 1 et 2, ordre des cartes à l'intérieur.
- Valeurs exactes des récompenses dégressives.

## Paysages et formats des cartes

Décision du propriétaire après les essais : chaque changement de chapitre doit proposer un autre type de décor, reconnaissable par son terrain, son architecture, sa végétation et sa palette. Les trois formats standards sont 3, 6 et 9 cases ; les règles de netteté, de circulation et d’échelle se trouvent dans ../MAP_GUIDELINES.md. La Plaine fracturée reste la référence visuelle et de proportions, indépendamment du thème du chapitre.
