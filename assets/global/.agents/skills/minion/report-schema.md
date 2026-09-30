# Minion Report And Execution Schema

`minion` summaries come from explicit Codex subagent fanout. They may describe report-only analysis or guarded write-capable execution. They may be returned inline or stored transiently under `.codex/state/tmp/minion-*`.

## Path Convention

```text
.codex/state/tmp/minion-<UTC timestamp>-<short slug>.md
```

Use UTC timestamps formatted as `YYYYMMDDTHHMMSSZ`. Keep slugs short, lowercase, and descriptive.

## Steering Report

```yaml
schema: minion.report.v2
created_utc: "YYYY-MM-DDTHH:MM:SSZ"
request:
  original_prompt: "<user request summary>"
  worker_count_requested: null
  worker_count_used: 6
  default_count_applied: true
  max_worker_count: 6
  requested_count_capped: false
  worker_agent: ".codex/agents/worker.toml"
  mode: "report-only|execution"
limits_warning: "<Codex runtime/account/environment/sandbox/token warning, when relevant>"
scope:
  included:
    - "<path, module, risk area, issue, or question>"
  excluded:
    - "<out-of-scope item>"
  execution_request: false
  write_scopes:
    - worker_id: "worker-01"
      allowed_paths:
        - "<path or module>"
      bead_id: "<optional Beads issue id>"
coordination:
  beads_claimed_by_steering:
    - "<issue id or none>"
  integration_owner: "steering-session"
  commit_owner: "steering-session"
  push_owner: "steering-session"
deferred_scope:
  locks: true
  cron_watch: true
  auto_amend: true
  auto_ack: true
  cross_branch_orchestration: true
  pr_actions: true
workers:
  - worker_id: "worker-01"
    assigned_slice: "<slice>"
    mode: "report-only|execution"
    status: "complete|blocked|partial"
    inspected:
      - "<file or command>"
    changed_files:
      - "<execution mode only; file changed by worker>"
    findings:
      - severity: "info|low|medium|high|critical"
        summary: "<finding>"
        evidence:
          - "<file:line or command evidence>"
        recommendation: "<recommendation>"
    verification:
      - command: "<command>"
        result: "passed|failed|not-run"
        notes: "<short notes>"
    risks:
      - "<risk or none>"
    integration_notes:
      - "<merge, conflict, or follow-up notes>"
synthesis:
  findings:
    - "<deduplicated finding>"
  changed_files:
    - "<integrated changed file>"
  verification:
    - command: "<combined steering command>"
      result: "passed|failed|not-run"
      notes: "<short notes>"
  contradictions:
    - "<worker disagreement or none>"
  blockers:
    - "<blocker or none>"
  next_steps:
    - "<next step>"
transient_report_path: ".codex/state/tmp/minion-YYYYMMDDTHHMMSSZ-<slug>.md"
```

## Worker Report: Report-Only Mode

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

## Worker Report: Execution Mode

```yaml
worker_id: "worker-01"
assigned_slice: "<implementation slice>"
assigned_bead: "<optional Beads issue id>"
mode: "execution"
status: "complete|blocked|partial"
allowed_write_scope:
  - "<path or module>"
files_changed:
  - "<path changed by worker>"
scope_inspected:
  - "<file, directory, command, doc section, or issue>"
summary:
  - "<implemented behavior or attempted work>"
verification:
  - command: "<command>"
    result: "passed|failed|not-run"
    notes: "<short notes>"
risks:
  - "<risk or none>"
blockers:
  - "<blocker or none>"
integration_notes:
  - "<merge, conflict, cleanup, or follow-up notes>"
```

## Guardrails

- Reports are not durable state.
- Execution worker output is not complete until the steering session reviews, integrates, verifies, and commits it.
- Workers do not push, open PRs, or create commits.
- Workers do not claim, update, or close Beads unless the steering session explicitly delegates that exact Beads operation.
- Execution fanout requires disjoint write scopes and parent-session integration.
- The following remain deferred-scope only: locks, cron/watch, auto-amend, auto-ack, cross-branch orchestration, and PR actions.
