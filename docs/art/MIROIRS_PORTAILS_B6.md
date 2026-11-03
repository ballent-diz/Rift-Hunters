# Miroir-portail : contrat visuel autonome B6

Scène : `res://assets/vfx/objects/mirror_portal/mirror_portal.tscn`.
Racine stable : **MirrorPortal**, Node2D unique, z_index 2. Pied ancré à `(0,0)` ; dimensions de repos environ 60 × 98 unités avec radius 32. Pas de collision, de lumière couvrante au sol, de téléportation, de cible ou de règle de recharge.

## Paramètres et API

- `radius: float = 32` : facteur uniforme de taille par rapport au modèle nominal.
- `duration: float = 0.65` : durée visuelle des états transitoires et échéance indicative de l'état cooldown. Claude peut régler ce paramètre à la durée de son événement.
- `tint: Color` : couleur de paire ; les deux portails jumeaux reçoivent la même couleur. La pierre et la structure restent communes, le verre, les arêtes et les fragments reprennent la teinte.
- `set_state(value: StringName)` ou `play(value: StringName)` : réinitialise le temps et joue l'état indiqué.
- États exacts : `active`, `cooldown`, `enter`, `exit`, `hidden`.
- `seek_visual(seconds: float)` : place le visuel à cet instant et le fige ; pas de signal émis par ce saut. Pour reprendre, rappeler play/set_state.
- `release()` : cache et désactive le traitement, sans supprimer le nœud ; réutilisable par play.
- Signal `finished(state: StringName)` : émis une seule fois à la fin visuelle d'enter, exit ou cooldown. **Aucun changement automatique d'état** : le code appelant décide de repasser à active ou cooldown. Ce signal n'accorde aucun droit de téléportation et ne termine pas une recharge de gameplay.

## Rendu

Active : cadre de cristal facetté, vitre sombre ondulante, lignes de reflet, sommet en losange. Cooldown : vitre éteinte, cadre assombri, structure toujours identifiable. Enter : rubans en convergence et éclats vers la vitre. Exit : torsion ouverte et éclats sortants. Après duration, les rubans et éclats sont éteints, mais l'état reste enter/exit jusqu'à intervention du code appelant.

Un seul CanvasItem, aucune allocation de nœud par particule. Transit plafonné à **24 fragments**, trois rubans de 18 sommets, fond sombre local et alpha limité ; aucun grand cercle lumineux. Les états sont des effets graphiques de proposition à valider sur un combat réel ; aucune performance en partie n'est revendiquée par ce contrat.

## Intégration attendue de Claude

Instancier un nœud par emplacement, positionner son pied, attribuer le même tint aux deux jumeaux. Appeler enter/exit aux événements décidés par le jeu et cooldown lorsque le miroir doit sembler indisponible. Réactiver explicitement active lorsque la logique autorise de nouveau le portail. Aucun src/, data/ ni manifeste n'est fourni ici.
