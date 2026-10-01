---
name: falcon
description: Dispatch scoped implementation to isolated Codex CLI worktrees, inspect reports, queue amendments, resume or cancel workers, and monitor completion locally.
---

Use Falcon when the user requests delegated implementation. Steering owns issue
claims/closure, scoped staging/commits, integration, publication and PR creation.
Workers only implement/test in their isolated worktree, leave changes uncommitted
and return a structured report. Workspace-write protects Git metadata; do not
ask workers to commit or escalate their permissions.

Workers require Linux/WSL subreaper and pidfd support; unsupported platforms
refuse before launch. Cancellation and scope release require kernel-confirmed,
nonce-bound owned-descendant quiescence, not just runner exit. Keep ownership
evidence and inspect failures rather than deleting locks or killing the owner.

Read [COMMANDS.md](COMMANDS.md) for the interface and [PROTOCOL.md](PROTOCOL.md)
before dispatch. Run `python3 <skill-directory>/scripts/falcon.py --root <repo> <command>`.
Literal file/directory scopes are locked until steering explicitly releases a
dispatch. `complete` means valid current-attempt evidence awaiting steering;
it does not mean committed, integrated or closed. Steering runs `handoff`, reviews
the actual scoped diff/tests/risks, and explicitly runs `commit` with the reviewed
report/diff hashes before authorized integration. Read [SYNTHESIS.md](SYNTHESIS.md)
for that boundary and interrupted-commit recovery.

The monitor is an opt-in local process. Use `monitor start`, `monitor status`
and `monitor stop`; it defaults to 30 seconds and installs no service.
Remote workers require an explicit host and workspace; read REFERENCE.md.
