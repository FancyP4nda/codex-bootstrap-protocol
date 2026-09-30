---
name: falcon
description: Dispatch scoped implementation to isolated Codex CLI worktrees, inspect reports, queue amendments, resume or cancel workers, and monitor completion locally.
---

Use Falcon when the user requests delegated implementation. Steering owns issue
claims/closure, integration, publication and PR creation. Workers only implement,
verify, commit to their isolated branch and return a structured report.

Read [COMMANDS.md](COMMANDS.md) for the interface and [PROTOCOL.md](PROTOCOL.md)
before dispatch. Run `python3 <skill-directory>/scripts/falcon.py --root <repo> <command>`.
Literal file/directory scopes are locked until steering explicitly releases a
dispatch. A complete worker report does not imply integration or issue closure.

The monitor is an opt-in local process. Use `monitor start`, `monitor status`
and `monitor stop`; it defaults to 30 seconds and installs no service.
Remote workers require an explicit host and workspace; read REFERENCE.md.
