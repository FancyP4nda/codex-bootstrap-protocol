#!/usr/bin/env python3
"""Native payload, manifest, mirror and inventory integrity checks."""
import hashlib
import json
from pathlib import Path
import re
import sys
import tomllib


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def installed(kit, skills, codex):
    failures = 0
    for source in (kit/'assets/global/.agents/skills').iterdir():
        if not source.is_dir():
            continue
        target = skills/source.name
        expected = [p for p in source.rglob('*') if p.is_file()]
        state = 'current'
        for p in expected:
            dest = target/p.relative_to(source)
            if not dest.is_file():
                state = 'missing'; break
            if dest.is_symlink() or sha(dest) != sha(p):
                state = 'differing'
        print(f'global skill {source.name}: {state}')
    for p in (kit/'assets/global/.codex/agents').glob('*.toml'):
        dest = codex/'agents'/p.name
        print(f'global agent {p.stem}: '+('missing' if not dest.exists() else 'current' if sha(p) == sha(dest) else 'differing'))
    return failures


def check(root):
    manifests = [(root/'assets/scaffold', root/'assets/scaffold/manifest.txt')]
    manifests += [(root/'assets/global', root/'assets/global/manifest.txt')]
    manifests += [(p/'scaffold', p/'manifest.txt') for p in (root/'assets/packs').iterdir()]
    for base, manifest in manifests:
        seen = set()
        for line in manifest.read_text().splitlines():
            if not line or line.startswith('#'):
                continue
            fields = line.split('\t')
            assert len(fields) == 4, (manifest, line)
            kind, rel, action, _ = fields
            assert rel not in seen and '..' not in Path(rel).parts and not Path(rel).is_absolute(), rel
            seen.add(rel)
            if kind == 'file':
                assert (base/rel).is_file() and action == 'copy', rel
            else:
                assert kind == 'transient_dir' and action == 'ensure_ignored', line
        shipped = {p.relative_to(base).as_posix() for p in base.rglob('*') if p.is_file() and p.name != 'manifest.txt' and '__pycache__' not in p.parts and p.suffix != '.pyc'}
        if base == root/'assets/scaffold':
            shipped.discard('.codex/config.toml')
        if base == root/'assets/global':
            shipped -= {'skills-manifest.txt', 'agents-manifest.txt'}
        assert shipped <= seen, (manifest, shipped-seen)
    names = []
    for p in (root/'assets').rglob('SKILL.md'):
        text = p.read_text()
        match = re.match(r'---\n([\s\S]*?)\n---\n', text)
        assert match, p
        header = match.group(1)
        name = re.search(r'^name:\s*(.+)$', header, re.M).group(1).strip('"\'')
        assert name == p.parent.name, p
        assert re.search(r'^description:\s*\S', header, re.M), p
        assert not re.search(r'^allowed-tools:|^model:', header, re.M), p
        names.append(name)
        for rel in re.findall(r'\]\(([^)#]+)(?:#[^)]*)?\)', text):
            if not re.match(r'https?://|/|~|\$|<', rel) and not any(c in rel for c in '* '):
                assert (p.parent/rel).exists(), (p, rel)
    assert len(names) == len(set(names)), 'duplicate canonical skill names'
    agents = []
    for p in (root/'assets').rglob('*.toml'):
        data = tomllib.loads(p.read_text())
        if '/agents/' in str(p):
            assert all(isinstance(data.get(k), str) and data[k] for k in ('name', 'description', 'developer_instructions')), p
            assert 'model' not in data, p
            agents.append(data['name'])
    assert len(agents) == len(set(agents)), 'duplicate canonical agents'
    for base in (root/'assets/global/.agents', root/'assets/global/.codex/agents', root/'assets/scaffold/.agents/templates'):
        for p in base.rglob('*'):
            if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc':
                payload=root/'assets/scaffold' if base==root/'assets/scaffold/.agents/templates' else root/'assets/global'
                dest = root/p.relative_to(payload)
                assert dest.is_file() and p.read_bytes() == dest.read_bytes(), f'kit mirror drift: {dest}'
    inventory = json.loads((root/'docs/source-inventory.json').read_text())
    assert inventory['source_commit'] == 'f89f7f3dffb1150fa7df30b180b397dd25a711f9'
    for row in inventory['assets']:
        assert row.get('acceptance'), row
        path = row['destination']
        if path.startswith('assets/'):
            assert (root/path).exists(), f'inventory destination missing: {path}'
        if 'native_sha256' in row:
            assert sha(root/path) == row['native_sha256'], f'current inventory hash drift: {path}'
    for p in (root/'assets').rglob('*'):
        if not p.is_file() or p.name == 'LICENSE' or '__pycache__' in p.parts or p.suffix == '.pyc':
            continue
        text = p.read_text(errors='replace')
        assert not re.search(r'--dangerously-bypass-(?:approvals-and-sandbox|hook-trust)|bypassPermissions', text), p
        assert not re.search(r'\.claude/(?:skills|agents|docs|tmp)', text), p
    print(f'Native payload: {len(names)} skills, {len(agents)} agents; manifests, references, mirrors and safety scan passed.')


if __name__ == '__main__':
    if sys.argv[1:2] == ['--installed']:
        sys.exit(installed(*(Path(p) for p in sys.argv[2:])))
    check(Path(__file__).resolve().parents[1])
