# graphify reference: incremental update

> Modified by the codex-bootstrap atlas pack from Graphify v0.9.85 (Apache-2.0). The changes are listed in `references/atlas-pack-notes.md` in the agents directory (`~/.agents`).

Load this only when the user passed `--update`. A first-time full build never reads this file.

Start this flow with the block under `## Interpreter guard for subcommands` in `SKILL.md`, every time, even when Step 1 or an earlier flow ran it in this conversation: it checks the Graphify CLI against the pinned version and the output roots, and the blocks below read `graphify-out/.graphify_python` and `graphify-out/.graphify_root` only as this run wrote them, never as an earlier run or the repository left them. It empties `graphify-out/.graphify_values/`, so write the value files a block reads after it. Every block below takes the runner's `PATH` first (`PATH=$(... atlas-graphify.sh --path)`, which prints a refusal instead when the repository could supply graphify), and every Graphify operation runs through the runner, `atlas-graphify.sh`, with its values after the runner's `--`; if the guard or the runner prints a line, show it to the user exactly as printed and stop. A short value the user typed (a path, URL, flag or number) goes in a quoted heredoc (`<<'GRAPHIFY_VALUE_EOF'`), one line, whose body you fill in; free text (a question, an answer, node names, labels, a prompt) goes in a file you write with your file tool in `graphify-out/.graphify_values/` after the guard ran, never in a heredoc, since text taken from the repository or the graph could end one. Never write a value into a command line or into Python source.

## For --update (incremental re-extraction)

Use when you've added or modified files since the last run. Only re-extracts changed files - saves tokens and time.

```bash
export GRAPHIFY_NO_AUTO_REFRESH=1
export GIT_NO_LAZY_FETCH=1 GIT_PROTOCOL_FROM_USER=0 GIT_ALLOW_PROTOCOL=
PATH=$(/bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path) || { printf '%s\n' "$PATH"; exit 1; }
unset GRAPHIFY_OUT
"$(cat graphify-out/.graphify_python)" -I - <<'GRAPHIFY_PY'
import os
from pathlib import Path
ROOT = os.fsdecode(Path('graphify-out/.graphify_root').read_bytes())  # the scan root the guard recorded
import sys, json
from graphify.detect import detect_incremental, save_manifest
from pathlib import Path

from graphify.paths import out_path
from graphify.watch import _read_build_excludes, _read_build_gitignore
result = detect_incremental(Path(ROOT), extra_excludes=_read_build_excludes(out_path()), gitignore=_read_build_gitignore(out_path()))
new_total = result.get('new_total', 0)
print(json.dumps(result, indent=2, ensure_ascii=False))
Path('graphify-out/.graphify_incremental.json').write_text(json.dumps(result, ensure_ascii=False), encoding="utf-8")
deleted = list(result.get('deleted_files', []))
if new_total == 0 and not deleted:
    print('No files changed since last run. Nothing to update.')
    raise SystemExit(0)
if deleted:
    print(f'{len(deleted)} deleted file(s) to prune.')
if new_total > 0:
    print(f'{new_total} new/changed file(s) to re-extract.')
GRAPHIFY_PY
```

Then populate `.graphify_detect.json` so Steps 3A–6 (which read it unconditionally) see the right state for an incremental run. `files` carries the changed subset (drives Step 3A AST + Step 3B0 cache check on only what changed); `all_files` carries the full corpus for any step that needs corpus-wide context:

```bash
export GRAPHIFY_NO_AUTO_REFRESH=1
export GIT_NO_LAZY_FETCH=1 GIT_PROTOCOL_FROM_USER=0 GIT_ALLOW_PROTOCOL=
PATH=$(/bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path) || { printf '%s\n' "$PATH"; exit 1; }
"$(cat graphify-out/.graphify_python)" -I - <<'GRAPHIFY_PY'
import json
from pathlib import Path
r = json.loads(Path('graphify-out/.graphify_incremental.json').read_text(encoding="utf-8"))
Path('graphify-out/.graphify_detect.json').write_text(json.dumps({
    'files': r.get('new_files', {}),
    'all_files': r.get('files', {}),
    'total_files': r.get('new_total', 0),
    'total_words': r.get('total_words', 0),
    'skipped_sensitive': r.get('skipped_sensitive', []),
    'needs_graph': True,
}, ensure_ascii=False), encoding="utf-8")
GRAPHIFY_PY
```

