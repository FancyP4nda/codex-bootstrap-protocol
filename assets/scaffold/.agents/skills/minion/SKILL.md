---
name: minion
description: Run explicit Codex report-only subagent fanout for parallel research, review, triage, and planning; defaults to 10 workers and defers write-heavy execution.
protocol_version: 1.0
origin: SCAR Labs
cognitive_tier: Execution
---

# Minion

## Purpose

Use `minion` when the operator explicitly asks for Codex subagents, parallel workers, fanout, swarm-style review, or `$minion`.

`minion` v1 is report-only. It fans out bounded research, review, triage, planning, or evidence-gathering work to Codex subagents and returns structured reports to the steering session. It does not execute write-heavy implementation work.

## Trigger Rules

Activate this skill only when the user explicitly asks for one of:

- `$minion`
- Codex subagents
- parallel agents or workers
- fanout across review, research, triage, or planning slices

Do not activate it for ordinary single-thread implementation requests.

## Defaults And Limits

- If the user does not specify a worker count, default to 10-way fanout.
- If the user specifies a worker count, use that count.
- Do not impose a scaffold-level hard cap.
- Warn that practical limits are subject to Codex runtime, account, environment, sandbox, approval, token, and local resource constraints.
- For large fanouts, warn that synthesis quality and coordination overhead can degrade even when the scaffold allows the requested count.

## Worker Agent Contract

Use the project-scoped report-only worker custom agent defined in `.codex/agents/worker.toml` when available.

Do not create or edit `.codex/agents/worker.toml`; that file is owned by the custom-agent task. If the worker agent is missing, continue with Codex subagents only after telling the user that the preferred report-only worker contract is unavailable.

Each worker prompt must restate report-only behavior:

- Do not edit files.
- Do not create commits.
- Do not claim, update, or close Beads issues.
- Do not push changes.
- Do not install dependencies.
- Do not perform write-heavy implementation.
- Return evidence, findings, recommendations, risks, and verification suggestions.

## Intake

Before spawning subagents:

1. Parse the requested goal, worker count, scope, and required output.
2. If no worker count is present, set `worker_count: 10`.
3. Identify whether the request is report-safe or write-heavy.
4. Identify candidate slices that can run independently.
5. State the fanout plan in the steering session before dispatching workers.
6. Include the practical-limits warning whenever the count is large, the task is broad, or runtime constraints are likely to matter.

## Write-Heavy Requests

Do not execute write-heavy fanout in v1.

When the user asks `minion` to implement, edit, fix, migrate, refactor, commit, push, open a PR, or otherwise perform write-heavy work:

1. Convert the request into report-only planning, file-scope analysis, collision-domain analysis, code review, test-gap review, or implementation-plan reports.
2. If report-only conversion would not satisfy the user, explicitly defer the request to a later write-capable phase.
3. For deferred write-capable work, report the file-scope and collision-domain planning that would be required before implementation workers could be safe.

Use the phrase `write-capable phase deferred` in the final synthesis when write-heavy fanout was requested.

## Deferred Scope

`minion` v1 explicitly defers:

- locks and lock registries
- cron/watch behavior
- auto-amend behavior
- auto-ack behavior
- cross-branch orchestration
- PR actions
- write-capable implementation workers

These items may appear only as deferred-scope statements or future planning considerations, never as active v1 behavior.

## Report Paths

Transient report files, when written, use this convention:

```text
.codex/state/tmp/minion-<UTC timestamp>-<short slug>.md
```

Examples:

```text
.codex/state/tmp/minion-20260607T153000Z-review-auth.md
.codex/state/tmp/minion-20260607T153000Z-plan-migration.md
```

The repository gitignores `.codex/state/tmp/`; do not store durable project decisions there. Durable decisions belong in the appropriate project documentation or Beads issue, only when the user asks for that update.

## Fanout Process

1. Confirm the task is suitable for report-only fanout.
2. Choose slices with minimal overlap. Useful slicing strategies include files, modules, risk categories, acceptance criteria, user stories, hypotheses, or test surfaces.
3. Spawn the requested number of Codex subagents explicitly. Prefer the project `worker` custom agent for each worker when available.
4. Give each worker a narrow prompt with:
   - shared goal
   - assigned slice
   - scope boundaries
   - required files or commands to inspect
   - report-only restrictions
   - output schema from `report-schema.md`
5. Wait for all requested workers unless the user asked for incremental readbacks.
6. Synthesize results in the steering session. Deduplicate findings, separate evidence from inference, and call out contradictions or gaps.
7. If writing a transient report file is useful or requested, write it under `.codex/state/tmp/minion-*` using the schema in `report-schema.md`.

## Output Contract

The steering synthesis must include:

- worker count requested and used
- whether the default 10-way fanout was applied
- worker agent used or missing
- practical-limits warning when relevant
- per-worker summary
- consolidated findings
- assumptions and blockers
- deferred write-capable scope, if applicable
- suggested verification commands
- transient report path, if a report file was written

Use `report-schema.md` as the structured report contract and `fixtures/report-only-prompt-readback.md` as the sample prompt/readback fixture.
