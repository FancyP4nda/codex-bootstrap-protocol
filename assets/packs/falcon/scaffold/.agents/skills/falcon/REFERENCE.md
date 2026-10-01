# State and remote operation

All mutable state is ignored under .codex/state/tmp/falcon:
registry.lock, <id>.json, monitor.json, worktrees/<id> and
attempts/<dispatch-id>/<attempt-id>/report.json + log.jsonl. Dispatch records
carry id, scope, beads, branch, worktree, base, status, prompt, amendments, session,
PID/start identity, current attempt/report/hash, previous attempt evidence,
steering commit/handoff and optional existing PR observations. Reports use
scripts/report.schema.json. `record.report` identifies only the latest accepted
attempt, never a reused `<id>.report.json`; old pre-remediation artifacts remain
available for manual recovery but are not accepted fresh evidence.

For remote work, the user must explicitly specify an SSH host and a workspace.
Use dispatch --paste, adapt the bounded prompt to that workspace and give it to
a Codex CLI worker in an explicitly prepared isolated worktree there, using the
workspace-write sandbox. Example (prepare/select that worktree separately):

```bash
ssh -o BatchMode=yes <explicit-host> codex exec -C <explicit-worktree> --sandbox workspace-write -c 'approval_policy="never"' -
```

Supply the prompt over stdin after reviewing the exact host/workspace. Remote
workers leave changes uncommitted and report source changes/tests/risks back to
authorized remote steering. Local scope locks and local `handoff`/`commit` do not
coordinate/audit a remote filesystem: remote steering must serialize overlapping
work, audit scope and create a reviewed commit before any explicitly authorized
fetch/integration. Missing host or
workspace is a blocker; local dispatch requires no remote infrastructure.
