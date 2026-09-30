---
name: plan-to-beads-unified
description: Bridge an approved docs/project-plan.md into beads at triage:backlog, one per execution-ready task under epic beads, with work-item templates, dependencies and PRD traceability, ending with a refine-beads handoff. Use after the plan is approved. Doesn't decompose raw PRDs or promote beads to triage:ready (refine-beads does that).
---

# Plan to Beads

The bridge between planning and execution. It turns an approved project plan into template-shaped beads at `triage:backlog`, filling as much of each work-item template as the plan factually supports, then hands off to `refine-beads`. refine-beads inlines the rest of the spec, classifies the beads, runs the Readiness Checklist and promotes them to `triage:ready`.

```text
PRD -> project-planner -> project-plan.md (status: approved)
    -> plan-to-beads-unified -> beads at triage:backlog
    -> refine-beads -> triage:ready -> claim & execute
```

## Division of labor

| Concern | Owner |
|---|---|
| Bead creation, field mapping, traceability, dependencies | this skill |
| `task:`, `epic:`, area and `parallel-safe` labels (verbatim in the plan) | this skill |
| `size:`, `cynefin:`, `persona:`, `layer:` labels, Effort Forecast | refine-beads |
| Inlining the full PRD spec, Readiness Checklist, `triage:ready` | refine-beads |

Where a refine-beads field can't be derived mechanically from the plan, write `TBD (refine-beads)`. A guessed `cynefin:clear` or `size:small` on an unexamined task makes a bead look ready when it isn't, which is exactly the failure the readiness gate exists to catch.

## Process

1. **Check approval.** Read `docs/project-plan.md`.
   - Continue only if its frontmatter says `status: approved`. Otherwise create nothing, and report the status and that the plan needs approving first. An unapproved plan may still change, and beads made from it would drift.
   - If the user has only a PRD, point them to `project-planner`.
2. **Check bd.** Run `command -v bd` and confirm `.beads/` exists.
   - If `bd` is missing, stop and say it needs installing.
   - If `.beads/` is missing, suggest `bd init`, which the bootstrap installer normally runs.
   - Don't install or initialize either yourself.
3. **Select tasks.** Take only tasks marked `Execution-ready: Yes`.
   - Skip `Execution-ready: No` and `HITL` tasks, and list them in the report. HITL tasks are human decisions; track them as beads only if the user asks.
   - `Execution-ready: Yes` means project-planner already checked the Agent Handoff Packet, so don't re-grade it. If a task plainly lacks a packet, ask for the plan to be fixed.
4. **Skip existing beads.** Run `bd list --label task:<id> --limit 0` (and `--label epic:<id>`) and reuse beads that already exist for a plan ID. `--limit 0` matters: `bd list` otherwise stops at 50 results without warning.
5. **Choose a template** from `~/.agents/skills/refine-beads/work-item-templates.md`:

   | Plan signal | `--type` | Template |
   |---|---|---|
   | New capability, 1 layer | `feature` | Small Feature |
   | New capability, 2 layers or a migration | `feature` | Medium Feature |
   | Full-stack, new entity, or 3+ layers | `feature` | Large Feature |
   | Fixes broken behavior | `bug` | Bug |
   | Maintenance, no behavior change | `chore` | Chore |

   If the scope is unclear, use Medium and note the size as `TBD (refine-beads)`.
6. **Map the plan fields onto the template.** Copy verbatim wherever the plan has the content:

   | Plan field | Bead section |
   |---|---|
   | What to build | **Summary** + **Changes Needed** (file-scoped if the plan lists files, else `TBD (refine-beads)`) |
   | Acceptance criteria | **Acceptance Criteria**, verbatim as a `- [ ]` checklist |
   | Expected public interface | **API Contract** / **Frontend Component** (Medium+); for Small, a note in Changes Needed |
   | Constraints | **Scope Boundaries** |
   | Collision domain, Parallel-safe, Can/Must-not run with | the `parallel-safe` label (only if `Yes`), plus these fields verbatim in the header block, for later sequencing |
   | Verification command | **Testing Strategy** |
   | PRD traceability | a link line, e.g. `Traceability: <parent PRD> FR-001, US-003` |
   | Depends on | a `bd dep add` edge (step 8) |
   | Epic | a parent epic bead with an `epic:E01` label |

   Start each bead body with this header block:

   ```text
   Source plan: docs/project-plan.md
   Parent PRD: <the plan's Parent PRD; docs/prd.md if none>
   Plan task: T001
   Epic: E01
   Triage: backlog (bridge-created; awaiting refine-beads)
   Classification: size/cynefin/persona/layer = TBD (refine-beads)
   Effort Forecast: TBD (refine-beads)
   Collision domain: <verbatim>
   Parallel-safe: <Yes|No>
   Can run with: <verbatim or none>
   Must not run with: <verbatim or none>
   ```
7. **Preview.** Show one mapping table (plan ID → template, labels, parent epic; skipped tasks and why) and confirm once before writing to bd, unless the user has already said to go ahead. Many beads are tedious to undo.
8. **Create** epics first, then tasks, capturing each bead ID:

   ```bash
   bd create "E01: <epic title>" --type epic -l "epic:E01"
   bd create "T001: <task title>" --type feature \
     -l "task:T001,epic:E01,backend,parallel-safe" \
     --parent <epic-id> --body-file "$TMPDIR/bead-T001.md"
   bd set-state <id> triage=backlog --reason "plan-to-beads-unified: bridge-created from approved plan"
   ```

   - `-l` takes one comma-separated list.
   - `--body-file` keeps the template body intact.
   - `bd set-state` records an audit event and guarantees a single `triage:*` label.

   Once every bead exists, add the dependency edges: `bd dep add <T001-id> <T002-id> -t blocks` means T001 is blocked by T002. Check with `bd dep tree <id>` that the edges match the plan.
9. **Export** with `bd export -o .beads/issues.jsonl`.

## Report

- **Plan:** path, with approval confirmed.
- **Created:** epics and tasks (plan ID → bead ID, with each task's template).
- **Skipped:** tasks not converted, and why.
- **Dependencies:** the edges added.
- **Plan gaps:** anything missing in the plan.
- **Handoff line:** end with this, listing the task beads (epics aren't refined):

```text
Run the refine-beads skill on <id1>,<id2>,... (source: <parent PRD>) to promote them to triage:ready.
```

Suggest refining only the beads whose phase starts now, not the whole backlog.
