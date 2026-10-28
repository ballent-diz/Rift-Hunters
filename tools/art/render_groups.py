"""Rendre les 19 groupes depuis un snapshot déjà préparé, sans réimport répétitif."""
from pathlib import Path
import argparse, subprocess, sys

here = Path(__file__).resolve().parent
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--work-dir', default=str(here))
p.add_argument('--project', default='after-project')
p.add_argument('--output', default='tous-apres')
p.add_argument('--start', type=int, default=0)
p.add_argument('--count', type=int, default=19)
p.add_argument('--frames', type=int, default=16)
p.add_argument('--tag', default='APRES')
p.add_argument('--renderer', default='gl_compatibility')
args = p.parse_args()
for group in range(args.start, args.start + args.count):
    command = [sys.executable, str(here / 'run_context.py'), '--reuse', '--short-path',
               '--work-dir=' + args.work_dir, '--project=' + args.project,
               '--output=' + args.output + f'/g{group:02d}', '--group=' + str(group),
               '--frames=' + str(args.frames), '--tag=' + args.tag, '--renderer=' + args.renderer]
    subprocess.run(command, check=True)
