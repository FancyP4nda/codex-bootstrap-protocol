---
name: session-start
description: Orient a work session from Git, project instructions, durable handoff and optional Beads; choose and claim the next scoped task.
---

Read the project's AGENTS.md and inspect Git status and recent commits before
changing anything. Preserve existing work. Run only documented environment
checks; missing health documentation is a gap to report, not a reason to invent
services or endpoints.

If .beads exists and bd is available, run bd prime, bd stats and bd ready. A
broken database is a recovery issue: report bd doctor or bd bootstrap guidance
and skip claims until it is usable. Do not interpret a failed lookup as an empty
queue. If there is no Beads workspace, orient from Git, README and the user's
request; skip every Beads operation.

Read docs/handoff.yaml, docs/changelog.yaml and docs/CONTEXT.md when present.
For a requested delegated orientation, use navigator-recon with these paths and
a read-only report. For an ordinary repo, work directly. Summarize completed,
in-progress and recommended work; let the user's request select the task.

Inspect selected issues, refine under-specified work with $refine-beads when
available, and claim only the work you will execute. For a complex task whose
workflow authorizes delegation, navigator-survey can propose a plan; for a
small fix navigator-maintenance can identify the smallest verified change.
Repository workflow determines branching and publication; do not automatically
pull, stash, push or create a branch as an orientation side effect.

Read only relevant shared guidance from ../../bootstrap/instructions or project
.agents/bootstrap/instructions. State the next concrete action and any blocker.
