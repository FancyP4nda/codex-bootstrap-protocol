# Minion Report-Only Prompt And Readback Fixture

This fixture shows the intended `$minion` prompt shape and the expected report-only readback. It is illustrative, not a command transcript.

## Prompt

```text
$minion Review the authentication migration plan with parallel Codex subagents.
Use three workers: one for security risks, one for test gaps, and one for rollout risks.
Return report-only findings with file references and suggested verification commands.
```

## Steering Fanout Plan

```yaml
schema: minion.plan.v1
mode: report-only
worker_count_requested: 3
worker_count_used: 3
default_count_applied: false
worker_agent: ".codex/agents/worker.toml"
practical_limits_warning: "Practical fanout limits are subject to Codex runtime, account, environment, sandbox, approval, token, and local resource constraints."
workers:
  - worker_id: worker-01
    assigned_slice: "security risks"
  - worker_id: worker-02
    assigned_slice: "test gaps"
  - worker_id: worker-03
    assigned_slice: "rollout risks"
```

## Worker Prompt Template

```text
You are worker-01 for a minion v1 report-only fanout.

Use the project-scoped report-only worker custom agent from .codex/agents/worker.toml when available.

Shared goal: Review the authentication migration plan.
Assigned slice: security risks.
Scope: inspect only the relevant local docs, code references, and verification commands needed for this slice.

Report-only restrictions:
- Do not edit files.
- Do not create commits.
- Do not claim, update, or close Beads issues.
- Do not push changes.
- Do not install dependencies.
- Do not perform write-heavy implementation.

Return a worker report using .agents/skills/minion/report-schema.md:
- scope inspected
- evidence
- findings
- assumptions
- risks
- blockers
- suggested verification
```

## Readback

```yaml
schema: minion.report.v1
created_utc: "2026-06-07T15:30:00Z"
request:
  original_prompt: "Review the authentication migration plan with three report-only workers."
  worker_count_requested: 3
  worker_count_used: 3
  default_count_applied: false
  worker_agent: ".codex/agents/worker.toml"
  mode: "report-only"
limits_warning: "Practical fanout limits are subject to Codex runtime, account, environment, sandbox, approval, token, and local resource constraints."
scope:
  included:
    - "security risks"
    - "test gaps"
    - "rollout risks"
  excluded:
    - "implementation edits"
    - "commits"
    - "Beads state changes"
  write_heavy_request: false
  write_capable_phase_deferred: false
deferred_scope:
  locks: true
  cron_watch: true
  auto_amend: true
  auto_ack: true
  cross_branch_orchestration: true
  pr_actions: true
  write_capable_implementation_workers: true
workers:
  - worker_id: "worker-01"
    assigned_slice: "security risks"
    status: "complete"
    inspected:
      - "docs/security.md"
    findings:
      - severity: "medium"
        summary: "Migration plan needs an explicit rollback credential-safety check."
        evidence:
          - "docs/security.md:example"
        recommendation: "Add rollback validation before implementation starts."
    risks:
      - "Credential handling may be underspecified."
    verification:
      - "rg -n \"rollback|credential|secret\" docs"
  - worker_id: "worker-02"
    assigned_slice: "test gaps"
    status: "complete"
    inspected:
      - "tests/"
    findings:
      - severity: "low"
        summary: "No migration-specific failure-path test was identified."
        evidence:
          - "tests/:example"
        recommendation: "Plan one failure-path test before write-capable work."
    risks:
      - "Regression risk if failure paths remain untested."
    verification:
      - "rg -n \"migration|auth\" tests"
  - worker_id: "worker-03"
    assigned_slice: "rollout risks"
    status: "complete"
    inspected:
      - "docs/project-plan.md"
    findings:
      - severity: "info"
        summary: "Rollout sequencing should name the cutover checkpoint."
        evidence:
          - "docs/project-plan.md:example"
        recommendation: "Add checkpoint criteria to the implementation bead."
    risks:
      - "Ambiguous cutover readiness."
    verification:
      - "rg -n \"cutover|rollback|checkpoint\" docs"
synthesis:
  findings:
    - "Plan rollback, failure-path tests, and cutover checkpoint criteria before write-capable work."
  contradictions:
    - "none"
  blockers:
    - "none for report-only review"
  next_steps:
    - "Use findings to refine the implementation task before any write-capable phase."
transient_report_path: ".codex/state/tmp/minion-20260607T153000Z-auth-migration.md"
```

## Default Count Example

When the prompt omits a count:

```text
$minion Review this project plan for risks and test gaps.
```

The steering plan uses `worker_count_used: 10` and `default_count_applied: true`.

## Write-Heavy Conversion Example

When the prompt asks for implementation:

```text
$minion Use 12 workers to implement this migration across the repo.
```

The readback must not dispatch implementation work. Convert to report-only planning:

```yaml
mode: report-only
worker_count_requested: 12
worker_count_used: 12
default_count_applied: false
scope:
  write_heavy_request: true
  write_capable_phase_deferred: true
synthesis:
  next_steps:
    - "write-capable phase deferred until file-scope and collision-domain planning are complete"
```
