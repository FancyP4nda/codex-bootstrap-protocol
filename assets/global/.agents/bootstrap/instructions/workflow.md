# Development Workflow Blueprint

These referenced guides live alongside the loaded core: global `~/.agents/bootstrap/instructions/` or project `.agents/bootstrap/instructions/` with `--local-core`. They do not auto-load as Codex rules; read relevant guides under applicable user/project instructions. The beads (`bd`) steps apply only in repos that have `.beads/`. Project-specific standards live in each project's `.agents/bootstrap/instructions/development-standards.md`.

| File | Covers |
|------|--------|
| `workflow-planning.md` | Scoping work, creating beads, dependencies, labels, quality checks |
| `workflow-execution.md` | Branching, claim/execute checklists, coding, commits, pull requests |
| `workflow-session.md` | Session startup (`$session-start`), self-optimization, session completion (`$session-wrapup`), handoff |
| `workflow-agents.md` | Multi-agent coordination, Playwright testing |
| `bootstrap-protocol.md` | Pipeline map, project-doc conventions, context-file precedence, standing rules |
