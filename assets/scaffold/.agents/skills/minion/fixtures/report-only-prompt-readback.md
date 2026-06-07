# Minion Prompt And Readback Fixtures

This fixture shows intended `$minion` prompt shapes and expected readbacks for report-only and execution modes. It is illustrative, not a command transcript.

## Report-Only Prompt

```text
$minion Review the authentication migration plan with parallel Codex subagents.
Use three workers: one for security risks, one for test gaps, and one for rollout risks.
Return report-only findings with file references and suggested verification commands.
```

## Report-Only Steering Plan

```yaml
schema: minion.plan.v2
mode: report-only
worker_count_requested: 3
worker_count_used: 3
default_count_applied: false
max_worker_count: 6
requested_count_capped: false
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

## Report-Only Worker Prompt Template

```text
You are worker-01 for a minion report-only fanout.

Use the project-scoped worker custom agent from .codex/agents/worker.toml when available.

Shared goal: Review the authentication migration plan.
Assigned slice: security risks.
Scope: inspect only the relevant local docs, code references, and verification commands needed for this slice.

Report-only restrictions:
- Do not edit files.
- Do not create commits.
- Do not claim, update, or close Beads issues.
- Do not push changes.
- Do not install dependencies.

Return a worker report using .agents/skills/minion/report-schema.md:
- scope inspected
- evidence
- findings
- assumptions
- risks
- blockers
- suggested verification
```

## Execution Prompt

```text
$minion Work the next ready Beads with parallel workers.
Use up to 6 workers. Implement, verify, and return changed files for parent-session integration.
```

## Execution Steering Plan

```yaml
schema: minion.plan.v2
mode: execution
worker_count_requested: 6
worker_count_used: 3
default_count_applied: false
max_worker_count: 6
requested_count_capped: false
worker_agent: ".codex/agents/worker.toml"
practical_limits_warning: "Execution fanout is capped at 6 workers and still depends on Codex runtime, account, environment, sandbox, approval, token, and local resource constraints."
coordination:
  beads_inspected:
    - "project-123"
    - "project-124"
    - "project-125"
  beads_claimed_by_steering:
    - "project-123"
    - "project-124"
    - "project-125"
  integration_owner: "steering-session"
workers:
  - worker_id: worker-01
    assigned_bead: "project-123"
    assigned_slice: "CLI parser tests"
    allowed_write_scope:
      - "tests/cli/"
  - worker_id: worker-02
    assigned_bead: "project-124"
    assigned_slice: "README command docs"
    allowed_write_scope:
      - "README.md"
      - "docs/cli.md"
  - worker_id: worker-03
    assigned_bead: "project-125"
    assigned_slice: "error message cleanup"
    allowed_write_scope:
      - "src/cli/"
```

## Execution Worker Prompt Template

```text
You are worker-01 for a minion execution fanout.

Use the project-scoped worker custom agent from .codex/agents/worker.toml when available.

Shared goal: Work the selected ready Beads.
Assigned Bead: project-123.
Assigned slice: CLI parser tests.
Allowed write scope:
- tests/cli/

Execution permissions:
- You may edit files only inside the allowed write scope.
- Run the smallest relevant verification command when feasible.
- Preserve unrelated user changes.

Execution restrictions:
- Do not edit files outside the allowed write scope.
- Do not create commits.
- Do not push changes.
- Do not open PRs.
- Do not claim, update, or close Beads issues.
- Do not install dependencies or make network calls.

Return a worker report using .agents/skills/minion/report-schema.md:
- files changed
- summary
- verification commands and results
- risks
- blockers
- integration notes
```

## Execution Readback

```yaml
schema: minion.report.v2
created_utc: "2026-06-07T15:30:00Z"
request:
  original_prompt: "Work the next ready Beads with parallel workers."
  worker_count_requested: 6
  worker_count_used: 3
  default_count_applied: false
  max_worker_count: 6
  requested_count_capped: false
  worker_agent: ".codex/agents/worker.toml"
  mode: "execution"
scope:
  execution_request: true
  write_scopes:
    - worker_id: "worker-01"
      allowed_paths:
        - "tests/cli/"
      bead_id: "project-123"
coordination:
  beads_claimed_by_steering:
    - "project-123"
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
    assigned_slice: "CLI parser tests"
    mode: "execution"
    status: "complete"
    inspected:
      - "tests/cli/"
    changed_files:
      - "tests/cli/parser.test.sh"
    verification:
      - command: "./tests/cli/parser.test.sh"
        result: "passed"
        notes: "parser coverage passed locally"
    risks:
      - "none"
    integration_notes:
      - "ready for steering-session review"
synthesis:
  changed_files:
    - "tests/cli/parser.test.sh"
  verification:
    - command: "./tests/cli/parser.test.sh"
      result: "passed"
      notes: "worker verification accepted by steering session"
  blockers:
    - "none"
  next_steps:
    - "steering session reviews, closes Beads, commits, and pushes"
transient_report_path: ".codex/state/tmp/minion-20260607T153000Z-execute-beads.md"
```

## Default And Cap Example

When the prompt omits a count:

```text
$minion Review this project plan for risks and test gaps.
```

The steering plan uses `worker_count_used: 6` and `default_count_applied: true`.

When the prompt requests more than 6 workers:

```text
$minion Use 12 workers to implement the ready Beads.
```

The steering plan uses `worker_count_requested: 12`, `worker_count_used: 6`, and `requested_count_capped: true`.
