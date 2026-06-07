---
name: session-wrapup
description: Codex-native session closeout for initialized Bootstrap Protocol targets using verification, Beads updates, docs/handoff.yaml, docs/changelog.yaml, and explicit publication gates.
protocol_version: 1.0
origin: SCAR Labs
cognitive_tier: Execution
---

# Session Wrapup

## Purpose

Close a Codex work session with verification, Beads state updates, durable local handoff notes, and a clear next-session resume point. Use this skill when the user asks to wrap up, stop cleanly, hand off, record progress, or close completed work.

This skill replaces the legacy closeout command concept. That reference is migration context only; do not invoke slash commands or read any live legacy runtime paths.

## Canonical Runtime Paths

- Project instructions: `AGENTS.md`
- Handoff state: `docs/handoff.yaml`
- Changelog state: `docs/changelog.yaml`
- Project context: `docs/CONTEXT.md`
- Architecture and area docs: `docs/architecture.md`, `docs/backend.md`, `docs/frontend.md`, `docs/data-model.md`, `docs/security.md`
- Beads tracker: `.beads/`
- Optional Codex custom agents: `reviewer` for report-only review, `navigator` for next-work orientation

Do not use legacy runtime state files, Claude session IDs, Claude transcript paths, TaskCreate/TaskUpdate, or Claude-only command syntax.

## Publication Gate

Do not perform external publication actions by default. This includes:

- `git push`
- `bd dolt push`
- pull request creation
- package publishing
- cloud deployment
- network or credential operations

Run those only when the current user request explicitly asks for them or the user approves after you present the command and consequence. Local verification, local file edits, local Beads updates, and local commits are not external publication.

## Wrapup Gates

Start by reading `AGENTS.md` and checking local state:

```bash
git status --short --branch
test -f docs/handoff.yaml
test -f docs/changelog.yaml
command -v bd
test -d .beads
```

Degrade clearly:

- If `AGENTS.md` is missing, continue but say project instructions were unavailable.
- If `docs/handoff.yaml` is missing, produce the handoff summary in the chat and ask before creating the file.
- If `docs/changelog.yaml` is missing, produce the changelog entry in the chat and ask before creating the file.
- If `bd` is unavailable, do not install it. Skip issue updates and report the exact Beads commands that should be run later.
- If `.beads/` is missing, do not run `bd init` unless the user explicitly asks. Report that Beads state cannot be updated.
- If verification cannot be run, explain the blocker and keep affected Beads open.

## Closeout Flow

### 1. Identify Work

Determine which Bead or user request was worked this session. Prefer explicit user-provided Bead IDs. If unclear and Beads is available, run:

```bash
bd list --status=in_progress
```

Do not close parent epics or adjacent Beads unless the user explicitly included them in scope.

### 2. Inspect Changes

Run:

```bash
git status --short
git diff --stat
```

Use the changed paths to decide whether docs updates are needed. Avoid unrelated formatting or metadata churn.

### 3. Verify

Run the smallest relevant verification command from the Bead first. If the Bead does not define one, choose the closest local test, lint, build, or readback check. For docs-only skill changes, a scoped `rg` readback can be sufficient when it directly covers acceptance criteria.

If verification fails, investigate whether the failure is caused by this session. Do not close the Bead until acceptance criteria are satisfied.

### 4. Review When Useful

For non-trivial changes, use the report-only `reviewer` custom agent when available:

```text
Review the current session changes against the active Bead acceptance criteria. Inspect only local files. Do not edit files, update Beads, commit, push, or perform external actions. Return correctness, security, regression, maintainability, and verification findings with file references.
```

If the custom agent is unavailable, perform a direct review.

### 5. Update Beads

When Beads is available:

- Close completed scoped work only after verification and acceptance criteria pass:
  `bd close <id> --reason "<concise evidence>"`
- Leave incomplete work open and add a note when supported by the installed `bd` version.
- Create follow-up Beads only for real remaining work discovered during this session, and only inside the current scope or with user approval.

Do not use TaskCreate or TaskUpdate.

### 6. Update `docs/changelog.yaml`

When `docs/changelog.yaml` exists and completed user-visible work shipped, prepend or append according to the schema already present. The scaffold's minimal schema is:

```yaml
version: 1
changes: []
```

Use concise entries that include date, Bead IDs, changed areas, and a one-line summary where the schema allows. If the file uses an `entries:` schema instead, preserve that schema.

Validate YAML when a validator is available:

```bash
yq '.' docs/changelog.yaml
```

If `yq` is unavailable, inspect the edited file directly and report that parser validation was unavailable.

### 7. Update `docs/handoff.yaml`

When `docs/handoff.yaml` exists, record a next-session resume point. The scaffold's minimal schema is:

```yaml
version: 1
project:
  name: ""
  status: draft
active_work: []
decisions: []
verification: []
next_steps: []
```

Preserve the schema already present. Capture:

- completed Beads and evidence
- in-progress Beads and exact resume point
- blockers
- verification commands and results
- decisions made
- next steps in priority order
- commit hashes when a local commit is created

Validate YAML when possible:

```bash
yq '.' docs/handoff.yaml
```

### 8. Commit Locally When Appropriate

If code or docs changed and verification is acceptable, create a local commit when the user requested a complete closeout or local instructions require it. Use a clear Conventional Commit-style message and include the Bead ID when available.

Do not push unless explicitly requested or approved under the Publication Gate.

### 9. Final Report

Return:

- changed paths
- verification commands and results
- Beads updated or left open
- docs state updated or skipped
- commit status
- publication status
- exact next-session resume point

## Smoke Prompt

For an initialized target:

```text
$session-wrapup

Wrap up the current Bead. Verify the acceptance criteria, update docs/handoff.yaml and docs/changelog.yaml if warranted, close only completed scoped Beads, and create a local commit. Do not push or publish unless I explicitly approve it.
```
