#!/usr/bin/env python3
"""Prépare les 30 illustrations manquantes, leurs prompts et les recettes du pipeline commun."""
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / 'assets/concepts/incoming/ui.hunter_passive_icons'
SUBJECTS = {
    'combat_training': 'trunk|A well-worn ivory katana striking a compact wooden practice target; a single clear impact spark.',
    'trunk_vigor': 'trunk|A stout silver breastplate protecting one bright warm ivory heart, powerful upright silhouette.',
    'combat_phantom_step': 'trunk|One samurai boot stepping through a silver translucent afterimage, a short curved ivory motion trail.',
    'combat_last_breath': 'trunk|One battered silver mask with a narrow crack, a last small ivory flame still burning inside.',
    'blade_honed_edge': 'blade|One polished katana edge being sharpened by a dark whetstone, a sharp amber-white glint at contact.',
    'combat_rift_brawler': 'blade|One armored fist intercepting an incoming dark shard and sending three strong amber impact rays outward.',
    'combat_shattering_dash': 'blade|One forward samurai boot landing and shattering a small basalt slab, sharp amber cracks and a short motion streak.',
    'combat_marksman': 'prism|One long cyan-white crystal bolt piercing two small dark armored plates aligned in a diagonal.',
    'spec_chain_detonation': 'prism|Three cyan diamond marks connected by a zigzag, the central diamond detonating into large angular white fragments.',
    'spec_prismatic_resonance': 'prism|Three nested cyan crystal diamonds resonating around a bright white central diamond, bold compact symmetry.',
    'spec_pyromancer': 'prism|One long cyan crystal arrow with a clear orange flame wrapped around its head; cyan shaft and ivory-orange flame contrast.',
    'abyss_depths': 'abyss|One dark basalt plate with a deep vertical pale lavender fracture, two layered fragments showing its depth.',
    'spec_deep_breach': 'abyss|Two heavy basalt halves torn apart by a jagged ivory-lavender chasm, a bright sharp center and dark side planes.',
    'spec_gravitationist': 'abyss|A compact dark gravity core with an ivory-lavender rim pulling three chunky stone fragments inward; short inward curves.',
    'echoes_bonds': 'bond|Two powerful interlocking silver-jade links joining a hunter blade and a stylized companion claw.',
    'echoes_lone_hunter': 'bond|One lone samurai hunter bust with a jade shoulder guard and upright ivory blade, strong solitary silhouette.',
    'echoes_pack_leader': 'bond|Three distinct small companion heads beneath one jade and ivory command crest, grouped triangular silhouette.',
    'echoes_sharpened': 'bond|One companion claw and an ivory lightning-shaped technique spark inside a broken jade refresh arc, clear dominant claw.',
    'echoes_third_seal': 'research|Three separate jade wax seals held by one copper clasp on a small dark research scroll; three big distinct shapes.',
    'echoes_veteran': 'research|A copper veteran medal with two broad silver chevrons above one jade companion paw emblem.',
    'research_banish': 'research|One copper research card being crossed and swept away by a crisp jade diagonal slash; no letters or symbols resembling text.',
    'research_early_evolution': 'research|A copper specimen cradle holding a jade chrysalis splitting to reveal one luminous ivory wing.',
    'research_fourth_option': 'research|Four clearly separated ivory card faces fanned from a copper card holder, each with a simple jade jewel and no writing.',
    'research_rift_study': 'research|One open copper-bound research book with a large jade crystal diagram rising physically from its center, no writing.',
    'research_unstable': 'research|One copper alchemical flask containing two swirling jade crystal growths and a small ivory spark, bold bottle silhouette.',
    'explore_essence_sense': 'exploration|One brass compass whose ivory needle points toward a single large luminous jade essence droplet.',
    'explore_magnet': 'exploration|A broad brass horseshoe magnet drawing three chunky jade essence fragments inward with short ivory trails.',
    'explore_prospector': 'exploration|One brass pickaxe striking a large jade crystal cluster on a small dark rock, one ivory contact glint.',
    'explore_sealed_chests': 'exploration|One compact dark wood and brass treasure chest with a prominent jade seal and ivory light escaping from its lid.',
    'explore_starting_relic': 'exploration|One brass expedition satchel open around a prominent jade relic talisman, a single ivory ribbon of light.',
}
PALETTES = {
    'trunk': 'warm ivory, weathered silver, midnight blue shadows',
    'blade': 'amber gold, warm ivory, dark bronze, midnight blue shadows',
    'prism': 'luminous cyan, icy white, silver, midnight blue shadows',
    'abyss': 'pale lavender, cold ivory, deep indigo, dark basalt',
    'bond': 'jade green, ivory, silver, dark teal shadows',
    'research': 'antique copper instruments, jade details, ivory, midnight blue shadows',
    'exploration': 'antique brass expedition equipment, jade crystals, ivory, dark teal shadows',
}