If new files exist, first check whether all changed files are code files:

```bash
export GRAPHIFY_NO_AUTO_REFRESH=1
export GIT_NO_LAZY_FETCH=1 GIT_PROTOCOL_FROM_USER=0 GIT_ALLOW_PROTOCOL=
PATH=$(/bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path) || { printf '%s\n' "$PATH"; exit 1; }
"$(cat graphify-out/.graphify_python)" -I - <<'GRAPHIFY_PY'
import json
from pathlib import Path

result = json.loads(open('graphify-out/.graphify_incremental.json', encoding='utf-8').read()) if Path('graphify-out/.graphify_incremental.json').exists() else {}
code_exts = {'.py','.ts','.js','.go','.rs','.java','.cpp','.c','.rb','.swift','.kt','.cs','.scala','.php','.cc','.cxx','.hpp','.h','.kts','.lua','.toc','.f','.F','.f90','.F90','.f95','.F95','.f03','.F03','.f08','.F08'}
new_files = result.get('new_files', {})
all_changed = [f for files in new_files.values() for f in files]
code_only = all(Path(f).suffix.lower() in code_exts for f in all_changed)
print('code_only:', code_only)
GRAPHIFY_PY
```

If `code_only` is True: print `[graphify update] Code-only changes detected - skipping semantic extraction (no LLM needed)`, run only Step 3A (AST) on the changed files, dispatch no subagents but run Step 3B's fast path block (the empty semantic file), then run Step 3C, which writes this run's `graphify-out/.graphify_extract.json` from the AST result. Never merge an extraction file an earlier or interrupted run left behind. Then go to the merge and Steps 4–6.

If `code_only` is False (any changed file is a doc/paper/image/video): run the full Steps 3A–3C pipeline as normal. Step 3B sends only docs, papers and images to semantic extraction, so changed video and audio files are left out:

Not available in the atlas pack: video and audio transcription. The pack supports building, updating and querying the graph; to use video and audio transcription, run upstream Graphify by hand outside the kit (see "Running Graphify by hand" in references/atlas-pack-notes.md in the agents directory (`~/.agents`)).


If no new files exist (only deletions), write a fresh empty extraction, replacing any file an earlier run left, so the merge step can prune:

```bash
export GRAPHIFY_NO_AUTO_REFRESH=1
export GIT_NO_LAZY_FETCH=1 GIT_PROTOCOL_FROM_USER=0 GIT_ALLOW_PROTOCOL=
PATH=$(/bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path) || { printf '%s\n' "$PATH"; exit 1; }
echo '[graphify update] Only deletions -- creating empty extraction for merge.'
"$(cat graphify-out/.graphify_python)" -I - <<'GRAPHIFY_PY'
import json
from pathlib import Path
Path('graphify-out/.graphify_extract.json').write_text(json.dumps({'nodes':[],'edges':[],'hyperedges':[],'input_tokens':0,'output_tokens':0}), encoding='utf-8')
GRAPHIFY_PY
```


Then:

