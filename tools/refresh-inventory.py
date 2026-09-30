#!/usr/bin/env python3
"""Mechanically refresh native integrity while retaining frozen source hashes."""
import hashlib
import json
from pathlib import Path

root=Path(__file__).resolve().parents[1]
source=root.parent/'claude-bootstrap-protocol'
file=root/'docs/source-inventory.json'
data=json.loads(file.read_text())
for row in data['assets']:
    row['destination']=row['destination'].replace('.claude/mcp/','.codex/mcp/')
    path=root/row['destination']
    if path.is_file(): row['native_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
    if row['destination']=='native-hooks-and-tui':
        row['native_replacements']=['assets/native/session-context.py','lib/native-config.py','docs/opt-in-configs.md']
for name in ('Starting-workflow.md','prompts/grill-mission-packs.md'):
    row={'source':name,'destination':name,'source_sha256':hashlib.sha256((source/name).read_bytes()).hexdigest(),
         'native_sha256':hashlib.sha256((root/name).read_bytes()).hexdigest(),'acceptance':'workflow-parity-and-native-runtime-scan'}
    data['assets']=[r for r in data['assets'] if r['source']!=name]+[row]
data['native_additions']=['minion','navigator','reviewer','worker','guided wizard','command setup/removal','hash-tracked updates']
data['exclusions']=['source Git and Beads history','credentials and caches','source-specific planning history',
                    'upstream README and generated manifests replaced by native documentation/manifests']
file.write_text(json.dumps(data,indent=2)+'\n')
print(f'Refreshed {len(data["assets"])} source mappings and native hashes.')
