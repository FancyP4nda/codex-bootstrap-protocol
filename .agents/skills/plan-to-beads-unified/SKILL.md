---
name: plan-to-beads-unified
description: Convert an approved docs/project-plan.md into Beads backlog items by mapping execution-ready Agent Handoff Packets onto work-item bodies while preserving task IDs, epic IDs, PRD traceability, and parallelization metadata.
protocol_version: 1.0
origin: SCAR Labs
cognitive_tier: Execution
---

# Plan To Beads Unified

## Purpose

Convert an approved project plan into Beads backlog items. This bridge creates work items from execution-ready Agent Handoff Packets and stops before implementation readiness refinement.

```text
docs/prd.md
  -> project-planner
  -> docs/project-plan.md (status: approved)
  -> plan-to-beads-unified
  -> Beads items at triage:backlog
  -> readiness refinement
  -> tdd
```

## Division Of Labor

| Concern | Owner |
|---|---|
| Bead creation, field mapping, traceability | This bridge |
| `task:`, `epic:`, area labels, `parallel-safe` | This bridge when present in the plan |
| Effort forecast with low confidence | This bridge |
| `size:`, `cynefin:`, `persona:`, `layer:` labels | Readiness refinement |
| Promotion from `triage:backlog` to ready state | Readiness refinement |

Hard rule: write `TBD (readiness refinement)` wherever a classification label or judgment-bound section is required but cannot be derived deterministically from the plan. Never fabricate `size:`, `cynefin:`, `persona:`, or `layer:` values.

## Inputs

- Required: an approved `docs/project-plan.md`. Its frontmatter must contain `status: approved`.
- Required for traceability: the parent `docs/prd.md` referenced by the plan.

If the user provides only a PRD with no approved plan, stop and tell them to run `project-planner` and get the plan approved first. Do not decompose raw PRDs in this skill.

## Canonical Repo Paths

- Project plan: `docs/project-plan.md`
- Parent PRD: `docs/prd.md`
- Project glossary: `docs/CONTEXT.md`
- Beads tracker: `.beads/`

## Process

### Step 1: Gate On Plan Approval

Read `docs/project-plan.md`. Check the frontmatter for `status: approved`.

- If `status` is missing, `draft`, `in_review`, or anything other than `approved`, create no beads and report the actual status.
- If `status: approved`, continue.

### Step 2: Verify Beads Is Available

```bash
command -v bd
```

If `bd` is unavailable, stop and tell the user Beads must be installed first. Do not install it. If `.beads/` is missing, ask before running `bd init`.

### Step 3: Select Tasks To Convert

From the approved plan, select only tasks marked `Execution-ready: Yes`.

Skip:

- Tasks marked `Execution-ready: No`.
- Tasks marked `HITL`.
- Tasks with incomplete Agent Handoff Packets.

For every selected task, confirm its Agent Handoff Packet includes at minimum what to build, acceptance criteria, dependencies, parallelization metadata, verification command, and closeout criteria. If a packet is incomplete, surface it and ask the user to revise the plan.

### Step 4: Choose The Work Item Type

Pick the Beads type from the plan:

| Plan signal | `bd --type` |
|---|---|
| New capability | `feature` |
| Broken existing behavior | `bug` |
| Maintenance, config, cleanup, docs-only update | `chore` |

If the plan does not state scope clearly enough, default to `feature` and flag size/classification as `TBD (readiness refinement)`.

### Step 5: Map Agent Handoff Packet Fields

Create a bead body that preserves the plan's content instead of summarizing away required fields.

Use this header on every task bead:

```text
Source plan: docs/project-plan.md
Parent PRD: docs/prd.md
Plan task: T001
Epic: E01
Triage: backlog (bridge-created; awaiting readiness refinement)
Classification: size/cynefin/persona/layer = TBD (readiness refinement)
Collision domain: <verbatim from plan>
Parallel-safe: <Yes|No, verbatim from plan>
Can run with: <verbatim or none>
Must not run with: <verbatim or none>
```

Mapping:

- **What to build** -> Summary and Changes Needed.
- **Acceptance criteria** -> Acceptance Criteria checklist.
- **Expected public interface** -> API Contract / Frontend Component / documented interface note.
- **Constraints** -> Scope Boundaries.
- **Collision domain** and parallelization metadata -> Scope Boundaries plus labels when factual.
- **Verification command** -> Testing Strategy.
- **PRD traceability** -> PRD Traceability.
- **Depends on** -> Beads dependency edge after all task beads exist.
- **Epic** -> parent epic bead plus `epic:E01` label.

### Step 6: Labels

Carry only factual labels from the plan:

- `task:T001`
- `epic:E01`
- Area labels explicitly named or obvious in the plan.
- `parallel-safe` only when the plan says `Parallel-safe: Yes`.

Never apply `size:*`, `cynefin:*`, `persona:*`, or `layer:*`.

### Step 7: Create Beads At Backlog State

Create epics first, then tasks, then dependency edges. Use non-interactive commands.

```bash
bd create "E01: <epic title>" --type epic -l "epic:E01"
bd create "T001: <task title>" --type feature -l "task:T001,epic:E01,parallel-safe" --parent <epic-id> --body-file /tmp/bead-T001-body.md
bd set-state <task-id> triage=backlog --reason "plan-to-beads-unified: bridge-created from approved plan, awaiting readiness refinement"
bd dep add <task-id> <blocker-id> -t blocks
```

Do not create duplicate beads for plan IDs that already exist. Report the existing mapping and create only missing beads.

### Step 8: Export And Handoff

After all beads, labels, dependencies, and states are in place:

```bash
bd export -o .beads/issues.jsonl
```

End with a handoff line that names the readiness refinement workflow available in the target project and lists the task bead IDs. Recommend refining only the beads whose phase is starting now.

## Output Format

Return a concise report:

- Plan path and approval status confirmed.
- Epics created.
- Task beads created, each with type and triage state.
- Tasks skipped and why.
- Classification fields left as `TBD (readiness refinement)`.
- Dependencies formalized.
- Plan gaps surfaced.
- Readiness refinement handoff line.

## Hard Rules

1. Require `status: approved` on `docs/project-plan.md`.
2. Skip non-execution-ready and HITL tasks.
3. Never fabricate `size:`, `cynefin:`, `persona:`, or `layer:` labels.
4. Create beads at `triage:backlog` only.
5. Preserve sequencing metadata.
6. Maintain PRD traceability.
7. Do not initialize Beads, install dependencies, or mutate tracker state without user intent.
