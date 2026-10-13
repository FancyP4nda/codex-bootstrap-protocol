---
workflow_artifact: decision_brief
artifact_version: 1
source_mode: existing_project
status: approved
upstream_ids: []
recommended_next_skill: product-architect
canonical_next_artifact: prd
---

# Decision Brief: the `atlas` pack in the Codex kit (Archify, Graphify and REA commands)

Grilled 2026-10-13 in the Claude kit by its Technical Lead with the operator. Tracked by the single bead `claude-bootstrap-protocol-54f` in the Claude kit's beads database; this kit files no mirror bead, and commits for this work cite that ID.

The source decision record is `.claude/docs/decision-brief-archify-graphify.md` plus ADR 0009 (`.claude/docs/adr/0009-packs-may-declare-external-prerequisites.md`) in `claude-bootstrap-protocol`. This brief does not repeat the shared reasoning, evidence or command descriptions. It states the decisions as they apply here, then lists **every intentional divergence**. Where this brief is silent, the Claude brief holds.

## Resolved terminology

This kit's `docs/CONTEXT.md` is a short orientation note with no glossary or naming map, so no terms were added there. The two terms the grill resolved, as defined in the Claude kit's `CONTEXT.md`:

- **External Prerequisite:** a runtime a pack depends on but does not vendor (a CLI, an MCP server, a browser), installed by the operator with its own installer at a version the pack pins. The kit checks for it and reports the fix; it never installs it.
- **Command:** a kit-authored skill only the operator can start (`$name` here, `/name` in Claude Code); the model never invokes it, and its description costs no context until used.

Whether this kit grows a glossary section for them is an open item.

## ADR-level decisions (this kit has no `adr/` folder)

This section is the record for this kit:

- **AD-1 (= Claude ADR 0009): Packs may declare External Prerequisites the kit does not vendor.**
  - **The decision.** One opt-in global pack, `atlas`, vendors pinned snapshots of the Archify skill (with its dependency-free Node CLI) and the Graphify skill, plus the 16 kit-authored Commands.
  - **External Prerequisites.** The Graphify runtime (`graphifyy==0.9.85`), the REA runtime (`rea-agents@6.4.0`), Node >=18 and a Chromium-family browser are declared in `pack.yaml`. They are checked and reported, never installed.
  - **Accepted gap.** The scan chain stops at the skill: the runtimes and their transitive dependencies are unscanned (accepted risk).
  - **Rejected options:** two packs, a commands-only pack, vendored runtimes, and the global core (reasoning in Claude ADR 0009).
- **AD-2: Each kit owns its own skill root.**
  - **Roots.** This kit owns `~/.agents/skills/archify` and `~/.agents/skills/graphify`; the Claude kit owns the same names under `~/.claude/skills/`. Neither kit writes into the other's root.
  - **REA.** The REA skill (`reverse-engineer-anything`) stays the operator's own install in both roots, outside either kit.

## Resolved decisions, as they apply here

Numbers follow the Claude brief's decisions 1–10.

1. **Packaging:** the `atlas` global pack with `install_scope: global` and a `global/.agents/skills/` tree only. Both vendored skills and all 16 Commands install into `~/.agents/skills` under the stamp `~/.agents/bootstrap/packs/atlas.json`. No `.codex/` rows are needed.
2. **Existing installs:** see divergence D-4. Never run `graphify install` again; upgrades are kit re-pins.
3. **Vetting:**
   - pre-airlock, like this kit's `craft`: exact upstream commits, evidence null, placeholder verdict;
   - a `pack-integrity.json` entry for `atlas` whose `validation` string says "unverified: evidence fields remain null";
   - Commands set `ARCHIFY_UPDATE_CHECK_DISABLED=1`, `GRAPHIFY_QUERY_LOG_DISABLE=1` and `GRAPHIFY_NO_AUTO_REFRESH=1` for every run;
   - `$map-repo` runs the full Graphify pass with the semantic notice first.
