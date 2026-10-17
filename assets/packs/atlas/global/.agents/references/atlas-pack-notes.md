# Atlas pack notes

Pack-authored record for the `atlas` global pack: what it installs, where the
vendored skills come from, how this copy relates to the Claude kit's, and what
the pack does not support. It installs to `~/.agents/references/`. This is the
one native file in the pack: the Commands and the pack-authored scripts are
derived from the Claude kit's (see "Derivation"), and the two skill trees under
`skills/archify/` and `skills/graphify/` are third-party content, byte-identical
to upstream apart from the recorded patches and the rename below.

The Claude kit's notes (`atlas-pack-notes.md` in its pack) hold the full
history, the per-patch reasoning and the fix rounds; this file keeps only what
an operator of the Codex copy needs. Where the two differ, the decision brief
`docs/decision-brief-archify-graphify.md` (D-1 to D-10) says why.

## Install

```bash
codex-bootstrap --global-only --pack atlas            # skills and notes, for every project
codex-bootstrap --global-only --pack atlas --update-global   # take a re-pinned version, with backups
codex-bootstrap --remove-global-pack atlas            # remove the files that are still as installed
```

Skills install to `~/.agents/skills/<name>/`, which Codex loads. The notes
install to `~/.agents/references/atlas-pack-notes.md`. The install record is
`~/.agents/bootstrap/packs/atlas.json`. The pack writes nothing under
`$CODEX_HOME`. Every skill in it is user-only: it carries `agents/openai.yaml`
with `policy.allow_implicit_invocation: false`, so Codex does not start it from
a request's wording (decision brief D-2). Codex 0.162.1's documentation says it
honours that line; a running session has not confirmed it (A-011, R-021), and
the live check is the operator's step after the first real install.

The pack installs skills only. The runtimes the Commands drive are External
Prerequisites that the operator installs and `$atlas-doctor` checks: Graphify
(`graphifyy==0.9.85`), REA (`rea-agents@6.4.0`), Node (at least 18 for Archify;
`^22.19.0`, `^24.11.0` or `>=26.0.0` for REA), uv and a Chromium-family browser.
Nothing installs them and nothing runs a fix line for you.

## Roster

Every Command is `$name`, user-only. The Claude kit's Roster has each Command's
behaviour in full; the text installed here is that text with the `$` sigil.

- **`$atlas-doctor`**: read-only check of the prerequisites, REA's registration
  for Codex (`rea doctor --client codex`), the `multi_agent` setting, the REA
  entry in `config.toml`, the migration items, always-on and hook traces in the
  current repository, the scratch `.gitignore` rows, Gemini keys (by name) and
  the graph's freshness. It prints the exact fix line for each problem, edits
  nothing and runs no fix line. Codex-only lines:
  - `multi_agent`: `[ok]` when `config.toml` in `$CODEX_HOME` (default
    `~/.codex`) sets `multi_agent = true` under `[features]`; otherwise `[warn]`
    with the two lines to add. Graphify's parallel semantic extraction needs it;
    without it the extraction runs serially (D-5).
  - `rea-config`: `[ok]` when the same file has an `[mcp_servers.rea]` entry;
    otherwise `[warn]` with `rea setup` (D-6).
  - REA's MCP server, for the REA Commands' environment checks, is read as
    Codex configures it: `config.toml` in `$CODEX_HOME`, then the
    `.codex/config.toml` of each directory from the project root (the nearest
    `.git`, or `project_root_markers`) down to the working directory, merged
    per key (env tables name by name, arrays replaced), and a project layer
    counts only when `[projects."<root>"]` in the user's file has
    `trust_level = "trusted"`. The merged command and args must be a
    registration `rea-agents@6.4.0` writes (`rea mcp`, `<path>/scripts/rea.mjs
    mcp`, `node <path>/scripts/rea.mjs mcp` or `npx -y rea-agents@6.4.0 mcp`).
    When the entry cannot be established the check stops with a line naming
    the file.
  - `migration-unstamped-archify` and `migration-unstamped-graphify`: a skill
    directory under `~/.agents/skills` that the install record does not list,
    with the line that moves it out (D-4).
  - `trace-codex-hooks`: a `graphify` string inside a `PreToolUse` array of
    `.codex/hooks.json`, with `graphify codex uninstall` as the fix line.
  Its stub tests: `verification/test_atlas.py`.
- **`$map-repo [path] [--update]`**, **`$map-ask`**, **`$map-impact`**: build,
  query and report from the Graphify graph in `graphify-out/`.
- **`$diagram`**, **`$diagram-repo`**, **`$diagram-flow`**: Archify diagrams;
  kept ones are copied, on a yes, to `docs/diagrams/<slug>.html` (D-7).
- **`$rea-doctor`**, **`$rea-triage`**, **`$rea-feature`**, **`$rea-diagram`**,
  **`$rea-map`**, **`$rea-update`**: the REA Commands. Static by default.
- **`$rea-binary`**, **`$rea-android`**, **`$rea-electron`**: the REA target
  Commands for native binaries, Android packages and Electron apps.

## Pins

