# Les Rapiécés

Dans les ateliers abandonnés, la Faille a pris dans le lin usé et les fuseaux de bois.
Les coutures carmin traversent des étoffes délavées. Les points violets s'allument aux yeux,
aux coutures sous tension et dans quelques nœuds. L'exercice de lisibilité utilise les dalles
claires et corrompues du Sanctuaire des Runes.

| Rang | Nom | Identifiant | Geste et techniques proposés |
| --- | --- | --- | --- |
| Normal | Bobine mordante | `enemy.biting_bobbin` | Une petite bobine quadrupède qui claque de la mâchoire. |
| Normal | Ravaudeur | `enemy.patch_mender` | Un mannequin voûté qui pique de son aiguille. |
| Normal volant | Mite du voile | `enemy.veil_moth` | Des ailes en pans de tapisserie qui s'ouvrent au tir. |
| Normal à technique | Marionnette fendue | `enemy.split_puppet` | Coup du bras et coup de pied à ressort (`spring_kick`). |
| Élite | Navette de guerre | `enemy.war_shuttle` | Garde derrière la navette (`braced_shuttle`), puis frappe verticale (`loom_strike`). |
| Élite | Fileuse de linceuls | `enemy.shroud_spinner` | Collecte de fil (`thread_gather`) et repli sous son linceul (`shroud`). |
| Élite | Bélier de tenture | `enemy.tapestry_ram` | Charge tête basse (`bow_and_ram`) et franges hérissées (`fringe_bristle`). |

La répartition reprend celle des Saumâtres. Chaque déplacement, attaque, mort d'élite et technique
dessinée compte six poses. La planche A des normaux contient déplacement et attaque, avec une
rangée supplémentaire pour la Marionnette. A contient aussi la mort chez les élites.
Une planche B par élite, construite à partir de sa planche A, décrit ses deux techniques.
Les normaux laisseront l'effet commun remplacer leur silhouette à la mort. Le moteur fournira
les projectiles, les télégraphes et l'ombre placée sous la Mite.

Les dix planches de production, les sources retenues et les prompts ImageGen sont sous
`assets/concepts/incoming/enemy.<id>/`. Le manifeste référence les sept feuilles finales
à l'échelle 0,5 et leur palette plafonnée à 32 couleurs.

```sh
python3 tools/art/import_rapieces.py --preview-dir <dossier>
```

[Catalogue des silhouettes](../previews/rapieces/famille.webp) · [Aperçu animé](../previews/rapieces/mouvements.gif)

Le [banc Godot sur les dalles](../previews/rapieces/dalles.webp) et [sur la corruption](../previews/rapieces/berges.webp)
affiche les sprites et deux témoins d'échelle au zoom 1,3333 du mode 2D. Les comportements
et la répartition en partie restent à brancher avec les identifiants ci-dessus.

Le validateur du projet a accepté les sept entrées dans un banc Godot 4.3 isolé.
Le [rapport de contrôle](../previews/rapieces/controle.json) contient les empreintes des feuilles et icônes.