4. **Commands:** the same 16 names and behaviours as the Claude roster table, invoked with `$`:
   - `$map-repo`, `$map-ask`, `$map-impact`;
   - `$diagram`, `$diagram-repo`, `$diagram-flow`;
   - `$atlas-doctor`;
   - `$rea-doctor`, `$rea-triage`, `$rea-feature`, `$rea-binary`, `$rea-android`, `$rea-electron`, `$rea-diagram`, `$rea-map`, `$rea-update`.

   All are user-only, as are the two vendored skills (D-2).
5. **Graceful degradation:**
   - one shared precondition script, shipped with `atlas-doctor`, prints exact fix lines;
   - no installs and no config edits, except `$rea-update` on a yes;
   - REA Commands are static unless `--runtime`, which asks before each capture.
6. **Always-on mode and hooks are forbidden.** No Command runs `graphify codex install` (which writes an `AGENTS.md` section plus a no-op hook) or `graphify hook install`. `$atlas-doctor` reports any trace in the current repo. This also keeps this kit's `bd init --skip-agents --skip-hooks` intent.
7. **Pipeline fit:**
   - `.archify/` is gitignored scratch; diagrams worth keeping are copied, on a yes, to `docs/diagrams/<slug>.html`;
   - `graphify-out/` is always gitignored;
   - three read-only touchpoints, each firing only when `graphify-out/graph.json` exists:
     - `$session-start` freshness line;
     - `$refine-beads` suggests `$map-impact`;
     - `$session-wrapup` drift note against `docs/architecture.md`;
   - `$grill-with-docs` is unchanged.
8. **Verification:** the default suites stay hermetic (stubs, fixtures, no network). Live checks run from a separate opt-in script. A vendor-fidelity script needs network. See D-8 for the Codex-specific checks.
9. **Parity:** Command text is derived from the Claude kit's source (D-3). `multi_agent` is reported by the doctor only (D-5).
10. **`$rea-update`:** runs `rea update` after a yes that states it moves REA off the kit pin, then prints the suggested `rea setup` line without running it.

## Intentional divergences from the Claude brief

