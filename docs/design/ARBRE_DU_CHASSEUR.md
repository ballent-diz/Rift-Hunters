# Arbre du Chasseur v2 et sorts du Chasseur

Statut : **proposition du 16 octobre 2026, à valider par le propriétaire**. Une fois validée, sert de référence aux
lots C1 (visée, premiers sorts) et C2 (arbre v2, builds). Cadre général : [COMPETENCES_ET_BUILDS.md](COMPETENCES_ET_BUILDS.md).

## 1. Principes

- **Identité du Chasseur** : un sabreur des Failles (sprite de samouraï). Il garde son attaque automatique, le
  **Trait de Faille**, et gagne des **sorts visés au curseur** qui mêlent lame et magie de Faille.
- **Le build se joue sur les sorts** : 8 sorts à apprendre, **4 équipés** (A, E, R, F). Ce choix, plus les variantes et
  les passifs, fait le build.
- **Apprendre ≠ activer** (proposition clé) :
  - **apprendre** un nœud coûte des **Éclats**, une seule fois, pour toujours (la progression permanente actuelle) ;
  - **activer** un nœud dans un build coûte des **Points de Chasseur**, en nombre limité. Changer de build est
    **gratuit** au refuge : on expérimente librement (comme le Miroir de Hades), mais on ne peut pas tout activer.
- **Choix exclusifs** : chaque sort a deux **variantes** (A *ou* B) qui changent sa façon de jouer, et une seule
  **clé de voûte** (ultime passif) est active par build.
- Les statuts existants restent le langage commun : Fracture, Marques, Brûlure, Entrave, Racines.

## 2. Les 8 sorts (2 par voie)

Valeurs indicatives, à régler à l'équilibrage. Portée et zone affichées au sol pendant la visée.

| Voie | Sort | Effet de base | Recharge | Variante A | Variante B |
|---|---|---|---|---|---|
| Lame | **Taille fendante** | Arc de lame devant le Chasseur, vers le curseur (portée 150) : gros dégâts + Fracture | 4 s | *Tourbillon* : cercle complet autour du Chasseur | *Estoc* : ligne longue et étroite (portée 320) qui perce tout |
| Lame | **Bond de faille** | Bond jusqu'au curseur (portée 380), invulnérable pendant le saut, onde de choc à l'arrivée | 9 s | *Retour* : réutiliser dans les 3 s ramène au point de départ | *Impact* : onde 2× plus large qui Entrave 2 s |
| Prisme | **Lance prismatique** | Trait lourd en ligne vers le curseur, traverse tout, pose 2 Marques | 6 s | *Éventail* : 3 lances en cône | *Surcharge* : maintenir la touche charge la lance (dégâts ×2,5) |
| Prisme | **Rupture** | Fait détoner toutes les Marques dans une zone au curseur (rayon 220) | 10 s | *Réaction* : chaque détonation pose 1 Marque à côté (chaîne) | *Brasier* : les détonations laissent de la Brûlure au sol 3 s |
| Abîme | **Singularité** | Sphère posée au curseur qui attire les ennemis 3 s puis implose | 14 s | *Horizon* : rayon +40 %, les ennemis attirés subissent +15 % de dégâts | *Effondrement* : implosion 2× plus forte, durée 1,5 s |
| Abîme | **Chaînes de faille** | Zone au curseur (rayon 160) : Racines 1,5 s puis Entrave 2 s | 12 s | *Geôle* : la zone dure 4 s et enracine tout ce qui y entre | *Lien* : les dégâts subis par un ennemi enchaîné touchent tous les autres (30 %) |
| Lien | **Appel de meute** | Les Échos bondissent vers le curseur et frappent ensemble (dégâts selon leur nombre) | 12 s | *Ralliement* : les Échos y gagnent +25 % de vitesse d'attaque 4 s | *Curée* : dégâts ×2 sur les élites et le boss |
| Lien | **Égide de faille** | Bouclier sur le Chasseur et ses Échos (absorbe 25 % des PV max, 4 s) | 18 s | *Riposte* : quand il se brise, onde de choc | *Partage* : le Chasseur reçoit 50 % du bouclier mais se soigne de 15 % |

**Départ** : *Taille fendante* (A) et *Lance prismatique* (E) sont connues dès le début (lot C1). Les 6 autres
s'apprennent dans l'arbre.

## 3. Plan de l'arbre

Un **tronc** commun, puis **4 voies** de 5 niveaux. Coûts : Éclats pour apprendre / Points pour activer.