| Component | Repository | Tag | Commit | License |
|---|---|---|---|---|
| `archify` | <https://github.com/tt-a1i/archify> | `v3.1.0` | `1c2b42d660e4a7571813fb43839c79e3e9ca7720` | MIT, with the third-party content `skills/archify/THIRD_PARTY_NOTICES.md` lists |
| `graphify` | <https://github.com/Graphify-Labs/graphify> | `v0.9.85` | `b4e6307bf170f27e0cb888c03f4af9308d531a42` | Apache-2.0 (`LICENSE`, `NOTICE` and `LICENSE-MIT` are vendored beside `SKILL.md`) |

Archify's files are the Claude pack's, byte for byte, except `SKILL.md`.
Graphify's `SKILL.md` is upstream's `graphify/skill-agents.md` (the agents-root
variant) with the Claude pack's patches; the three reference files come from
`graphify/skills/agents/references/`, which equal `skills/claude/references/`
at the pin, so the Claude diffs apply unchanged. The other five reference files
serve operations the pack does not support and are not vendored.

## Patches

- **Archify**, three, the Claude pack's: `SKILL.md` runs every Archify command
  through `skills/atlas-doctor/scripts/atlas-archify.sh` (here
  `$HOME/.agents/skills/atlas-doctor/scripts/atlas-archify.sh`) and drops the
  `disable-model-invocation` line and the `license` and `metadata` keys, since
  the user-only switch is `agents/openai.yaml` (D-2); `renderers/shared/
  brand-marks.mjs` and `bin/visual-check.mjs` carry the brand-capture and
  browser network switches the wrapper sets.
