#!/usr/bin/env python3
"""Stage only deployable site files and a commit/hash manifest for GitHub Pages."""
import argparse, hashlib, json, shutil, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = ROOT / 'website'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('destination', type=Path)
args = parser.parse_args()
destination = args.destination.resolve()
if destination == SITE.resolve() or not destination.is_relative_to(ROOT.resolve()):
    parser.error('Use a new staging directory inside the repository, not website itself')
if destination.exists():
    parser.error('Destination already exists; refusing to overwrite')
files = sorted(p for p in SITE.rglob('*') if p.is_file() and
               (p.suffix in {'.html', '.css', '.png'} or p.name == 'release-status.json'))
destination.mkdir(parents=True)
checksums = {}
for source in files:
    relative = source.relative_to(SITE)
    target = destination / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    checksums[relative.as_posix()] = hashlib.sha256(target.read_bytes()).hexdigest()
(destination / '.nojekyll').write_text('')
(destination / 'robots.txt').write_text('User-agent: *\nDisallow: /\n')
for name in ['.nojekyll', 'robots.txt']:
    checksums[name] = hashlib.sha256((destination / name).read_bytes()).hexdigest()
manifest = {
    'schema': 1,
    'sourceCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
    'siteMode': 'public-development-preview',
    'installerPublicReady': False,
    'files': checksums,
}
(destination / 'deployment-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(f'Staged {len(checksums)} files plus deployment manifest in {destination}')
