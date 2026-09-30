# <Project name>

<!-- Project context for Codex. Replace each comment with this project's details; delete sections that don't apply. -->

## What this is

<!-- One or two sentences: what the project does and who it's for. -->

## Build, run and test

<!-- The commands to install dependencies, run the app, run tests and lint. -->

## Architecture

<!-- A short overview, or a pointer to docs/architecture.md. -->

## Conventions

<!-- Project-specific conventions: naming, structure, libraries to prefer or avoid. -->

## Context files

<!-- BEGIN CODEX BOOTSTRAP -->
Project docs live in `docs/`; consult relevant architecture, tests, security and
`CONTEXT.md` before changes. Product truth comes from this project's approved
artifacts and the user's current instructions.

Invoke `$session-start`, `$session-checkpoint` and `$session-wrapup` for session
work. Planning: `$brainstormer` → `$grill-with-docs` → `$product-architect` →
`$project-planner` → optional `$adversarial-review` → `$plan-to-beads-unified`.
Use `$refine-beads` before implementing under-specified issues and `$tdd` when
tests establish meaningful behavior. Core skills are global in `~/.agents/skills`
unless installed with `--local-core`.

Read `.agents/bootstrap/instructions/development-standards.md` for project
standards. Shared workflow guidance lives in `~/.agents/bootstrap/instructions`
or the project's `.agents/bootstrap/instructions` in local-core mode; load only
the relevant planning, execution, session or agent document.

If `.beads` exists, run `bd prime`, track work with Beads and export tracked
records through ordinary Git. Preserve its existing backend; never require Dolt
remote synchronization. Without Beads, use Git and a concise session summary.
Keep transient output under ignored `.codex/state/tmp`.

If installed, `$falcon` owns isolated worker dispatch and `$herald` routes UI,
design-system, prototype and accessibility work. For web-design requests read
`docs/web-design-mission.md` and `.agents/bootstrap/instructions/web-design-pack.md`
when present, then choose `$impeccable` or `$taste-skill` for the relevant task.
Web-design is an explicitly opted-in unverified pack; its licenses, pins and
remaining validation limits are recorded in `docs/web-design-notes.md`.

Native agents live in `.codex/agents` or `${CODEX_HOME:-~/.codex}/agents`.
Delegate only when the user or an applicable workflow authorizes it. Steering
owns integration and external actions. Honor project trust and hook review;
the installer never grants trust. Only publish, push or deploy when authorized
by the user or this repository's workflow.
<!-- END CODEX BOOTSTRAP -->
