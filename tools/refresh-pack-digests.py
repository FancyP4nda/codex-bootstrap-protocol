#!/usr/bin/env python3
"""Refresh integrity only; never invent airlock evidence or release stamps."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def digest(base, paths):
    lines = []
    for path in sorted(set(paths), key=lambda p: p.as_posix().encode()):
        lines.append(hashlib.sha256((base/path).read_bytes()).hexdigest()+'  '+path.as_posix()+'\n')
    return hashlib.sha256(''.join(lines).encode()).hexdigest()


integrity = {}
for pack in ('falcon', 'herald', 'web-design'):
    root = ROOT/'assets/packs'/pack
    metadata = root/'pack.yaml'
    text = metadata.read_text()
    if pack == 'web-design':
        for skill in ('impeccable', 'taste-skill'):
            rel = Path('.agents/skills')/skill
            files = [p.relative_to(root/'scaffold') for p in (root/'scaffold'/rel).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc']
            value = digest(root/'scaffold', files)
            pattern = r'(- id: '+re.escape(skill)+r'\n[\s\S]*?vendored_tree_digest: )"[a-f0-9]+"'
            text, count = re.subn(pattern, lambda m: m.group(1)+'"'+value+'"', text)
            if count != 1:
                raise ValueError(f'missing component digest: {skill}')
        metadata.write_text(text)
    files = [Path('manifest.txt'), Path('pack.yaml')]
    files += [p.relative_to(root) for p in (root/'scaffold').rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc']
    integrity[pack] = {'sha256': digest(root, files),
                       'validation': 'unverified: evidence fields remain null' if pack == 'web-design' else 'first-party native adaptation'}
(ROOT/'docs/pack-integrity.json').write_text(json.dumps(integrity, indent=2)+'\n')
print('Refreshed migration digests; no release stamp written.')
