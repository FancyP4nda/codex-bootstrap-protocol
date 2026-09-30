# Starting workflow — Codex Bootstrap Protocol

Bootstrap the target first. Global skills are the default, or choose --local-core.
Artifact templates live in .agents/templates/artifacts; durable project truth
lives in docs. Invoke skills with a dollar prefix, not slash commands.

1. `$brainstormer` develops the raw idea into an Opportunity Brief.
2. `$grill-with-docs` tests domain assumptions, resolves a Decision Brief, updates
   context and records qualifying ADRs.
3. `$product-architect` produces the project PRD from decisions, existing specs or
   interviews. The PRD describes the intended destination.
4. `$project-planner` maps the PRD into reviewed vertical slices and dependencies.
5. Optional `$adversarial-review`: Codex owns revisions, read-only Claude supplies
   cross-provider critique, or isolated Codex supplies a labeled fallback.
6. `$plan-to-beads-unified` bridges an approved plan into Beads; `$refine-beads`
   enriches the next ready work just in time, not an entire backlog speculatively.
7. `$session-start` orients from Git/docs and Beads when present. Claim authorized
   ready work and implement; optional `$falcon dispatch` uses isolated workers.
8. `$session-checkpoint` bounds intermediate context; `$session-wrapup` keeps
   actual architecture, tests, decisions, changelog and handoff current.

Enter at brainstorming for greenfield ideas, product architecture for an existing
spec, or grilling for a brownfield feature. A small fix can start with one well-
formed bead and refinement; it need not earn a full PRD. Ordinary Git sessions
without Beads/scaffold docs use the session skills' fallback.

Falcon is optional, explicitly delegated and local by default. Its stoppable
monitor does not create a service or own integration. Steering owns issue status,
branch integration and authorized publication. No implicit remote background work.

Sessions are disposable; durable repository context makes the next session
re-orientable without depending on hidden personal memory.
