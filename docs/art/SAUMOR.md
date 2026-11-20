# Saumor, le Dévoreur des Salines

Saumor termine le lot des Saumâtres. Sa carapace de sel forme une voûte et ses deux bras de basalte
portent le poids du corps. Sous la voûte, deux vantaux de cuivre protègent l'ouverture de son siphon.
Le cuivre patiné, les cordages et les croûtes ivoire reprennent les matières de la famille.

Les planches couvrent un combat à deux phases. En phase 1, Saumor fend les vantaux et se cale sur ses bras
pour aspirer le joueur. **L'Appel de la vanne** serait sa mécanique phare. Un abri solide
pourrait couper l'aspiration avant la fermeture des vantaux. La transition rompt leurs attaches
et laisse le siphon violet exposé. En phase 2, le corps change d'appui et l'ouverture est visible
dans chaque pose.

| Planche | Clips | Repère visuel |
| --- | --- | --- |
| A, 6 × 3 | `idle`, `move`, `attack` | Repos, marche, balayage d'un bras. |
| B, 6 × 2 | `gate_pull`, `shoulder_slam` | Aspiration, puis une frappe des deux bras dans l'autre clip. |
| C, 6 × 3 | `transform`, `phase2_idle`, `phase2_move` | Ouverture des vantaux, repos et marche avec siphon apparent. |
| D, 6 × 3 | `brine_sweep`, `core_burst`, `death` | Souffle de saumure, pulsation du siphon puis effondrement en carcasse. |

Les six poses d'un clip se lisent de gauche à droite. Les techniques ouvrent sur une préparation,
passent par une pose d'impact et reviennent à une position stable. Les zones d'aspiration, le souffle
et la pulsation seront des effets du moteur synchronisés avec ces poses. Les vantaux restent sur le corps.

`boss.saumor` regroupe les quatre planches dans un atlas unique. Les clips de repos tournent à 7 i/s,
les déplacements à 9 i/s et les actions à 10 i/s. L'échelle de manifeste est 0,5. Les cellules
mesurent 448 × 304 et les pieds s'alignent sur (224, 280). Les sources et leurs prompts ImageGen
sont conservés dans `assets/concepts/incoming/boss.saumor/source/`. C conserve la marche de sa première
passe et les deux premières rangées de sa retouche.

```sh
python3 tools/art/import_saumor.py --preview-dir <dossier>
```

[Comparaison des phases](../previews/saumor/saumor.webp) · [Revue animée des 11 clips](../previews/saumor/animations.gif)

Le banc Godot montre le boss avec le Veilleur et un Écho sur le décor du Temple des Marées,
au zoom 1,3333 du mode 2D. [Phase 1](../previews/saumor/phase_1.webp) · [Phase 2](../previews/saumor/phase_2.webp)

Les clips et l'identifiant sont prêts pour le raccordement. La signature, le comportement face aux abris,
l'équilibrage et la sélection des phases en partie restent à intégrer et à tester.
