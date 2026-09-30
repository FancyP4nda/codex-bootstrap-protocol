# Development Workflow Blueprint

These workflow rules are installed globally in `~/.agents/bootstrap/instructions/` by `codex-bootstrap` and load in every session. The beads (`bd`) steps apply only in repos that have `.beads/`. Project-specific standards live in each project's `.agents/bootstrap/instructions/development-standards.md`.

| File | Covers |
|------|--------|
| `workflow-planning.md` | Scoping work, creating beads, dependencies, labels, quality checks |
| `workflow-execution.md` | Branching, claim/execute checklists, coding, commits, pull requests |
| `workflow-session.md` | Session startup (`$session-start`), self-optimization, session completion (`$session-wrapup`), handoff |
| `workflow-agents.md` | Multi-agent coordination, Playwright testing |
| `bootstrap-protocol.md` | Pipeline map, project-doc conventions, context-file precedence, standing rules |
