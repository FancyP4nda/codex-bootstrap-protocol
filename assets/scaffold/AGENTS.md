# Agent Instructions

This repository was initialized with the Codex Bootstrap Protocol scaffold.

## Operating Rules

- Treat `docs/CONTEXT.md` as the durable project context entrypoint.
- Use Beads (`bd`) for task tracking when this project has been initialized with it.
- Keep generated scratch data in `.codex/state/tmp/`.
- Keep durable decisions, plans, and handoffs under `docs/`.
- Prefer small, reversible changes that match the local codebase.
- Verify changes with the narrowest relevant command before closeout.
- Never expose secrets, credentials, private keys, or sensitive local state.

## Workflow Pointers

- Read `docs/prd.md` before changing product behavior.
- Read `docs/project-plan.md` before starting implementation slices.
- Record architecture decisions in `docs/adr/`.
- Use `docs/handoff.yaml` for session or subagent handoff state that should persist.
- Use `docs/changelog.yaml` for project-visible change history.
