# Craft pack notes

Pack-authored record for the `craft` global pack: where its content comes
from, what was taken and left out, how it installs in Codex and how to move
the pin. It installs next to the vendored checklists in `~/.agents/references/`.
This file is the only pack-authored file; every other file in the pack is
third-party content, vendored unchanged.

## Upstream

- **Repository:** <https://github.com/addyosmani/agent-skills>
- **Commit:** `1be8e34187e34647bb83adc3a1323b26ae6f6abe` (merge of #649,
  2026-10-10). It is not a release tag: it is 43 commits after tag `0.6.12`,
  and upstream's `plugin.json` still reads `0.6.12` at this commit.
- **License:** MIT, from upstream's `LICENSE` at that commit, reproduced in
  full under "License" at the end of this file as the license requires.
  `pack.yaml` records `license: MIT` for the component.
- **Attribution:** the skills and reference checklists in this pack are the
  work of Addy Osmani and the agent-skills contributors.
- **Sibling kit:** the Claude kit (claude-bootstrap-protocol) vendors the same
  16 skills and 7 references from the same commit for `~/.claude`; its copy and
  this one are byte-identical to upstream.

## Install

```bash
codex-bootstrap --global-only --pack craft            # skills and references for every project
codex-bootstrap --global-only --pack craft --update-global   # take a re-pinned version, with backups
codex-bootstrap --remove-global-pack craft            # remove the files that are still as installed
```

Skills install to `~/.agents/skills/<skill>/`, which Codex CLI 0.162.1 loads
(as it does `$CODEX_HOME/skills` and a project's `.agents/skills`). The
references install to `~/.agents/references/`, where the skills' links
`../../references/<file>.md` resolve from each skill directory. The pack
ships no roles, so it writes nothing under `$CODEX_HOME`. Its install record
is `~/.agents/bootstrap/packs/craft.json`.

## Roster

### Skills (16)

| Skill | Purpose |
|---|---|
| `incremental-implementation` | Deliver a change in thin, verifiable slices. |
| `api-and-interface-design` | Design stable APIs, module boundaries and type contracts. |
| `frontend-ui-engineering` | Build accessible, responsive production UI. |
| `source-driven-development` | Check an approach against official documentation before building it. |
| `doubt-driven-development` | Put non-trivial decisions through a fresh-context adversarial review. |
| `debugging-and-error-recovery` | Find the root cause of failing tests, broken builds and unexpected behavior. |
| `browser-testing-with-devtools` | Test and debug in a real browser through Chrome DevTools MCP. |
| `code-review-and-quality` | Review a change across correctness, readability, architecture, security and performance. |
| `code-simplification` | Refactor for clarity without changing behavior. |
| `security-and-hardening` | Harden input handling, auth, storage and integrations (carries `references/hardening-patterns.md`). |
| `performance-optimization` | Measure and fix frontend, backend and query performance (carries `references/optimization-patterns.md`). |
| `ci-cd-and-automation` | Set up build, test and deploy pipelines and their quality gates. |
| `observability-and-instrumentation` | Add logging, metrics, tracing and alerting. |
| `shipping-and-launch` | Prepare a production launch: checklists, rollout, rollback. |
| `deprecation-and-migration` | Retire old systems and move users or schemas to new ones. |
| `constraint-driven-development` | Write the project's quality bar down as a contract (carries `references/floor-guard.md`). |

### References (7)

| File | Purpose |
|---|---|
| `accessibility-checklist.md` | Accessibility review checklist. |
| `definition-of-done.md` | What "done" means for a change. |
| `observability-checklist.md` | Logging, metrics and tracing checklist. |
| `orchestration-patterns.md` | Patterns for coordinating agents and skills. |
| `performance-checklist.md` | Performance review checklist. |
| `security-checklist.md` | Security review checklist. |
| `testing-patterns.md` | Test structure and patterns (JavaScript/TypeScript). |

## Left out

| Upstream content | Why |
|---|---|
| `using-agent-skills` | Router for upstream's Define/Plan layers; conflicts with the kit pipeline. |
| `interview-me`, `idea-refine` | The kit has `brainstormer` and `grill-with-docs`. |
| `spec-driven-development` | Its `SPEC.md` conflicts with `docs/prd.md` as the single product truth. |
| `planning-and-task-breakdown` | Its plan file conflicts with Beads. |
| `test-driven-development` | The kit has its own `tdd` skill. |
| `git-workflow-and-versioning` | The kit's workflow instructions cover it. |
| `context-engineering` | Broad trigger: it would fire in every session. |
| `documentation-and-adrs` | The kit's `grill-with-docs` ADR convention covers it. |
| The nine commands (`commands/*.toml` and their Claude Code and Gemini twins) | The kit works beads through its own skills; the matching skills above are vendored instead. |
| `agents/*.md` (four reviewer agents) | Claude Code agent files; this kit's `reviewer` role and the `qa` profile cover review in Codex. |
| The Claude kit's `review-gate` skill | Pack-authored for Claude Code (its Codex phase calls this kit's `qa` profile); not ported. |

## Patches

None. Every vendored file is byte-identical to upstream at the pinned commit.
Two kit checks treat the vendored files as third-party bytes rather than
kit-authored text:

- `verification/check-assets.py` skips its leftover-Claude-path scan for the
  pack's vendored files: `references/orchestration-patterns.md` explains
  where Claude Code reads agent files, which is upstream prose, not a
  migration leftover.
- The skill frontmatter checks (name matches directory, nonempty
  description, no `model:` or `allowed-tools:`) apply unchanged and pass.

## References the pack leaves dangling

The vendored text still names upstream content this pack leaves out. Read it
with this map:

| Vendored text names | Use instead |
|---|---|
| `/ship`, `/review` | The `code-review-and-quality` skill, or the `reviewer` role (`herdr-qa` for the `qa` profile). |
| `/test`, `test-driven-development` | The kit's `tdd` skill. |
| `/spec`, `/plan`, `/build`, `planning-and-task-breakdown` | `product-architect`, `project-planner` and `plan-to-beads-unified`, then work the beads. |
| `/code-simplify`, `/webperf` | The `code-simplification` and `performance-optimization` skills. |
| `git-workflow-and-versioning` | `~/.agents/bootstrap/instructions/workflow-execution.md`. |
| `interview-me` | `grill-with-docs`. |
| `documentation-and-adrs` | `grill-with-docs` (ADRs) and `$session-wrapup` (context docs). |
| `../docs/agents.md`, Claude Code agent and plugin details | Upstream documentation; not installed. |

## Re-pin checklist

1. Fetch the new upstream commit by its full SHA into a fresh scratch
   directory (`git fetch --depth 1 <url> <sha>`, then check out `FETCH_HEAD`);
   run nothing from it.
2. Diff the skill roster and `references/` against this file. A new skill
   starts excluded until it is reviewed; move a skill to "Left out" if it
   gained a broad trigger or Define/Plan-layer behavior.
3. Replace `global/.agents/skills/<skill>/` and the seven reference files,
   keeping this file.
4. Update `pinned_commit` in `pack.yaml`, the Upstream section here, then run
   `node tools/sync-assets.mjs` and `python3 tools/refresh-pack-digests.py`.
5. Run the kit's suites. Operators take the new version with
   `--global-only --pack craft --update-global`.

## License

MIT License

Copyright (c) 2025 Addy Osmani

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