```bash
export GRAPHIFY_NO_AUTO_REFRESH=1
export GIT_NO_LAZY_FETCH=1 GIT_PROTOCOL_FROM_USER=0 GIT_ALLOW_PROTOCOL=
PATH=$(/bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path) || { printf '%s\n' "$PATH"; exit 1; }
unset GRAPHIFY_OUT
GRAPHIFY_DIRECTED=$(cat <<'GRAPHIFY_VALUE_EOF'
IS_DIRECTED
GRAPHIFY_VALUE_EOF
)
export GRAPHIFY_DIRECTED
"$(cat graphify-out/.graphify_python)" -I - <<'GRAPHIFY_PY'
import os
from pathlib import Path
DIRECTED = os.environ['GRAPHIFY_DIRECTED'] == 'True'
ROOT = os.fsdecode(Path('graphify-out/.graphify_root').read_bytes())  # the scan root the guard recorded
import json
from pathlib import Path
from graphify.build import build_merge

# Load new extraction and incremental state
new_extraction = json.loads(Path('graphify-out/.graphify_extract.json').read_text(encoding="utf-8"))
incremental = json.loads(Path('graphify-out/.graphify_incremental.json').read_text(encoding="utf-8"))
deleted = list(incremental.get('deleted_files', []))
# prune_sources is ONLY for genuinely DELETED files. Changed/re-extracted files are
# handled by build_merge's replace-on-re-extract (#1344): every source_file in
# new_chunks is dropped from the base before merge, so old/stale nodes don't survive.
# Do NOT add changed here: with root= passed, prune_set relativizes to the same base
# as the freshly merged nodes and would DELETE the re-extracted content (#1178 is moot
# now that replace — not the dedup pass — reconciles changed files).
prune = list(deleted) or None

# Use build_merge() — reads graph.json directly without NetworkX round-trip
# so edge direction (calls, implements, imports) is always preserved (#801).
# Pass root= so prune_sources (absolute paths from detect_incremental) are
# relativized to match the graph's relative source_file values; without it
# nothing is pruned and stale nodes accumulate on every update (#1361).
# directed=DIRECTED: from the GRAPHIFY_DIRECTED heredoc, True if --directed was given,
# else False. Without it a --directed --update silently rebuilds undirected and collapses
# reciprocal A<->B edges (#1392).
G = build_merge(
    [new_extraction],
    graph_path='graphify-out/graph.json',
    prune_sources=prune,
    root=ROOT,
    directed=DIRECTED,
)
print(f'[graphify update] Merged: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges')

# Write merged result back to .graphify_extract.json so Step 4 sees the full graph
merged_out = {
    'nodes': [{'id': n, **d} for n, d in G.nodes(data=True)],
    'edges': [
        # Explicit source/target last so they win over any stale attrs in d.
        {**{k: val for k, val in d.items() if k not in ('_src', '_tgt', 'source', 'target')},
         'source': d.get('_src', u), 'target': d.get('_tgt', v)}
        for u, v, d in G.edges(data=True)
    ],
    # G.graph["hyperedges"] holds hyperedges from both existing graph.json
    # and new_extraction (build_merge combines them). Falling back to
    # new_extraction only would silently drop prior-run hyperedges (#801).
    'hyperedges': list(G.graph.get('hyperedges', [])),
    'input_tokens': new_extraction.get('input_tokens', 0),
    'output_tokens': new_extraction.get('output_tokens', 0),
}
Path('graphify-out/.graphify_extract.json').write_text(json.dumps(merged_out, ensure_ascii=False), encoding="utf-8")
print(f'[graphify update] Merged extraction written ({len(merged_out["nodes"])} nodes, {len(merged_out["edges"])} edges)')

# The manifest that lets the next --update diff against today's state, not the
# prior run's baseline (prevents ghost-node reports on subsequent updates).
# Step 4 saves it, only after it has written graph.json: saved here, a graph
# that Step 4 refuses to write would leave the manifest ahead of graph.json and
# the next --update would find nothing to redo. root= matches the build_merge
# call above so the manifest keys stay relative to the scan root — portable
# across clones/machines, so --update keeps matching cached files instead of
# missing every one after a move (#1417).
#
# Only stamp semantic files (docs/papers/images) that ACTUALLY produced output
# THIS run (new_extraction is this run's fresh extraction, read above before the
# merge overwrote the file): a changed doc whose chunk failed must stay unstamped
# so the next --update re-queues it, otherwise it is marked done and its content
# is lost forever (#2015). Mirrors the library extract path
# (cli._stamped_manifest_files + clear_semantic + scan_corpus).
from graphify.cli import _stamped_manifest_files
_manifest_files = _stamped_manifest_files(incremental['files'], new_extraction, Path(ROOT))
# Changed semantic files dispatched this run but NOT stamped had their chunk fail
# or be omitted; clear any stale semantic_hash so they are re-queued (#1948).
_sem_types = ('document', 'paper', 'image')
_dispatched = {f for t, fl in incremental.get('new_files', {}).items() if t in _sem_types for f in fl}
_stamped = {f for fl in _manifest_files.values() for f in fl}
_cleared = _dispatched - _stamped
# scan_corpus = the RAW full corpus so in-root files newly excluded since last run
# are dropped rather than masquerading as deletions; untouched rows preserved (#1908).
_scan = {f for fl in incremental['files'].values() for f in fl}

# The nodes of the existing graph.json whose source file this run deleted or
# re-extracted: the only losses that explain a smaller graph. Both sides are
# compared as resolved absolute paths under the scan root, since graph.json keeps
# source_file relative and detection lists absolute paths.
import hashlib
def _identity(p):
    return os.path.normcase(os.path.realpath(os.path.join(ROOT, p.replace('\\', '/'))))
_deleted_files = {_identity(f) for f in deleted}
_replaced_files = {_identity(f) for fl in incremental.get('new_files', {}).values() for f in fl}
_old_graph = Path('graphify-out/graph.json')
_old_data = json.loads(_old_graph.read_text(encoding="utf-8")) if _old_graph.exists() else {}
_old_nodes = _old_data.get('nodes', [])
_deleted_ids, _replaced_ids = [], []
for n in _old_nodes:
    if not isinstance(n, dict) or n.get('id') is None or not n.get('source_file'):
        continue
    _sf = _identity(str(n['source_file']))
    if _sf in _deleted_files:
        _deleted_ids.append(n['id'])
    elif _sf in _replaced_files:
        _replaced_ids.append(n['id'])
# A node with no source_file (an import target such as pathlib) lives only
# through its edges. When every edge it had in the old graph reaches a node
# removed above, the removal orphans it and Graphify drops it too: count it as
# deleted when all those nodes were deleted, else as re-extracted. One that
# still had an edge to a surviving node stays unexplained if it goes missing.
# Edges sit under "links", or under "edges" from Graphify's raw writer. An edge
# list the block can't read whole (an edge whose ends aren't both string ids)
# explains no such node, since a skipped edge could reach a surviving node.
_removed = set(_deleted_ids) | set(_replaced_ids)
_deleted_set = set(_deleted_ids)
_links = _old_data.get('links') if 'links' in _old_data else _old_data.get('edges', [])
_neighbours = {}
if isinstance(_links, list) and all(isinstance(e, dict) and isinstance(e.get('source'), str)
                                    and isinstance(e.get('target'), str) for e in _links):
    for e in _links:
        _neighbours.setdefault(e['source'], set()).add(e['target'])
        _neighbours.setdefault(e['target'], set()).add(e['source'])
for n in _old_nodes:
    if not isinstance(n, dict) or not isinstance(n.get('id'), str) or n.get('source_file') or n['id'] in _removed:
        continue
    _near = _neighbours.get(n['id'])
    if _near and _near <= _removed:
        (_deleted_ids if _near <= _deleted_set else _replaced_ids).append(n['id'])
# Step 4 reads this file, bound to the merged extraction written above by its
# SHA-256, so a file an interrupted run left behind never applies to another build.
Path('graphify-out/.graphify_update_pending.json').write_text(json.dumps({
    'extraction_sha256': hashlib.sha256(Path('graphify-out/.graphify_extract.json').read_bytes()).hexdigest(),
    'deleted_ids': _deleted_ids,
    'replaced_ids': _replaced_ids,
    'manifest_files': _manifest_files,
    'scan_corpus': sorted(_scan),
    'clear_semantic': sorted(_cleared),
}, ensure_ascii=False), encoding="utf-8")
print('[graphify update] Manifest held until Step 4 has written graph.json.')
GRAPHIFY_PY
```

