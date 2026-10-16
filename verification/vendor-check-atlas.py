#!/usr/bin/env python3
"""Atlas pack fidelity check: the vendored skills equal upstream at the pins apart from the recorded patches.

  vendor-check-atlas.py [--skills DIR]            offline: reverse-apply each recorded diff to the
                                                   vendored file and compare the result with the
                                                   recorded upstream hash
  vendor-check-atlas.py --network [--skills DIR]  also fetch both pins and compare every other
                                                   vendored file with upstream, byte for byte

Archify's tree is the Claude kit's vendored tree (same pin); Graphify's SKILL.md is upstream's
graphify/skill-agents.md and its references are graphify/skills/agents/references/. The patches are
recorded as unified diffs under verification/vendor-check-atlas-patches/. The table below is kept here,
independent of pack.yaml, so a pack.yaml edit cannot widen what passes. Exit 0 on success, 1 on a
mismatch.
"""
import argparse
import hashlib
import io
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

KIT = Path(__file__).resolve().parents[1]
PATCHES = KIT/'verification/vendor-check-atlas-patches'
PINS = {'archify': ('tt-a1i/archify', '1c2b42d660e4a7571813fb43839c79e3e9ca7720'),
        'graphify': ('Graphify-Labs/graphify', 'b4e6307bf170f27e0cb888c03f4af9308d531a42')}
# vendored path (under skills/) -> (component, upstream path, sha256 of the upstream file at the pin)
PATCHED = {
    'archify/SKILL.md': ('archify', 'archify/SKILL.md', '55c126d68c1fbef114ccdef8dd0e7f046419dc9203ac7f6dab1728f6bab3ca71'),
    'archify/renderers/shared/brand-marks.mjs': ('archify', 'archify/renderers/shared/brand-marks.mjs', '87436fa956c98dc9bbabf826d5f254587c1b3e7a829883f4098e04c62f4b5345'),
    'archify/bin/visual-check.mjs': ('archify', 'archify/bin/visual-check.mjs', 'dfec28e3e6666c835cb60f4d34ccabc8a831915dbbfe363de8cffe11de6fae81'),
    'graphify/SKILL.md': ('graphify', 'graphify/skill-agents.md', '0d62bc6222066a316625025eeaed8c9c5f8da81357a01218331b74c253261260'),
    'graphify/references/extraction-spec.md': ('graphify', 'graphify/skills/agents/references/extraction-spec.md', 'f72a6d2dfa67446f06f27a8f0053af1adc8d53b02e393c8472045f6740c6183e'),
    'graphify/references/query.md': ('graphify', 'graphify/skills/agents/references/query.md', 'e563ddcb1e155aa230f107e5ef9380bc1249c5cd8241128de7ed8a7bd9c20cf5'),
    'graphify/references/update.md': ('graphify', 'graphify/skills/agents/references/update.md', 'fc28570b2dacbc397728c9f10dbc5532c028c1f1a3df67ea0242fccdb61b4af9'),
}
# Archify's release subset leaves these three upstream files out (package-lock.json and two generators).
ARCHIFY_LEFT_OUT = {'archify/package-lock.json', 'archify/scripts/generate-brand-marks.mjs', 'archify/scripts/generate-validators.mjs'}
GRAPHIFY_LICENSES = ('LICENSE', 'LICENSE-MIT', 'NOTICE')
GRAPHIFY_REFERENCES = ('extraction-spec.md', 'query.md', 'update.md')
PACK_AUTHORED = {'archify/agents/openai.yaml', 'graphify/agents/openai.yaml', 'graphify/atlas-preflight.sh', 'graphify/atlas-graphify.sh'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def reverse_apply(vendored, diff):
    """The file the diff turns into `vendored`, or None when it does not apply exactly (no offset, no fuzz)."""
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp)/'upstream'
        run = subprocess.run(['patch', '-R', '--no-backup-if-mismatch', '-F0', '-o', str(out), str(vendored), '-i', str(diff)],
                             capture_output=True, text=True)
        if run.returncode != 0 or 'offset' in run.stdout or 'fuzz' in run.stdout:
            return None
        return out.read_bytes()


def check_offline(skills, problems):
    for rel, (_, _, upstream_sha) in PATCHED.items():
        vendored, diff = skills/rel, PATCHES/(rel + '.diff')
        if not vendored.is_file() or not diff.is_file():
            problems.append(f'{rel}: missing the vendored file or its recorded diff')
            continue
        upstream = reverse_apply(vendored, diff)
        if upstream is None:
            problems.append(f'{rel}: the recorded diff does not reverse-apply exactly')
        elif sha(upstream) != upstream_sha:
            problems.append(f'{rel}: reversing the recorded diff does not give the pinned upstream file')


def fetch_tree(component, into):
    repo, commit = PINS[component]
    with urllib.request.urlopen(f'https://codeload.github.com/{repo}/tar.gz/{commit}', timeout=120) as response:
        data = response.read()
    with tarfile.open(fileobj=io.BytesIO(data)) as tar:
        tar.extractall(into, filter='data')
    (root,) = [p for p in Path(into).iterdir() if p.is_dir()]
    return root


def check_network(skills, problems):
    with tempfile.TemporaryDirectory() as tmp:
        trees = {}
        for component in PINS:
            where = Path(tmp)/component
            where.mkdir()
            trees[component] = fetch_tree(component, where)
        for rel, (component, path, upstream_sha) in PATCHED.items():
            if sha((trees[component]/path).read_bytes()) != upstream_sha:
                problems.append(f'{rel}: upstream {path} at the pin is not the recorded file')
        archify = trees['archify']
        expected = {p.relative_to(archify).as_posix() for p in (archify/'archify').rglob('*') if p.is_file()} - ARCHIFY_LEFT_OUT
        present = {p.relative_to(skills).as_posix() for p in (skills/'archify').rglob('*') if p.is_file()} - PACK_AUTHORED
        for extra in sorted(present - expected):
            problems.append(f'{extra}: vendored but not in the upstream release subset')
        for missing in sorted(expected - present):
            problems.append(f'{missing}: in the upstream release subset but not vendored')
        for rel in sorted(expected & present):
            if rel not in PATCHED and (skills/rel).read_bytes() != (archify/rel).read_bytes():
                problems.append(f'{rel}: differs from upstream and has no recorded patch')
        graphify = trees['graphify']
        for name in GRAPHIFY_LICENSES:
            if (skills/'graphify'/name).read_bytes() != (graphify/name).read_bytes():
                problems.append(f'graphify/{name}: differs from upstream')
        refs = sorted(p.name for p in (skills/'graphify/references').iterdir())
        if refs != sorted(GRAPHIFY_REFERENCES):
            problems.append(f'graphify/references holds {refs}; only the three supported files may be vendored')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--network', action='store_true', help='also compare every other vendored file with the pinned upstream')
    parser.add_argument('--skills', type=Path, default=KIT/'assets/packs/atlas/global/.agents/skills')
    args = parser.parse_args()
    problems = []
    check_offline(args.skills, problems)
    if args.network:
        check_network(args.skills, problems)
    for problem in problems:
        print('FAIL:', problem)
    if problems:
        return 1
    print('PASS: the recorded patches reverse-apply to the pinned upstream files' + ('; every other vendored file equals upstream.' if args.network else '.'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
