---
name: minion
description: Run explicit Codex subagent fanout for report-only analysis or guarded write-capable execution; defaults to 6 workers and caps fanout at 6 workers.
protocol_version: 2.0
origin: SCAR Labs
cognitive_tier: Execution
---

# Minion

## Purpose

Use `minion` when the operator explicitly asks for Codex subagents, parallel workers, fanout, swarm-style review, implementation fanout, parallel Beads work, or `$minion`.

`minion` supports two modes:

- **Report-only mode:** bounded research, review, triage, planning, evidence gathering, and synthesis.
- **Execution mode:** guarded write-capable implementation work delegated to Codex subagents with disjoint scopes, parent-session coordination, verification, and integration.

## Trigger Rules

Activate this skill only when the user explicitly asks for one of:

- `$minion`
- Codex subagents
- parallel agents or workers
- fanout across review, research, triage, planning, or implementation slices
- parallel Beads execution
- swarm-style work

Do not activate it for ordinary single-thread implementation requests.

## Defaults And Limits

- If the user does not specify a worker count, default to 6-way fanout.
- If the user specifies a worker count above 6, cap it at 6 and state that the requested count was capped.
- Never spawn more than 6 workers in one fanout wave.
- Warn that practical limits are subject to Codex runtime, account, environment, sandbox, approval, token, and local resource constraints.
- For broad execution fanouts, warn that synthesis quality, merge overhead, and collision risk can degrade even within the 6-worker cap.

## Mode Selection

Choose the mode from the user's request:

- Use **report-only mode** for research, review, audit, triage, planning, evidence gathering, risk analysis, or when the user explicitly asks for read-only work.
- Use **execution mode** when the user explicitly asks `minion` to implement, edit, fix, migrate, refactor, execute, work Beads, or otherwise perform write-capable work.
- If the request mixes analysis and implementation, split the fanout into a short planning phase followed by execution workers only after file scopes and collision domains are clear.

## Worker Agent Contract

Use the project-scoped worker custom agent defined in `.codex/agents/worker.toml` when available.

Do not create or edit `.codex/agents/worker.toml` while running `minion`; that file is project-owned. If the worker agent is missing, continue with Codex subagents only after telling the user that the preferred worker contract is unavailable.

Every worker prompt must state its mode and restrictions.

### Report-Only Worker Restrictions

- Do not edit files.
- Do not create commits.
- Do not claim, update, or close Beads issues.
- Do not push changes.
- Do not install dependencies.
- Return evidence, findings, recommendations, risks, and verification suggestions.

### Execution Worker Permissions And Restrictions

Execution workers may edit files only inside their assigned write scope.

Execution workers must:

- Work only on the assigned Bead, task, module, or file set.
- Avoid files outside the assigned write scope unless they first report a blocker.
- Avoid overlapping another worker's write scope.
- Preserve unrelated user changes.
- Run the smallest relevant verification command when feasible.
- Return changed file paths, behavior summary, verification results, residual risks, and integration notes.

Execution workers must not:

- Create commits.
- Push changes.
- Open PRs.
- Claim, update, or close Beads issues unless the steering session explicitly delegates that exact Beads operation.
- Install dependencies or make network calls unless the steering session already has explicit user approval.
- Run destructive commands against unassigned paths.
- Touch secrets, credentials, private keys, or unrelated local state.

## Intake

Before spawning subagents:

1. Parse the requested goal, mode, worker count, scope, and required output.
2. If no worker count is present, set `worker_count: 6`.
3. If the requested count is greater than 6, set `worker_count: 6` and report the cap.
4. Identify candidate slices that can run independently.
5. For execution mode, identify write scopes, collision domains, Beads dependencies, verification commands, and integration order before dispatching workers.
6. State the fanout plan in the steering session before dispatching workers.
7. Include the practical-limits warning whenever the task is broad, execution-mode, or runtime constraints are likely to matter.

## Beads Execution

When the operator asks `minion` to work Beads:

1. Run `bd ready` and inspect the candidate issues with `bd show <id>`.
2. Prefer ready issues marked parallel-safe with disjoint collision domains.
3. Do not dispatch concurrent workers for issues that declare overlapping collision domains or `Parallel-safe: No`.
4. The steering session should claim assigned Beads before dispatch when possible.
5. Assign each worker exactly one Bead or one explicitly bounded slice of a Bead.
6. Instruct workers not to close Beads; the steering session closes issues after integrating changes and running verification.
7. If fewer than the requested workers are safe to run, use the safe count and explain why.

## Execution Fanout Process

1. Confirm the task is suitable for write-capable fanout.
2. Choose slices with non-overlapping write scopes. Useful slicing strategies include Beads issues, modules, files, acceptance criteria, user stories, or test surfaces.
3. Spawn up to 6 Codex subagents explicitly. Prefer the project `worker` custom agent for each worker when available.
4. Give each worker a narrow prompt with:
   - shared goal
   - assigned Bead or implementation slice
   - allowed write scope
   - explicit files or commands to inspect
   - execution permissions and restrictions
   - expected verification command
   - output schema from `report-schema.md`
5. Work locally in the steering session on non-overlapping coordination tasks while workers run.
6. Wait for workers when their results are needed for integration.
7. Review and integrate returned changes.
8. Run the relevant combined verification in the steering session.
9. Update and close Beads only after integration and verification.
10. Commit and push from the steering session when the user or repo workflow requires it.

## Report-Only Fanout Process

1. Confirm the task is suitable for report-only fanout.
2. Choose slices with minimal overlap.
3. Spawn up to 6 Codex subagents explicitly. Prefer the project `worker` custom agent for each worker when available.
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

## Deferred Scope

`minion` still defers autonomous orchestration features:

- locks and lock registries
- cron/watch behavior
- auto-amend behavior
- auto-ack behavior
- cross-branch orchestration
- PR actions

These items may appear only as deferred-scope statements or future planning considerations, never as active behavior.

## Report Paths

Transient report files, when written, use this convention:

```text
.codex/state/tmp/minion-<UTC timestamp>-<short slug>.md
```

Examples:

```text
.codex/state/tmp/minion-20260607T153000Z-review-auth.md
.codex/state/tmp/minion-20260607T153000Z-execute-beads.md
```

The repository gitignores `.codex/state/tmp/`; do not store durable project decisions there. Durable decisions belong in the appropriate project documentation or Beads issue, only when the user asks for that update.

## Output Contract

The steering synthesis must include:

- mode used: `report-only` or `execution`
- worker count requested and used
- whether the default 6-way fanout was applied
- whether the requested count was capped at 6
- worker agent used or missing
- practical-limits warning when relevant
- per-worker summary
- changed files and verification results for execution mode
- consolidated findings
- assumptions and blockers
- deferred scope, if applicable
- suggested follow-up verification commands
- transient report path, if a report file was written

Use `report-schema.md` as the structured report contract and `fixtures/report-only-prompt-readback.md` as the prompt/readback fixture.