- **Graphify**: `SKILL.md` and the three reference files carry the Claude pack's
  execution-safety edits (the preflight and runner, values passed as data, the
  supported surface, the modification notice) and, in `SKILL.md`, a Codex
  adaptation of Part B: JSON path lists (`.graphify_uncached.json` and the chunk
  list files `.graphify_chunk_NN.files`, never one path per line, with every name
  refused if it is empty, holds a control, line-separator, surrogate, invisible
  or slash-or-dot look-alike character, or resolves outside the scan root; the
  session shows the STOP line to the user and fixes nothing itself), native
  subagents through `spawn_agent`, `wait_agent` and `close_agent` when
  `multi_agent` is on, a serial path (the session extracts each chunk in turn)
  when it is off, and a collection check that sets aside invalid chunk files and
  retries failed chunks serially. Workers read a chunk's files through one
  fixed command, `/bin/sh graphify/atlas-read-chunk.sh <list> <index>`. The
  shell entry point first finds the repository around the working directory
  and cuts PATH to the absolute entries outside it, as the runner does, and
  runs no `cat` or other tool from the ambient PATH (the interpreter path is
  read with the shell's own `read` and must lie outside the repository). It
  then runs `atlas-read-chunk.py`, which reads the list as data, checks the
  entry against the scan root again and prints the file, so no file name
  reaches a shell and no file-reading tool is needed.
  A PDF is read as text through `pdftotext` (poppler): the reader finds it on
  an absolute PATH entry outside the repository of the scan root and of the
  working directory (by logical and physical name, symlinks followed), runs
  it with fixed arguments and the resolved path as one argument (no shell), and
  without it refuses that PDF by name with an install line, never printing the
  bytes. poppler is an optional External Prerequisite of `$map-repo` on a
  corpus with PDFs.
  The Claude kit's Step B0 and B1 also refuse a file name that holds a double
  quote or a backslash, because its workers get the list as JSON text in a
  prompt; here the delta file puts the looser check back, since the reader
  reads the list as data and handles those names.
  Upstream's Part B names a Task tool and
  agent types that Codex does not have. The recorded diff of `SKILL.md`
  against upstream's `skill-agents.md` is
  `verification/vendor-check-atlas-patches/graphify/SKILL.md.diff` in this
  kit; the reference diffs are the Claude kit's own.
- Fidelity check (needs the network): `python3 verification/vendor-check-atlas.py`
  proves the recorded patches reverse-apply to the pinned upstream files; with
  `--network` it also re-fetches both pins and compares every other vendored file.

## Derivation

`node tools/migrate-atlas.mjs <claude-kit-checkout>` rebuilds
`global/.agents/skills` from the Claude kit's atlas pack and writes
`docs/atlas-source-map.json` (the source commit and every derived file's hash). The
transform:

- `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` becomes `$HOME/.agents`;
- the shared script's client argument `claude` becomes `codex`, and the doctor's
  Codex checks above replace its Claude-only ones;
- `/command` becomes `$command` (escaped in double-quoted shell strings),
  the Claude kit's kept-diagrams folder becomes `docs/diagrams`, `claude-bootstrap` becomes
  `codex-bootstrap`, `Claude Code` becomes `Codex`;
- `SKILL.md` frontmatter keeps `name` and `description`, and each skill gets
  `agents/openai.yaml`;
- Graphify's `SKILL.md` takes the Codex dispatch text in
  `tools/atlas-graphify-agents-delta.json` (a list of exact replacements; the
  converter fails when one no longer matches the Claude source).

A Command-text fix is made in the Claude kit and re-derived here with the
converter, then `node tools/sync-assets.mjs` and
`python3 tools/refresh-pack-digests.py`. Never rerun the whole-kit importer
(`tools/migrate-source.mjs`) over this pack.

## Running Graphify by hand

The operations the pack does not support stay available in upstream Graphify,
run by hand outside the kit at the operator's own risk. To do it more safely:

- set `GRAPHIFY_NO_AUTO_REFRESH=1` in that shell first. At 0.9.85 any
  `graphify` command refreshes the installed skill before it answers, which
  would overwrite this pack's copy of the Graphify skill;
- never run `graphify install` or the bare `graphify uninstall`: they install or
  delete the Graphify skill in every detected platform, this pack's copy
  included;
- Graphify git hooks (`graphify hook install`) and always-on mode
  (`graphify codex install`, `graphify claude install`) are outside the kit's
  policy; `$atlas-doctor` reports any that are installed;
- pass database passwords through `NEO4J_PASSWORD` or `FALKORDB_PASSWORD`, never
  on the command line or inside a URI;
- run it from the project directory, on a repository you trust, and check where
  each export writes before you run it.

## Running Archify by hand

The wrapper runs only the operations the pack needs to draw a diagram, repair
it and check it. The others (`preview`, `deliver`, `render`, `compare`,
`migrate`, `inspect`, `doctor`, `demo`, `examples`, `brands capture`,
`recover-output`, and options such as `--open`) stay available in upstream
Archify, run by hand outside the kit at the operator's own risk. To do it more
safely:

- set `ARCHIFY_UPDATE_CHECK_DISABLED=1` in that shell first;
- know that upstream Archify has no switch for its object-brand fetch or its
  browser checks: read a diagram's brands before you run it, and open only HTML
  you trust;
- run upstream Archify from its own install, not the pack's copy under
  `~/.agents/skills/archify/`;
- run it from the project directory, on a repository you trust.

## Unsupported extras

Graphify's vendored files mention no install outside the supported path, no
hook and no always-on text. Hooks or always-on installs made before the pack are
migration territory.

## Migration

One-time hand step for a machine that had Archify or Graphify installed before
the pack (D-4). The installer never adopts an identical file that was already
there, so a copy under `~/.agents/skills` from before the pack stays unlisted in
the install record and escapes later refresh and `--remove-global-pack`.

1. Before the first install, move `~/.agents/skills/archify` and
   `~/.agents/skills/graphify` to a folder outside `~/.agents/skills` (a moved
   directory inside it would still load as a skill), for example
   `mkdir -p ~/.agents/retired && mv ~/.agents/skills/archify ~/.agents/skills/graphify ~/.agents/retired/`.
2. Install the pack with the command above. It lists every file it writes.
3. Never run `graphify install` again, and delete any `.graphify_version` file in
   `~/.agents/skills/graphify`. `$atlas-doctor` checks both
   (`migration-stamp-agents`, `migration-unstamped-*`).
4. `~/.codex/AGENTS.md` carries no Graphify or Archify section, so there is
   nothing to remove there.

The installer dies on a symlink anywhere on a path it writes to, where the Claude
kit's writes through; `$atlas-doctor` reports an `archify` or `graphify`
symlink (`migration-archify-link`, `migration-graphify-link`) and tells the
user to move or remove the link, not its target.

## Constraints-file regeneration

`skills/atlas-doctor/graphify-constraints.txt` is a derived copy of the Claude
pack's file, the 29 dependency versions a verified Graphify 0.9.85 install
resolved. Regenerate it in the Claude kit (its notes, "Constraints-file
regeneration"), then re-derive it here.

## Re-pin checklist

A re-pin happens in the Claude kit first: new commit, new patches, new
verification. Then, here: run the converter, check that `graphify/skill-agents.md`
at the new commit is the file the recorded diff expects, that every
replacement in `tools/atlas-graphify-agents-delta.json` still matches the Claude
source (the converter fails otherwise) and that the Codex tools it names
(`spawn_agent`, `wait_agent`, `close_agent`) still exist,
re-record `verification/vendor-check-atlas-patches/graphify/SKILL.md.diff`, run
`python3 verification/vendor-check-atlas.py`, then sync, refresh the digests and
run the suites.

## Accepted risk

The runtimes (Graphify and its 29 dependencies, REA and its npm dependencies,
Node, uv, the browser) are not scanned; the exact pins, the constraints file,
the runner's version check and the wrappers' network switches are the controls.
The pack is pre-airlock like `craft` and `web-design`: every evidence field in
`pack.yaml` is null and its verdict is a placeholder.

## Open items

- A live Codex session has not confirmed that `allow_implicit_invocation: false`
  keeps these skills from starting on their own (A-011, R-021). Operator step,
  after the first real install.
- This kit's pack validator has no External Prerequisite field; `pack.yaml` is
  not schema-valid until it does (filed as a bead).
- Graphify's Part B is verified by running its chunk, collection and merge
  blocks against fixture chunk files (`GraphifyDispatchTests`); a real Codex
  session spawning subagents from it is not exercised (operator step, with
  A-011).
