#!/usr/bin/env python3
"""Génère docs/art_prompts.md : un prompt par visuel, cohérent avec la bible graphique.
Modifier les descriptions ici puis relancer : python3 tools/art/prompts.py"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "..", "docs", "art_prompts.md"))

STYLE = ("detailed 16-bit pixel art, crisp pixels, no anti-aliasing blur, dark 1-pixel outlines, limited palette with "
         "hue-shifted shading (cool violet shadows, warm amber highlights), main light from the top-left, thin violet rim "
         "light on the bottom-right edges, dark fantasy rift theme")
LAYOUT = ("{frames} frames in a single horizontal row, evenly spaced, the SAME character in every frame with identical "
          "proportions, colors and size, side view facing RIGHT with a slight top-down 3/4 angle, feet on the same baseline, "
          "solid flat pure green background (#00D648), no ground shadow, no text, no borders, no UI")
NEGATIVE = ("blurry, smooth gradients, painterly, 3d render, text, watermark, signature, frame borders, multiple different "
            "characters, perspective change between frames, cropped, background scenery, ground shadow")

ANIMS = {
    "player": [("idle", 6, "breathing idle loop"), ("move", 8, "running loop"), ("dash", 4, "quick forward dash with motion trail"),
               ("hurt", 3, "recoiling from a hit"), ("death", 8, "collapsing and fading into rift light")],
    "monster": [("idle", 8, "breathing idle loop"), ("move", 8, "walking or flying loop"),
                ("attack", 7, "basic attack: wind-up, strike, recover"), ("technique", 8, "special move, dramatic, with light effects")],
    "enemy": [("move", 6, "moving loop"), ("attack", 4, "attack wind-up and strike"), ("death", 6, "dying, dissolving into violet sparks")],
    "boss": [("idle", 6, "menacing idle loop"), ("move", 8, "slow heavy movement loop"), ("attack", 6, "main attack"),
             ("death", 8, "death, collapsing into a void implosion")],
}

ENTITIES = [
    ("player.hunter", "player", 64, "a hooded Rift Hunter: slim agile adventurer in a long midnight-blue cloak with cyan trim, "
     "glowing cyan visor slit under the hood, small glowing rift lantern at the belt, light leather armor"),
    # Échos
    ("monster.ashblade", "monster", 64, "Ashblade: an obsidian-plated predator quadruped, cracked black volcanic plates with glowing "
     "ember-orange veins, forelimbs ending in long serrated dark-steel blades, swept-back horns, segmented tail ending in a blade, "
     "glowing amber eye"),
    ("monster.ashblade.eclipse_blade", "monster", 64, "Eclipse Blade (evolution of Ashblade): same predator with deep violet-black "
     "plates, violet glowing veins, much longer crystal-cyan blades, a crescent-shaped dorsal fin"),
    ("monster.ashblade.pyrefang", "monster", 64, "Pyrefang (evolution of Ashblade): charred red-brown plates, a mane of roaring "
     "flames along the spine, brighter fire veins, smoldering blades"),
    ("monster.mossback", "monster", 64, "Mossback: a squat walking stone monolith golem covered with patches of glowing green "
     "lichen, two rune eyes glowing mint green, short pillar legs, ancient and gentle"),
    ("monster.mossback.monolith", "monster", 64, "Monolith (evolution of Mossback): a taller massive menhir golem, thick glowing "
     "lichen, golden runes carved on its body, imposing guardian stance"),
    ("monster.mossback.quakeback", "monster", 64, "Quakeback (evolution of Mossback): sandstone golem with amber light pouring from "
     "cracks, seismic plates on its back, stomping posture"),
    ("monster.glimmerwing", "monster", 64, "Glimmerwing: a moth made of prismatic glass, four translucent pale-blue wings with "
     "glowing light filaments, small luminous body, feathery antennae, hovering"),
    ("monster.glimmerwing.prismara", "monster", 64, "Prismara (evolution of Glimmerwing): larger rainbow-prism wings, small light "
     "shards orbiting around it"),
    ("monster.glimmerwing.dawnward", "monster", 64, "Dawnward (evolution of Glimmerwing): golden-white dawn moth with a warm halo, "
     "shield-shaped wings"),
    ("monster.glimmerwing.prismatic_eclipse", "monster", 64, "Prismatic Eclipse (secret evolution of Glimmerwing): dark violet glass "
     "moth with an eclipse ring halo, cyan-white glowing wing edges"),
    ("monster.thornweave", "monster", 64, "Thornweave: a small dryad-like creature made of thorny green vines, a closed flower bud "
     "head with one pink blossom, root legs, curling tendrils"),
    ("monster.thornweave.briar_queen", "monster", 64, "Briar Queen (evolution of Thornweave): taller vine queen with a crown of "
     "thorns and red roses, long whip-like vines"),
    ("monster.thornweave.blightbloom", "monster", 64, "Blightbloom (evolution of Thornweave): withered orange-brown vines with "
     "smoldering toxic flowers releasing embers"),
    ("monster.voltwisp", "monster", 64, "Voltwisp: a floating electric wisp, a crackling yellow orb of lightning with a comet tail, "
     "zigzag lightning face, sparks around it"),
    ("monster.voltwisp.stormarc", "monster", 64, "Stormarc (evolution of Voltwisp): small blue storm cloud body with branching "
     "lightning arms"),
    ("monster.voltwisp.thunderhead", "monster", 64, "Thunderhead (evolution of Voltwisp): heavy dark thundercloud with a golden "
     "lightning core"),
    ("monster.gloommaw", "monster", 64, "Gloommaw: a round shadowy violet beast that is mostly a huge mouth full of pale teeth, "
     "tiny glowing eyes, smoky tendrils instead of legs"),
    ("monster.gloommaw.abyssmaw", "monster", 64, "Abyssmaw (evolution of Gloommaw): larger abyssal maw with a swirling void inside "
     "its mouth"),
    ("monster.gloommaw.gorgeshade", "monster", 64, "Gorgeshade (evolution of Gloommaw): crimson-dark gluttonous shade with a bloated "
     "belly and dripping jaws"),
    ("monster.mirrorling", "monster", 64, "Mirrorling: a living floating hexagonal mirror shard, silver-blue faceted crystal with a "
     "reflective face and two small eyes, tiny shards hovering around it"),
    ("monster.mirrorling.prismward", "monster", 64, "Prismward (evolution of Mirrorling): larger shield-like mirror with prismatic "
     "rainbow edges"),
    ("monster.mirrorling.kaleidos", "monster", 64, "Kaleidos (evolution of Mirrorling): kaleidoscopic pink-and-teal multi-faceted "
     "crystal creature"),
    # Corrompus
    ("enemy.skitterling", "enemy", 48, "Skitterling: small corrupted insectoid crawler, dark purple carapace, six thin legs, two "
     "glowing magenta eyes"),
    ("enemy.husk", "enemy", 64, "Husk: heavy armored beetle-like creature with a domed violet shell made of thick plates, small head"),
    ("enemy.spitter", "enemy", 64, "Spitter: bulbous corrupted creature with a long tube-like mouth and glowing magenta sacs on "
     "its back"),
    ("enemy.lunger", "enemy", 64, "Lunger: sleek arrow-shaped corrupted predator covered in spikes, built for charging"),
    ("enemy.broodmother", "enemy", 64, "Broodmother: bloated corrupted mother creature carrying glowing magenta eggs on its back"),
    ("enemy.shade_stalker", "enemy", 64, "Shade Stalker: thin shadowy wraith, semi-transparent dark violet body, glowing pink eyes"),
    ("enemy.crystal_warden", "enemy", 64, "Crystal Warden: floating corrupted guardian made of blue crystal shards around a glowing "
     "core, protective aura"),
    # Dévoreurs
    ("boss.nebulorax", "boss", 320, "Nebulorax, the Devourer of Dimensions: colossal spiral of obsidian blade-scales and nebula "
     "tentacles around a glowing violet vortex eye (its weak heart), floating rift crystals, palette #1B1E33 #3A1670 #6A1FD0 "
     "#C040F0 #EBD6FA (see docs/concepts/bosses/nebulorax.md)"),
    ("boss.vorgranite", "boss", 320, "Vorgranite, the Hungry Mountain: colossal stone beast shaped like a walking mountain, amber "
     "magma light pouring from cracks, crystals growing on its back, huge jaw"),
]


def main():
    lines = ["# Prompts de génération d'images", "",
             "Généré par `tools/art/prompts.py` à partir de la bible graphique (`docs/ART_BIBLE.md`).", "",
             "## Méthode conseillée", "",
             "1. Générer d'abord une **image de référence** (personnage seul, pose de repos) avec le prompt « Référence ».",
             "2. Générer ensuite **chaque animation séparément** (une ligne de frames par image), en donnant l'image de référence "
             "au générateur (référence de personnage / image-to-image) pour garder la même créature.",
             "3. Déposer les images dans `assets/concepts/incoming/<identifiant>/` avec un `job.json` "
             "(modèle : `assets/concepts/incoming/README.md`), puis lancer l'import.",
             "4. Il n'est pas nécessaire d'avoir toutes les animations : celles qui manquent peuvent réutiliser une autre "
             "ligne (`aliases`).", "",
             f"**Style commun (à garder dans chaque prompt)** : {STYLE}.", "",
             f"**Prompt négatif (générateurs qui l'acceptent)** : {NEGATIVE}.", ""]
    for visual_id, category, size, description in ENTITIES:
        lines.append(f"## `{visual_id}`")
        lines.append("")
        lines.append(f"**Référence** : `Character reference sheet, {description}. Single character, full body, side view facing "
                     f"right, slight top-down 3/4 angle, {STYLE}, solid flat pure green background (#00D648), no text.`")
        lines.append("")
        for anim, frames, label in ANIMS[category]:
            layout = LAYOUT.format(frames=frames)
            lines.append(f"- **{anim}** ({frames} frames) : `Pixel art sprite sheet of {description}. Animation: {label}. "
                         f"{layout}. Each frame about {size}x{size} pixels. {STYLE}.`")
        lines.append("")
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("écrit :", OUT, f"({len(ENTITIES)} visuels)")


if __name__ == "__main__":
    main()
