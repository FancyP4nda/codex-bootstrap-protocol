# State and remote operation

All mutable state is ignored under .codex/state/tmp/falcon:
registry.lock, <id>.json, <id>.log.jsonl, <id>.report.json, monitor.json and
worktrees/<id>. Dispatch records carry id, scope, beads, branch, worktree, base,
status, prompt, amendments, session, PID/start identity, report path/hash and
optional existing PR observations. Reports use scripts/report.schema.json.

For remote work, the user must explicitly specify an SSH host and a workspace.
Use dispatch --paste, adapt the bounded prompt to that workspace and give it to
a Codex CLI worker there with --worktree and workspace-write sandbox. Example:

```bash
ssh -o BatchMode=yes <explicit-host> codex exec --worktree -C <explicit-workspace> --sandbox workspace-write -c 'approval_policy="never"' -
```

Supply the prompt over stdin after reviewing the exact host/workspace. Remote
workers report changes/commit IDs back to steering. Local scope locks do not
coordinate a remote filesystem, so steering must serialize overlapping remote
work and verify fetched commit provenance before integration. Missing host or
workspace is a blocker; local dispatch requires no remote infrastructure.
