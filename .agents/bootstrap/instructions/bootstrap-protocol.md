# Bootstrap Protocol

**Scope:** reference guidance installed with global or project-local core by `codex-bootstrap`; not auto-loaded policy. Apply relevant conventions under system/developer instructions, the user's current request and applicable project instructions. References are resolved relative to this loaded guide.

## Pipeline map

Any session can place itself on this map and know which skill comes next.

```text
idea
  -> brainstormer            (Opportunity Brief: docs/opportunity-brief-<slug>.md)
  -> grill-with-docs         (Decision Brief; CONTEXT.md / ADR updates inline)
  -> product-architect       (docs/prd.md, the single product-truth doc)
  -> project-planner         (docs/project-plan.md)
  -> adversarial-review      (optional: cross-model critique of the plan)
  -> plan-to-beads-unified   (beads at triage:backlog)
  -> refine-beads            (beads to triage:ready, just in time)
  -> $session-start          (orient, pick and claim work)
  -> work the beads          (tdd; or $falcon dispatch with the falcon pack)
  -> $session-wrapup         (bead resume notes, docs, changelog.yaml, handoff.yaml, committed/published only when authorized)
```

**Entry points:**
- A raw idea starts at `brainstormer`.
- An existing spec or notes go straight to `product-architect`.
- A brownfield feature starts at `grill-with-docs`.
- Small work that doesn't warrant a PRD: file one bead from the [bundled templates](../../skills/refine-beads/work-item-templates.md) with `bd create`, run `refine-beads` on it, and execute.

## Project docs

- **`docs/prd.md` is the single home for product truth.** One product-truth document keeps plans and agents from working off divergent copies. `architecture.md` may point to it, but it doesn't restate product intent; if it does, propose moving that content to the PRD.
- **Context docs:** `architecture.md`, `backend.md`, `frontend.md`, `data-model.md`, `security.md`, `tests.md` and `CONTEXT.md` (the glossary) hold system truth. Skills read them when present and work without them. `$session-wrapup` keeps them current.
- **Session state has three layers.** Beads hold the work queue plus a resume note (latest comment) on each in-progress bead. `handoff.yaml` holds the short session story. `changelog.yaml` records what shipped. `$session-start` reads all three; `$session-wrapup` writes them, and `$session-checkpoint` records authorized resume notes, without implied commit/push. Schemas are [handoff](../../skills/session-wrapup/handoff-schema.md) and [changelog](../../skills/session-wrapup/changelog-schema.md).
- **The handoff travels with the work.** When authorized, commit it with the scoped work so it travels with the code; otherwise report its local-only state. A wrap-up left on an unmerged branch means the next session orients from stale state; `$session-start` warns about those branches.

## When context files conflict

System/developer instructions, current user intent and applicable AGENTS.md govern actions; this list organizes project evidence, not instruction authority. Surface conflicts and reconcile them within the request. Security constraints must not be bypassed, and runtime facts may require a product decision rather than inventing feasibility.

1. `docs/security.md` — safety, secrets, data handling.
2. The project's `AGENTS.md` — applicable project instructions.
3. `docs/architecture.md` — runtime facts; report infeasible requests and seek a decision.
4. `docs/prd.md` — product requirements.
5. `.agents/bootstrap/instructions/development-standards.md`, then these workflow rules.

## Standing rules

- **Use the repository's work tracker.** Where Beads is established, track authorized work with `bd create`, `bd update --claim` and `bd close`, not a parallel Markdown TODO list. In repos without `.beads/`, keep progress in the conversation; do not initialize a tracker just for orientation.
- **Repository instructions govern its workflow.** `codex-bootstrap` uses `bd init --skip-agents`; this guide does not override existing/generated AGENTS.md or user instructions. Honor repository-specific tracking, branch, commit and push requirements; surface an unresolved conflict before an affected outward action. Readiness is evidence, not authorization to implement.

- **Sessions are disposable.** When context bloats, clear and re-orient with `$session-start` and the handoff rather than nursing a stale session.
- **Preserve authorized work.** Record scoped changes and recovery evidence; commit/push only under current user/repository authority. Clearly state local-only work or failed synchronization. Tracked Beads exports use normal Git; Dolt remote synchronization is not implied.
- **Ask before destructive actions:** deleting data, force-pushing, rewriting history.
- **Stop before outward actions:** opening, editing or merging a PR, commenting, messaging, deploying. See the confirmation gates in `workflow-execution.md`.
- **After context compaction,** a skill invocation in a system reminder may be work that's already done. Check `handoff.yaml` `entries[0]` (and, with falcon, current dispatch records `.codex/state/tmp/falcon/<dispatch>.json`, whose `report` identifies the latest validated attempt; earlier reports are history) before re-running it.