def main():
    rows = {r[0]: r for r in csv.reader((ROOT / 'i18n/strings.csv').open(encoding='utf-8-sig')) if r}
    template = json.loads((ROOT / 'assets/concepts/incoming/icon.hunter.cleaving_slash/job.json').read_text())
    CATALOG.mkdir(parents=True, exist_ok=True)
    entries = []
    markdown = ['# Trente icônes manquantes du Chasseur', '',
                'Génération intégrée imagegen, une image par icône. Images originales transparentes conservées ;',
                'import commun 512 px sans réduction de palette, sans contour ajouté, mipmaps activées.', '']
    for identity, description in SUBJECTS.items():
        family, subject = description.split('|')
        data = (ROOT / f'data/progression/skill_tree/{identity}.tres').read_text()
        name_key = re.search(r'name_key = "([^"]+)"', data)[1]
        desc_key = re.search(r'desc_key = "([^"]+)"', data)[1]
        prompt = (
            'Use case: stylized-concept. Asset: one Rift Hunters skill-tree icon, square 512 x 512. '
            'Crisp high-definition painted dark fantasy Japanese samurai game illustration, sculpted cel-shaded '
            'materials, sharp selective edges and restrained fine etched details; not blocky pixel art. '
            'One dominant centered silhouette filling 85 percent of the canvas with transparent margins. '
            'Read instantly when reduced to 48 pixels: broad masses, few separated secondary shapes, high contrast. '
            'No environment, floor, background plate, border, badge frame, text, letters, digits, UI, watermark, '
            'checkerboard pattern, bloom haze or magenta glow. Actual transparent alpha background. '
            'Top-left key light, deep blue-violet shadows, small luminous highlights. '
            f'Palette: {PALETTES[family]}. Subject: {subject} '
            'Keep the illustration elegant and cohesive with hand-painted action RPG spell icons, not a flat vector pictogram.'
        )
        folder = ROOT / f'assets/concepts/incoming/icon.hunter.{identity}'
        (folder / 'source').mkdir(parents=True, exist_ok=True)
        (folder / 'source/prompt.txt').write_text(prompt + '\n', encoding='utf-8')
        job = dict(template)
        job['visual_id'] = f'icon.hunter.{identity}'
        job['status'] = 'wip'
        (folder / 'job.json').write_text(json.dumps(job, indent=2) + '\n', encoding='utf-8')
        entry = dict(id=identity, visual_id=job['visual_id'], family=family,
                     name_fr=rows[name_key][1], meaning_fr=rows[desc_key][1], prompt=prompt,
                     source=str((folder / 'source/icon.png').relative_to(ROOT)).replace('\\', '/'))
        entries.append(entry)
        markdown += [f'## {identity} — {entry["name_fr"]}', '', entry['meaning_fr'], '', prompt, '']
    (CATALOG / 'prompts.json').write_text(json.dumps(entries, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    (CATALOG / 'PROMPTS.md').write_text('\n'.join(markdown), encoding='utf-8')
    print(f'{len(entries)} prompts et recettes prêts.')


if __name__ == '__main__':
    main()