```
                         TRONC (toujours accessible)
        Vigueur (PV)  ·  Entraînement (dégâts)  ·  Pas fantôme (Ruée)  ·  Dernier souffle
   ┌─────────────────┬──────────────────┬──────────────────┬──────────────────┐
 LAME              PRISME              ABÎME              LIEN
 (corps à corps,   (distance,          (contrôle,         (Échos)
  Fracture)         Marques)            zones)
 I   passif ×3     passif ×3           passif ×3          passif ×3
 II  sort 1        sort 1              sort 1             sort 1
 III variante A|B  variante A|B        variante A|B       variante A|B
 IV  sort 2 + var. sort 2 + var.       sort 2 + var.      sort 2 + var.
 V   CLÉ DE VOÛTE  CLÉ DE VOÛTE        CLÉ DE VOÛTE       CLÉ DE VOÛTE   ← une seule active par build
```

### Passifs et clés de voûte (reprise de l'arbre actuel en gras)

| Voie | Passifs (niveaux I et IV) | Clé de voûte (niveau V) |
|---|---|---|
| Tronc | Vigueur (+10 PV/rang), **Entraînement** (+5 % dégâts/rang), **Pas fantôme**, **Dernier souffle** | — |
| Lame | **Ruée fracturante** ; dégâts au corps à corps +8 %/rang ; **Cogneur de faille** | *Maître-lame* : chaque sort de Lame réduit de 1 s la recharge des autres sorts |
| Prisme | **Tireur des Failles** ; **Résonance prismatique** ; **Pyromancien** ; **Détonation en chaîne** | *Prisme vivant* : le Trait de Faille pose une Marque tous les 3 tirs |
| Abîme | **Brèche profonde** ; **Gravitationniste** ; durée des contrôles +15 %/rang | *Maître du vide* : les ennemis sous Racines ou Entrave subissent +25 % de dégâts |
| Lien | **Liens solides** ; **Techniques affûtées** ; **Chasseur solitaire** *ou* **Chef de meute** | *Âme de meute* : chaque sort du Chasseur réduit de 1 s la recharge des sorts d'Échos |

**Troisième sceau** (+1 emplacement d'équipe, 3e Écho) reste un nœud à part du tronc, débloqué par la progression de la
campagne, comme prévu dans [ECHOS.md](ECHOS.md).

### Ce qui sort de l'arbre

Les nœuds d'**Exploration** et de **Recherche** (Prospecteur, Aimant, Coffres scellés, Relique de départ, Flair de
l'Essence, Bannissement, Quatrième choix, Étude des Failles, Mutations instables, Évolution précoce, Recrues aguerries)
ne font pas un style de jeu : ce sont des **confort de partie**. Proposition : ils deviennent des **améliorations du
refuge**, achetées une fois et toujours actives (Laboratoire, payées en Essence ou en Éclats), hors du budget de points.
L'arbre ne contient plus que le build de combat.

## 4. Points de Chasseur

- Départ : **4 points**. **+1 point** à la première victoire sur chaque carte, **+1** tous les 3 objectifs de carte
  réussis. Ordre de grandeur en fin de campagne : **25 à 30 points**.
- Coûts d'activation : passif 1 point/rang, sort 2 points, variante 1 point, clé de voûte 4 points.
  Activer tout l'arbre coûterait ≈ 60 points : en fin de jeu, on remplit **à peu près deux voies** et on choisit.
- Les 4 sorts équipés doivent être activés ; les sorts de départ coûtent quand même leurs points (pas de gratuité
  qui fausse le budget), mais le joueur commence avec de quoi les activer.

## 5. Builds enregistrés

- **3 emplacements de build** nommables (un 4e et un 5e plus tard par la progression).
- Un build = nœuds activés + 4 sorts équipés sur A, E, R, F + (lot C3) le sort équipé de chaque Écho.
- Choix du build dans le menu de départ d'expédition ; modification au refuge, gratuite.

## 6. En partie : les montées de niveau

Les cartes de niveau restent et renforcent le build (lot C4, avec raretés) : par exemple *Taille fendante : +1 coup*,
*Singularité : recharge −20 %*, *Lance prismatique : +1 Marque*. Seuls les sorts **équipés** reçoivent des cartes.

## 7. Sauvegarde

Migration de la version de sauvegarde : les Éclats dépensés dans l'arbre actuel sont **remboursés** ; les nœuds
d'exploration et de recherche déjà achetés sont **conservés** comme améliorations du refuge.

## 8. À valider par le propriétaire

1. Le principe *apprendre (Éclats) / activer (Points)* et la réinitialisation gratuite.
2. Les 4 voies (Lame, Prisme, Abîme, Lien) et les 8 sorts ; noms et effets à retoucher librement.
3. Les 2 sorts de départ (Taille fendante, Lance prismatique).
4. La sortie des nœuds d'exploration et de recherche vers le refuge.
5. Le budget de points (4 au départ, 25-30 en fin de campagne) et 3 builds enregistrés.
