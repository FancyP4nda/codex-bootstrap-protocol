# Bootstrap Protocol

**Scope:** installed globally by `codex-bootstrap`. The pipeline and doc conventions below apply in repos bootstrapped with the kit, which have `docs/`. The standing rules apply everywhere.

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
  -> work the beads          (tdd; or $falcon work beads with the falcon pack)
  -> $session-wrapup         (bead resume notes, docs, changelog.yaml, handoff.yaml, committed on the work branch)
```

**Entry points:**
- A raw idea starts at `brainstormer`.
- An existing spec or notes go straight to `product-architect`.
- A brownfield feature starts at `grill-with-docs`.
- Small work that doesn't warrant a PRD: file one bead from `~/.agents/skills/refine-beads/work-item-templates.md` with `bd create`, run `refine-beads` on it, and execute.

## Project docs

- **`docs/prd.md` is the single home for product truth.** One product-truth document keeps plans and agents from working off divergent copies. `architecture.md` may point to it, but it doesn't restate product intent; if it does, propose moving that content to the PRD.
- **Context docs:** `architecture.md`, `backend.md`, `frontend.md`, `data-model.md`, `security.md`, `tests.md` and `CONTEXT.md` (the glossary) hold system truth. Skills read them when present and work without them. `$session-wrapup` keeps them current.
- **Session state has three layers.** Beads hold the work queue plus a resume note (latest comment) on each in-progress bead. `handoff.yaml` holds the short session story. `changelog.yaml` records what shipped. `$session-start` reads all three; `$session-wrapup` writes them, and `$session-checkpoint` writes just the bead notes plus a commit. Schemas are in `~/.agents/skills/session-wrapup/`.
- **The handoff travels with the work.** Wrap-up commits it on the session's work branch, so it merges along with the code. A wrap-up left on an unmerged branch means the next session orients from stale state; `$session-start` warns about those branches.

## When context files conflict

The higher item wins. State the conflict and both sources, then propose the smallest edit that reconciles them, starting with the lower-precedence file.

1. `docs/security.md` — safety, secrets, data handling.
2. The project's `AGENTS.md` — project conventions.
3. `docs/architecture.md` — runtime facts. A real constraint here outranks an incompatible feature request.
4. `docs/prd.md` — product requirements.
5. `.agents/bootstrap/instructions/development-standards.md`, then these workflow rules.

## Standing rules

- **Beads is the only work tracker.** Track work as beads (`bd create`, `bd update --claim`, `bd close`), not bd create/bd create lists or markdown TODOs. In repos without `.beads/`, keep progress in the conversation.
- **These rules win over bd's generated instructions.** `codex-bootstrap` runs `bd init --skip-agents`, so bd doesn't add its own `AGENTS.md`/`AGENTS.md` block or `bd prime` hook. If a repo has them anyway (older setup, or `bd setup` run by hand), follow these rules on pushing (feature branches freely, never `main` without asking), ending a session (`$session-wrapup`, keeping remote branches), and issue types (no `task` type; see the Readiness Checklist).

- **Sessions are disposable.** When context bloats, clear and re-orient with `$session-start` and the handoff rather than nursing a stale session.
- **Work persists by being pushed.** Push to the feature branch as the normal way work persists; nothing is "done" until it's on origin.
- **Ask before destructive actions:** deleting data, force-pushing, rewriting history.
- **Stop before outward actions:** opening, editing or merging a PR, commenting, messaging, deploying. See the confirmation gates in `workflow-execution.md`.
- **After context compaction,** a skill invocation in a system reminder may be work that's already done. Check `handoff.yaml` `entries[0]` (and, with falcon, `.codex/state/tmp/falcon-reports-<branch>.yaml`) before re-running it.
