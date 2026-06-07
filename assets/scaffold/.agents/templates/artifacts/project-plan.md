---
workflow_artifact: project_plan
artifact_version: 1
source_mode: existing_project
status: approved
upstream_ids: [OPP-001]
recommended_next_skill: plan-to-beads-unified
canonical_next_artifact: execution_task
---

# Project Plan

## Parent PRD

`docs/prd.md`

## Planning Assumptions

- Assumption 1
- Assumption 2

## Epics

### E01: Epic Title

- **Goal:** Outcome this epic unlocks.
- **PRD coverage:** PRD section, requirement, or user story references.
- **Completion signal:** Observable indication that the epic is done.

## Tasks

### T001: Task Title

- **Epic:** E01
- **Type:** AFK / HITL
- **Depends on:** None / T000
- **Execution-ready:** Yes / No
- **Parallel-safe:** Yes / No
- **Collision domain:** Files/modules/contracts/data likely to be touched.
- **Can run with:** T000 / Unknown
- **Must not run with:** T000 / None
- **What to build:** One narrow end-to-end behavior.
- **PRD traceability:** PRD section, requirement, or user story references.

**Acceptance criteria**

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

**Agent Handoff Packet**

- **Context to read:** `docs/prd.md` sections, relevant files, or commands.
- **Expected public interface:** UI/API/CLI/event/config/documented behavior.
- **What to build:** One narrow end-to-end behavior.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Relevant security, privacy, compatibility, dependency, rollout, or data constraints.
- **Dependencies:** Hard blockers and assumptions.
- **Parallelization:** Parallel-safe, collision domain, can run with, must not run with.
- **Verification command:** Smallest relevant test/check command, plus broader command if known.
- **Closeout criteria:** Tests pass, acceptance criteria checked, tracker updated, follow-ups filed.

## Recommended Sequence

1. T001 - reason it comes first.
2. T002 - dependency or value rationale.

## Risks And Open Questions

- Risk or question, with the task or epic it affects.

## Handoff To `plan-to-beads-unified`

Use this approved plan plus the parent PRD as input to `plan-to-beads-unified`.

- Convert only `Execution-ready: Yes` tasks into Beads work items.
- Preserve task order, task IDs, epic IDs, dependencies, PRD traceability, Agent Handoff Packets, and parallel-safety metadata.
- Keep `HITL` or `Execution-ready: No` items out of Beads until clarified.
