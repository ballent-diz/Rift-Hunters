"""Copie isolée du banc d'aperçu : aucun fichier du worktree source n'est modifié."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, tempfile
from PIL import Image

Image.MAX_IMAGE_PIXELS = None
HERE = Path(__file__).resolve().parent
WORKSPACE = HERE.parent
REPO_ROOT = HERE.parents[1] if (HERE.parents[1] / 'assets/asset_manifest.json').exists() else None
DEFAULT_SOURCE = REPO_ROOT or (WORKSPACE / 'Rift-Hunters-work78')
GODOT = os.environ.get('GODOT_BIN') or shutil.which('godot') or 'C:/Users/petit/Downloads/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe'
BASELINE = '1d41723b2e6af94f33d6353b9c4443e3dae324c9'


def git(repo, *args):
    return subprocess.check_output(['git', '-c', 'safe.directory=' + str(repo), *args], cwd=repo)


def prepare(repo, project, baseline):
    project.mkdir(parents=True, exist_ok=True)
    folders = ['assets/vfx/enemies/chapter3', 'assets/vfx/enemies/chapter4', 'assets/vfx/bosses/glauquemire']
    copied = {}
    if baseline:
        names = git(repo, 'ls-tree', '-r', '--name-only', BASELINE, '--', *folders).decode().splitlines()
        for name in names:
            data = git(repo, 'show', BASELINE + ':' + name)
            p = project / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(data)
            copied[name] = hashlib.sha256(data).hexdigest()
    else:
        for folder in folders:
            for src in (repo / folder).rglob('*'):
                if src.is_file() and not src.name.endswith('.import'):
                    p = project / src.relative_to(repo)
                    p.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(src, p)
                    copied[str(src.relative_to(repo)).replace('\\', '/')] = hashlib.sha256(src.read_bytes()).hexdigest()
    # Dépendances présentes dans main, sans importer tout le jeu.
    for folder in ['assets/vfx/hunter', 'assets/vfx/echoes']:
        for src in (repo / folder).rglob('*'):
            if src.is_file() and not src.name.endswith('.import'):
                p = project / src.relative_to(repo)
                p.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(src, p)
    manifest = json.loads((repo / 'assets/asset_manifest.json').read_text(encoding='utf-8'))['entries']
    sprites = {}
    for key in ['player.hunter', 'monster.mossback']:
        entry = manifest[key]
        sprites[key] = {k: entry[k] for k in ['sheet', 'cell', 'anchor', 'scale']}
        name = entry['sheet'].removeprefix('res://')
        p = project / name
        p.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(repo / name, p)
    (project / 'context_sprites.json').write_text(json.dumps(sprites, indent=2) + '\n', encoding='utf-8')
    # Un recadrage documentaire, à la densité du monde ; le zoom Godot sera 4/3.
    tile = Image.open(repo / 'assets/environments/root_mangrove/map.webp').convert('RGB')
    tile.crop((round(350 * 2.25), round(1000 * 2.25), round(1310 * 2.25), round(1540 * 2.25))).resize((960, 540), Image.Resampling.LANCZOS).save(project / 'context_ground.webp', lossless=True)
    shutil.copyfile(HERE / 'context_showcase.gd', project / 'context_showcase.gd')
    (project / 'project.godot').write_text('[application]\nconfig/name="PR78 - apercu technique"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=720\nwindow/vsync/vsync_mode=0\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/default_filters/use_nearest_mipmap_filter=false\n', encoding='utf-8')
    (project / 'snapshot.json').write_text(json.dumps({'baseline_commit': BASELINE if baseline else None, 'source_worktree': str(repo), 'effect_files_sha256': copied, 'ground_world_crop': [350, 1000, 960, 540], 'ground_source_density': 2.25}, indent=2) + '\n', encoding='utf-8')
    tool = project / 'tools/art/check_marsh_vfx.gd'
    tool.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(repo / 'tools/art/check_marsh_vfx.gd', tool)


def run(args):
    repo = Path(args.source).resolve()
    godot = Path(args.godot).resolve()
    if not godot.is_file():
        raise FileNotFoundError('Indiquer le binaire Godot avec --godot ou GODOT_BIN')
    work_dir = Path(args.work_dir).resolve()
    work_dir.mkdir(parents=True, exist_ok=True)
    project = (work_dir / args.project).resolve()
    if not project.is_relative_to(work_dir):
        raise ValueError('Le projet isolé doit rester dans le dossier --work-dir')
    if not args.reuse and project.name == 'baseline-project' and not args.baseline:
        raise ValueError('Pour préserver AVANT, choisir --project=after-project ou --baseline')
    if not args.reuse:
        prepare(repo, project, args.baseline)
    out = (work_dir / args.output).resolve()
    if not out.is_relative_to(work_dir):
        raise ValueError('Les sorties doivent rester dans le dossier --work-dir')
    out.mkdir(parents=True, exist_ok=True)
    snapshot = project
    env = os.environ.copy()
    needs_import = not args.reuse or not (project / '.godot/imported').exists()
    if args.short_path:
        signature = hashlib.sha256((snapshot / 'snapshot.json').read_bytes() + (HERE / 'context_showcase.gd').read_bytes()).hexdigest()
        pointer = work_dir / ('short_runtime_' + snapshot.name + '.json')
        cache = json.loads(pointer.read_text(encoding='utf-8')) if pointer.exists() else {}
        if cache.get('signature') == signature and Path(cache.get('project', '')).is_dir():
            project = Path(cache['project'])
            temp = project.parent
            needs_import = not (project / '.godot/imported').exists()
        else:
            temp = Path(tempfile.mkdtemp(prefix='rh78-'))
            project = temp / 'p'
            shutil.copytree(snapshot, project, ignore=shutil.ignore_patterns('.godot'))
            shutil.copyfile(HERE / 'context_showcase.gd', project / 'context_showcase.gd')
            config = project / 'project.godot'
            config.write_text(config.read_text(encoding='utf-8').replace('config/name="PR78 - apercu technique"', 'config/name="rh78"'), encoding='utf-8')
            pointer.write_text(json.dumps({'signature': signature, 'project': str(project)}, indent=2) + '\n', encoding='utf-8')
            needs_import = True
        env.update(APPDATA=str(temp / 'a'), LOCALAPPDATA=str(temp / 'l'))
    else:
        env.update(APPDATA=str(work_dir / 'profile/roaming'), LOCALAPPDATA=str(work_dir / 'profile/local'))
    (out / 'run_environment.json').write_text(json.dumps({'snapshot_project': str(snapshot), 'render_project': str(project), 'renderer': args.renderer, 'short_path': args.short_path, 'effect_script_sha256': hashlib.sha256((project / 'assets/vfx/enemies/chapter3/enemy_effect.gd').read_bytes()).hexdigest()}, indent=2) + '\n', encoding='utf-8')
    options = {'env': env, 'cwd': project, 'check': True}
    if os.name == 'nt':
        options['creationflags'] = subprocess.CREATE_NO_WINDOW
    if needs_import:
        with (out / 'import.log').open('w', encoding='utf-8') as f:
            subprocess.run([str(godot), '--headless', '--import', '--path', str(project)], stdout=f, stderr=subprocess.STDOUT, **options)
    else:
        (out / 'import.log').write_text('Import déjà disponible pour ce snapshot inchangé ; non répété.\n', encoding='utf-8')
    if args.check_only:
        with (out / 'check.log').open('w', encoding='utf-8') as f:
            subprocess.run([str(godot), '--headless', '--path', str(project), '--script', 'res://tools/art/check_marsh_vfx.gd'], stdout=f, stderr=subprocess.STDOUT, **options)
        print(out)
        return
    if args.prepare_only:
        print(project)
        return
    command = [str(godot), '--path', str(project), '--resolution', '1280x720', '--rendering-method', args.renderer, '--audio-driver', 'Dummy', '--script', 'res://context_showcase.gd', '--', '--out=' + str(out), '--group=' + str(args.group), '--frames=' + str(args.frames), '--single=' + str(args.single), '--tag=' + args.tag, '--mode=' + args.mode]
    with (out / 'render.log').open('w', encoding='utf-8') as f:
        subprocess.run(command, stdout=f, stderr=subprocess.STDOUT, **options)
    images = sorted(out.glob('g*_f*.png'))
    if images:
        frames = [Image.open(p).convert('RGB') for p in images]
        frames[0].save(out / 'apercu.webp', save_all=True, append_images=frames[1:], duration=70, loop=0, quality=90, method=5)
    print(out)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', default=str(DEFAULT_SOURCE))
    p.add_argument('--godot', default=str(GODOT), help='Binaire Godot ; sinon GODOT_BIN, PATH ou installation Windows locale')
    p.add_argument('--work-dir', default=str(HERE if REPO_ROOT is None else Path(tempfile.gettempdir()) / 'rift_hunters_marsh_context'), help='Dossier externe pour projets isolés et sorties, jamais des assets à versionner')
    p.add_argument('--project', default='baseline-project')
    p.add_argument('--output', default='baseline-sample')
    p.add_argument('--baseline', action='store_true')
    p.add_argument('--reuse', action='store_true', help='Ne pas recopier les sources, conserver le snapshot existant')
    p.add_argument('--prepare-only', action='store_true')
    p.add_argument('--check-only', action='store_true', help='Import puis contrôle ciblé des 56 scènes, sans capture')
    p.add_argument('--group', type=int, default=0)
    p.add_argument('--single', type=int, default=-1)
    p.add_argument('--frames', type=int, default=16)
    p.add_argument('--tag', default='AVANT')
    p.add_argument('--mode', choices=['capture', 'load'], default='capture')
    p.add_argument('--renderer', choices=['gl_compatibility', 'mobile', 'forward_plus'], default='mobile')
    p.add_argument('--short-path', action='store_true', help='Copie de rendu dans un nouveau TEMP court pour éviter MAX_PATH Windows ; snapshot conservé')
    run(p.parse_args())
