# Les Sifflants — bestiaire du Défilé Hurlant (carte 7)

Famille originale issue de la **première planche de sept créatures** choisie par le propriétaire. Les concepts alternatifs des Éoliques/Hurlants/Aéragés ne remplacent pas cette référence.

| Rang | ID | Nom | Silhouette et comportement |
|---|---|---|---|
| Normal | `enemy.shale_scrabbler` | Gratte-schiste | Petit quadrupède à griffes d'os ; attaque courte |
| Normal | `enemy.bell_husk` | Clocheux des gorges | Errant au masque d'os et cloches de bronze ; griffe |
| Normal volant | `enemy.rift_kite` | Milan du gouffre | Ailes de voile et crâne aviaire ; piqué |
| Normal à technique | `enemy.gust_engine` | Souffleur de schiste | Quadrupède à lentille de Faille ; cône de vent |
| Élite | `enemy.shale_bastion` | Bastion du défilé | Hache et bouclier ; garde puis frappe |
| Élite | `enemy.wind_cantor` | Chantre des rafales | Mage aux flûtes et étoffes ; contrôle par le son |
| Élite | `enemy.ravine_ram` | Bélier des corniches | Cornes de bronze ; charge et balayage |

**Boss** : `boss.veilarc` — **Véilarc, Dévoreur des Courants**. Géant d'ardoise à tête aviaire, faux d'os, couronne de carillons et cœur cyclonique magenta. Deux phases, seuil de passage proposé à 50 % PV ; quatre techniques spécifiées dans [SIFFLANTS_COMPETENCES.md](../design/SIFFLANTS_COMPETENCES.md).

## Ressources préparées (publication PNG distincte)

- `assets/sprites/enemies/<id>/<id>_sheet.png` : 6 colonnes, 2 à 5 rangées, cellules 64–96 px.
- `assets/sprites/bosses/veilarc/veilarc_sheet.png` : 6 colonnes × 11 rangées, cellules 448 × 304 px.
- `assets/ui/icons/{enemies,bosses}/<id>.png` : icônes PNG.
- `assets/vfx/pixelfx/<effect_id>/violet.{png,json}` : 11 FX, 6 images chacun.

Style : `docs/ART_BIBLE.md` (schiste, os, bronze, étoffes indigo, Faille magenta discrète, caméra 2,5D). Le boss n'a que quatre rangées générées d'origine : les sept autres rangées sont des **réutilisations/transformations** à parfaire ; pas onze animations peintes indépendamment.

**État** : prototypes `wip` disponibles dans l'archive livrée séparément. Leur présence dans cette fiche ne signifie pas que les PNG ni les mécaniques sont dans `main`. Imports Godot et essais en situation requis.
