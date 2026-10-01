---
name: refine-beads
description: Promote triage:backlog or triage:triaged beads to triage:ready by inlining their source PRD/spec section into the bead body, applying the matching work-item template and classification labels, and passing the Readiness Checklist. Use just before beads are claimed (e.g. after plan-to-beads-unified, or for a bead filed by hand), not en masse.
---

# Refine Beads

Turn beads that point at a spec into beads that *contain* their spec, so a fresh session can implement one without further research. This skill only enriches bead bodies, labels and dependencies. It doesn't claim beads, write code, change git state or create new beads.

**Inputs:** one or more bead IDs, and the source doc to inline from (default `docs/prd.md`; plan-to-beads-unified names it in its handoff line). The template family is derived from the bead's type and labels unless the caller specifies it.

**Just in time.** Refine the beads about to be worked, not the whole backlog. Refining later phases early bakes in assumptions that the early work may change. When a project has just been bridged from a plan, refining all of Phase 1 at once is fine, because Phase 1 starts now.

Resolve resources relative to this loaded skill directory, not another global installation. Pass resolved paths to any delegated role.

## Procedure

1. **Read current state.** `bd show <id>` for each bead: title, type, labels (size, cynefin, layer, persona, triage), description, parent and dependencies. Note which sections of its template in [bundled template](work-item-templates.md) are present or missing.
2. **Locate the source section.** Use the bead's title and any inline pointers ("PRD § X", `FR-003`). If there's no pointer and the title is ambiguous, ask rather than guess.
3. **Inline the content.** Fill the template for the bead's type and size (Small/Medium/Large Feature, Bug, Chore, Epic, Decision). Copy verbatim where the source already has the content (acceptance criteria, file paths, commands); paraphrase only to fit the template's structure. Replace any `TBD (refine-beads)` placeholders, including the per-phase **Effort Forecast** (plan/implement/test + `Total: ~N turns` + Confidence), calibrated against comparable closed beads where they exist. If the source itself is missing something, surface the gap instead of inventing it.
4. **Apply classification labels:** `size:*`, `cynefin:*`, one or more `persona:*`, and one or more `layer:*` (matching the files in Changes Needed). Apply them in one call with the repeatable flag:
   `bd update <id> --add-label size:medium --add-label cynefin:complicated --add-label persona:end-user --add-label layer:backend`.
   Avoid `bd label add <id> X Y Z`: its positional arguments are issue IDs, so extra "labels" are treated as bead IDs and fail.
5. **Formalize dependencies.** Every prose "depends on / blocks / after / requires" gets a matching `bd dep add`. Check the result with `bd dep tree <id>`.
6. **Run the Readiness Checklist** in [bundled template](work-item-templates.md) (§ "Readiness Checklist"). Report any failing items by name.
7. **Promote only on a pass:**
   `bd set-state <id> triage=ready --reason "refine-beads: readiness checklist passed"`.
   `bd set-state` swaps the `triage:*` label atomically and records an event bead as the audit trail. Raw `bd label add/remove` leaves no audit trail. If any checklist item fails, set the bead to `triage:triaged`, report the gap, and move on to the next bead.

After a batch of writes, run `bd export -o .beads/issues.jsonl` so the jsonl reflects them.

## Report

For each bead, give: previous → new triage state, what was enriched, labels added, dependencies formalized, and the checklist result (with any failing items). Then list open questions and source-doc gaps, and the next step: usually "claim and execute", or "resolve gaps in <doc>".