| # | Topic | Claude kit | Codex kit (this) | Why |
|---|---|---|---|---|
| D-1 | Install root and stamp | `~/.claude/skills/`, stamp `~/.claude/.claude-bootstrap-pack-atlas` | `~/.agents/skills/`, stamp `~/.agents/bootstrap/packs/atlas.json` | Each kit's existing global-pack mechanism (`bootstrap:378-379, 449-450`). |
| D-2 | User-only switch | `disable-model-invocation: true` in `SKILL.md` frontmatter | `agents/openai.yaml` with `policy: allow_implicit_invocation: false` per Command and per vendored skill; `SKILL.md` frontmatter keeps only `name` and `description` | Codex's documented mechanism (Codex 0.162.1 skill-creator `references/openai_yaml.md:47-49`); precedent in this kit's `to-questionnaire` and `wait-what`. Live behaviour is *unverified* in a running Codex session. |
| D-3 | Command text source | Authored here | Derived from the Claude kit's Command text by this kit's converter (`tools/migrate-source.mjs` already strips `disable-model-invocation`, line 32), with `/` sigils rewritten to `$` and `.claude/docs/` paths to `docs/` | One source of truth; the bodies differ only by the defined transform. |
| D-4 | Clean-up of existing installs | Remove the `~/.claude/skills/archify` symlink; the pack replaces `~/.claude/skills/graphify` through the "untracked" path; delete its `.graphify_version`; remove the `# graphify` section from `~/.claude/CLAUDE.md` | Before the first install, **move** `~/.agents/skills/archify` and `~/.agents/skills/graphify` out of the skills dir, to a folder outside `~/.agents/skills` (a moved dir inside it would still load as a skill) | This kit's packs never adopt identical pre-existing files (`bootstrap:366`, `--no-adopt`). The live Archify 3.0.1 files would match the vendored ones, stay unstamped, and escape later refresh and `--remove-global-pack`. A fresh install stamps every file. `~/.codex/AGENTS.md` carries no Graphify or Archify section (checked), so there is nothing to remove there. |
| D-5 | `multi_agent` | n/a | `$atlas-doctor` checks `[features] multi_agent = true` in `~/.codex/config.toml` and prints the two lines to add; nothing edits `config.toml`. Without it, Graphify's semantic pass extracts serially | Graphify's parallel extraction needs it; the "no command edits agent config" rule. |
| D-6 | REA MCP registration check | `~/.claude.json` | `[mcp_servers.rea]` in `~/.codex/config.toml` (present today, with `GHIDRA_INSTALL_DIR`, `JAVA_HOME`, `HOPPER_LAUNCHER_PATH`) | Each client's own registry. |
| D-7 | Kept diagrams and project `.gitignore` | `.claude/docs/diagrams/`; the scaffold `.gitignore` is a whole-file copy, so the rows reach new projects only and `/map-repo` offers them to existing repos | `docs/diagrams/`; the scaffold's ignore rows reach existing projects too, through bootstrap's `ignore` merge (`bootstrap:489-494`) | Layout and installer differ; the outcome is the same. |
| D-8 | Verification hooks | `run-static-checks.sh` (`check_global_tree`), `run-pack-checks.sh`, `pack_validate.py` | `check-assets.py` and `run-static-checks.sh` assert an `openai.yaml` with the policy line beside every `atlas` Command and vendored skill; `run-pack-checks.sh` dry-runs `--global-only --pack atlas` into a temp `HOME`/`CODEX_HOME`, including a symlink-ancestor fixture (must die, never write); `tools/refresh-pack-digests.py` gains the `atlas` entry | This kit's existing suites. Its installer dies on symlinks where the Claude kit's writes through. |
| D-9 | Decision record | ADR 0009 in `.claude/docs/adr/` | AD-1 and AD-2 in this brief; `feature-parity.md` gains an `atlas` row when the PRD lands | This kit has no `adr/` folder; decision briefs are its record (as in `decision-brief-codex-bootstrap-protocol.md`). |
| D-10 | Order | Built first | Mirrored after the Claude pack lands, as the craft pack was (Claude E10) | D-3 needs the Claude source to exist. |

## Code/doc contradictions

- This kit's `pack.yaml` schema (pack-validator) has no External Prerequisite field either; it needs the same schema change, which AD-1 implies.
- `falcon/pack.yaml:6` and `herald/pack.yaml:6` cite "ADR 0005" and "ADR 0006", which exist only in the Claude kit. Not in scope; noted for whoever next touches those packs.
- `docs/CONTEXT.md` has no glossary or naming map, so the Claude kit's cross-kit naming map (`falcon` vs `minion`) has no counterpart here.

## PRD inputs

Goals, non-goals, constraints, risks and acceptance signals are as in the Claude brief's PRD inputs, with these Codex-specific additions:

- **Acceptance:** with this kit's flags, `--global-only --pack atlas` installs the 2 skills and 16 Commands, each with its `agents/openai.yaml`, into a clean `~/.agents/skills`. `$atlas-doctor` reports `multi_agent` and the REA entry in `config.toml`.
- **Risk:** if the operator skips D-4, identical pre-existing files stay unowned. `$atlas-doctor` should detect an unstamped `archify` or `graphify` dir under `~/.agents/skills` and print the move line.
- **Open items for product-architect:**
  1. Everything in the Claude brief's open items 1–8, mirrored into `docs/codex-bootstrap-protocol-PRD.md`.
  2. Whether the D-3 converter output is checked against the Claude kit's source in CI, which needs a sibling checkout, or only at mirror time.
  3. Whether `docs/CONTEXT.md` gains a glossary section with **External Prerequisite** and **Command**.
  4. Whether the vendored Graphify skill's Codex fallback (extract inline when the host can't dispatch subagents) is acceptable without `multi_agent`, or `$map-repo` should stop and point to D-5.

## Recommended next skill

`product-architect` in this kit (`$product-architect`), with this brief, after the Claude kit's PRD part for `atlas` is drafted, so the Codex PRD can mirror its FR numbering.
