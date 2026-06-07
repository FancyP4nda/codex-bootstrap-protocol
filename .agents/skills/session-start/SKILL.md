---
name: session-start
description: Codex-native session startup and orientation for initialized Bootstrap Protocol targets using docs/handoff.yaml, docs/changelog.yaml, Beads, and optional navigator reports.
protocol_version: 1.0
origin: SCAR Labs
cognitive_tier: Execution
---

# Session Start

## Purpose

Orient a Codex session inside an initialized Bootstrap Protocol target without loading the whole project into the main context. Use this skill when the user asks to start, resume, orient, find current work, or decide what Bead to work next.

This skill replaces the legacy `/leroy` startup concept. That reference is migration context only; do not invoke slash commands or read any live Claude runtime paths.

## Canonical Runtime Paths

- Project instructions: `AGENTS.md`
- Project glossary and context: `docs/CONTEXT.md`
- Handoff state: `docs/handoff.yaml`
- Changelog state: `docs/changelog.yaml`
- Beads tracker: `.beads/`
- Optional Codex custom agent: `navigator`

Do not use `.claude/handoff.yaml`, `.claude/changelog.yaml`, Claude session IDs, Claude transcript paths, or Claude-only command syntax.

## Startup Gates

Run these checks before recommending work:

1. Read the nearest `AGENTS.md`.
2. Run `git status --short --branch`.
3. Check for state docs:
   - `test -f docs/handoff.yaml`
   - `test -f docs/changelog.yaml`
4. Check Beads:
   - `command -v bd`
   - `test -d .beads`

Degrade clearly:

- If `AGENTS.md` is missing, continue but say project instructions were unavailable.
- If either state doc is missing, do not fabricate prior-session facts. Say which file is missing and continue with Git and Beads orientation if available.
- If `bd` is unavailable, do not install it. Say Beads is required for work-item orientation and skip ready/in-progress work tables.
- If `.beads/` is missing, do not run `bd init` unless the user explicitly asks. Report that the target is not Beads-initialized.
- If Git is unavailable or the directory is not a repo, skip branch/history details and say so.

## Orientation Flow

Prefer a report-only `navigator` custom agent when available and useful:

```text
Use the navigator custom agent to orient this initialized target. Inspect AGENTS.md, docs/handoff.yaml, docs/changelog.yaml, git status, and Beads state. Do not edit files, claim issues, close issues, commit, push, or perform external actions. Return last handoff, recent changes, in-progress Beads, ready Beads, blockers, recommended next work, and context files to read.
```

If the custom agent is unavailable, perform the same steps directly.

### 1. Last Handoff

Read `docs/handoff.yaml` if present. Summarize:

- project name and status
- active work
- decisions
- verification notes
- next steps

If the file exists but is empty or schema-light, report the actual fields present instead of assuming the richer wrapup schema.

### 2. Recent Changes

Read `docs/changelog.yaml` if present. Summarize the newest entries from `changes` or `entries`, depending on the schema present. If neither exists, say no changelog entries were found.

### 3. Beads State

When Beads is available, run the smallest useful read-only commands:

```bash
bd list --status=in_progress
bd ready
```

For the top candidate Beads, use `bd show <id>` before recommending them. Treat triage labels and dependency state as authoritative when present.

Do not claim a Bead during orientation unless the user selects one or explicitly asks you to start it.

### 4. Context Loading

Recommend only the context files needed for the likely next work:

- planning or scope: `docs/prd.md`, `docs/project-plan.md`
- glossary or terminology: `docs/CONTEXT.md`
- architecture or dependencies: `docs/architecture.md`
- backend/API: `docs/backend.md`
- frontend/UI: `docs/frontend.md`
- schemas/data: `docs/data-model.md`
- security/privacy: `docs/security.md`

Read those files only after a work direction is chosen or when they are directly needed to make a safe recommendation.

## Output

Return a compact startup report:

```text
Session Start
- Branch: <branch or unavailable>
- State docs: handoff=<present|missing>, changelog=<present|missing>
- Beads: <available|missing bd|missing .beads>
- Last handoff: <summary or unavailable>
- Recent changes: <summary or unavailable>
- In progress: <beads or none/unavailable>
- Ready: <top beads or none/unavailable>
- Recommended next step: <specific action>
- Context to load next: <paths>
```

If the user chooses a Bead, then run `bd show <id>`, verify scope and dependencies, claim it with `bd update <id> --claim` only when appropriate, and proceed with the relevant implementation skill.

## Smoke Prompt

For an initialized target:

```text
$session-start

Orient this repo. Use docs/handoff.yaml, docs/changelog.yaml, and Beads to summarize current state, then recommend the next Bead to inspect. Do not claim work yet.
```