Replace `IS_DIRECTED` in the `GRAPHIFY_DIRECTED` heredoc with `True` if `--directed` was given, otherwise `False`, here and in the graph-diff block below. Then run Steps 4–6 on the merged graph as normal. Step 4 saves the manifest once it has written graph.json. A smaller graph is written only when every node it lacks came from a file this run deleted or re-extracted, or is a node with no source file (an import target) whose every edge reached such a node; otherwise Step 4 refuses, as it does for an empty graph unless every source file of the graph was deleted. If Step 4 refuses, stop and show its lines to the user: the manifest stays as it was, so the next `--update` retries the same files.

After Step 4, show the graph diff:

```bash
export GRAPHIFY_NO_AUTO_REFRESH=1
export GIT_NO_LAZY_FETCH=1 GIT_PROTOCOL_FROM_USER=0 GIT_ALLOW_PROTOCOL=
PATH=$(/bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path) || { printf '%s\n' "$PATH"; exit 1; }
unset GRAPHIFY_OUT
GRAPHIFY_DIRECTED=$(cat <<'GRAPHIFY_VALUE_EOF'
IS_DIRECTED
GRAPHIFY_VALUE_EOF
)
export GRAPHIFY_DIRECTED
"$(cat graphify-out/.graphify_python)" -I - <<'GRAPHIFY_PY'
import os
DIRECTED = os.environ['GRAPHIFY_DIRECTED'] == 'True'
import json
from graphify.analyze import graph_diff
from graphify.build import build_from_json
from graphify.paths import load_node_link_graph
import networkx as nx
from pathlib import Path

# Load old graph (before update) from backup written before merge
old_data = json.loads(Path('graphify-out/.graphify_old.json').read_text(encoding="utf-8")) if Path('graphify-out/.graphify_old.json').exists() else None
new_extract = json.loads(Path('graphify-out/.graphify_extract.json').read_text(encoding="utf-8"))
G_new = build_from_json(new_extract, directed=DIRECTED)

if old_data:
    G_old = load_node_link_graph(old_data)
    diff = graph_diff(G_old, G_new)
    print(diff['summary'])
    if diff['new_nodes']:
        print('New nodes:', ', '.join(n['label'] for n in diff['new_nodes'][:5]))
    if diff['new_edges']:
        print('New edges:', len(diff['new_edges']))
GRAPHIFY_PY
```

Before the merge step, save the old graph:

```bash
export GRAPHIFY_NO_AUTO_REFRESH=1
export GIT_NO_LAZY_FETCH=1 GIT_PROTOCOL_FROM_USER=0 GIT_ALLOW_PROTOCOL=
PATH=$(/bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path) || { printf '%s\n' "$PATH"; exit 1; }
cp graphify-out/graph.json graphify-out/.graphify_old.json
```

Clean up after:

```bash
export GRAPHIFY_NO_AUTO_REFRESH=1
export GIT_NO_LAZY_FETCH=1 GIT_PROTOCOL_FROM_USER=0 GIT_ALLOW_PROTOCOL=
PATH=$(/bin/sh "$HOME/.agents/skills/graphify/atlas-graphify.sh" --path) || { printf '%s\n' "$PATH"; exit 1; }
rm -f graphify-out/.graphify_old.json
```

---

Not available in the atlas pack: --cluster-only. The pack supports building, updating and querying the graph; to use --cluster-only, run upstream Graphify by hand outside the kit (see "Running Graphify by hand" in references/atlas-pack-notes.md in the agents directory (`~/.agents`)).
