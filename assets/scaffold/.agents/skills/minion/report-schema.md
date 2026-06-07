# Minion Report Schema

`minion` reports are report-only summaries from explicit Codex subagent fanout. They may be returned inline or stored transiently under `.codex/state/tmp/minion-*`.

## Path Convention

```text
.codex/state/tmp/minion-<UTC timestamp>-<short slug>.md
```

Use UTC timestamps formatted as `YYYYMMDDTHHMMSSZ`. Keep slugs short, lowercase, and descriptive.

## Steering Report

```yaml
schema: minion.report.v1
created_utc: "YYYY-MM-DDTHH:MM:SSZ"
request:
  original_prompt: "<user request summary>"
  worker_count_requested: null
  worker_count_used: 10
  default_count_applied: true
  worker_agent: ".codex/agents/worker.toml"
  mode: "report-only"
limits_warning: "<Codex runtime/account/environment constraints warning, when relevant>"
scope:
  included:
    - "<path, module, risk area, or question>"
  excluded:
    - "<out-of-scope item>"
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
    assigned_slice: "<slice>"
    status: "complete"
    inspected:
      - "<file or command>"
    findings:
      - severity: "info|low|medium|high|critical"
        summary: "<finding>"
        evidence:
          - "<file:line or command evidence>"
        recommendation: "<report-only recommendation>"
    risks:
      - "<risk or none>"
    verification:
      - "<suggested command>"
synthesis:
  findings:
    - "<deduplicated finding>"
  contradictions:
    - "<worker disagreement or none>"
  blockers:
    - "<blocker or none>"
  next_steps:
    - "<report-only next step>"
transient_report_path: ".codex/state/tmp/minion-YYYYMMDDTHHMMSSZ-<slug>.md"
```

## Worker Report

Each worker returns this shape to the steering session:

```yaml
worker_id: "worker-01"
assigned_slice: "<slice>"
mode: "report-only"
status: "complete|blocked|partial"
scope_inspected:
  - "<file, directory, command, doc section, or issue>"
evidence:
  - reference: "<file:line, command, or doc section>"
    note: "<what the evidence supports>"
findings:
  - severity: "info|low|medium|high|critical"
    summary: "<short finding>"
    evidence:
      - "<supporting reference>"
    recommendation: "<what steering should consider>"
assumptions:
  - "<assumption or none>"
risks:
  - "<risk or none>"
blockers:
  - "<blocker or none>"
suggested_verification:
  - "<command or inspection step>"
```

## V1 Guardrails

- Reports are not durable state.
- Reports are not an implementation worker transcript.
- Reports do not authorize edits, commits, Beads closure, pushes, or PR actions.
- Write-heavy fanout must be converted to report-only planning/review or marked `write-capable phase deferred`.
- The following are deferred-scope only in v1: locks, cron/watch, auto-amend, auto-ack, cross-branch orchestration, PR actions, and write-capable implementation workers.
