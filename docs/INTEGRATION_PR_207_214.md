# Intégration coordonnée du 17 novembre 2026

Demande du propriétaire : publier les 81 Mio du lot graphique puis fusionner les cinq autres PR dans un ordre
qui préserve leurs dépendances. La PR gameplay #212 est déjà fusionnée après CI verte (`5fecf861`).

Les branches originales restent intactes. Une branche d’intégration conserve leurs commits et résout les conflits
avant une CI complète sur l’ensemble. Ordre des fusions locales :

| Ordre | PR | Résolution |
|---|---|---|
| 1 | #207 — sauvegarde | Conserver le profil de #206 déjà présent sur main, reprendre les compteurs de combos. |
| 2 | #210 — racine-laisse | Ajouter la mécanique, conserver la plongée de Nivorath et les raccords récents. |
| 3 | #211 — Dévoreur | Ajouter ses enchaînements sans retirer la racine-laisse. |
| 4 | #213 — gardiens | Appliquer après sa dépendance #211. |
| 5 | #214 — éclaboussures | Ajouter les pas dans l’eau et leurs contrôles, indépendamment des boss. |

## Sauvegarde : éviter deux profils concurrents

#206 et #207 ont implémenté la même mission en parallèle, avec des API et des chemins différents.
Remplacer `draft3d_profile.json` par `draft3d_save.json` aurait masqué la progression déjà enregistrée par main.
L’intégration garde donc l’API statique de `DraftSave`, son fichier, ses migrations, chapitres atteints/vaincus,
copies de secours, lecture seule et protection des profils futurs. Les façades, options et tests existants restent
cohérents avec cette API. `stats.combos` reprend l’apport distinct de #207 : les déclenchements sont cumulés en fin
de partie puis enregistrés avec les autres statistiques. Un test couvre le cumul, la relecture du même profil et
l’exclusion des parties d’essai.

## Graphismes

Les douze FX de combos, leurs douze illustrations, trois FX de passifs et cinq cartes sont livrés dans les chemins
prévus. Les neuf raccords supplémentaires sont appliqués aux mécaniques de #212 ; aucune valeur de combat n’est
changée par ces raccords. [Inventaire et aperçus](art/COUVERTURE_VISUELLE_V2.md).

L’utilisateur a explicitement autorisé la publication publique des PNG, JSON, aperçus, sources ImageGen et prompts
via GitHub, puis la fusion après CI verte. La CI de la PR d’intégration contrôle la combinaison complète ; les CI
vertes des cinq PR originales constituent des contrôles supplémentaires de leurs versions isolées.
