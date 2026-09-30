---
name: project-planner
description: Create PRD-driven project plans with epics and vertical-slice tasks. Use this skill whenever the user asks to turn a PRD into a project plan, implementation roadmap, epic breakdown, task sequence, delivery plan, or planning artifact before execution tracking. This skill is especially relevant when a downstream plan-to-beads-unified handoff is expected.
---

# Project Planner

## Purpose

Create a single project plan from a PRD. The plan groups user-visible outcomes into epics, breaks each epic into independently verifiable vertical-slice tasks, and prepares the approved breakdown for a downstream `plan-to-beads-unified` pass.

Every execution-ready task must include an Agent Handoff Packet so a fresh agent or sub-agent can implement one Beads task without inferring context from the whole project.

Use this skill upstream of `plan-to-beads-unified`: this skill decides the epic/task structure; `plan-to-beads-unified` can later create Beads work items after the user approves the plan.

## Workflow Artifact Contract

Accept `prd` artifacts as the normal input. Before planning, verify that any PRD frontmatter agrees with the Markdown body on source mode, upstream IDs, status, and recommended next skill. If the PRD is `status: blocked`, do not create execution-ready tasks for blocked scope.

Emit project plans with this routing frontmatter:

```yaml
---
workflow_artifact: project_plan
artifact_version: 1
source_mode: new_idea | existing_project
status: draft | approved | blocked
upstream_ids: [OPP-001]
recommended_next_skill: plan-to-beads-unified
canonical_next_artifact: execution_task
---
```

## Use When

- The user has a PRD and wants a project plan.
- The user asks for epics, tasks, a roadmap, sequencing, delivery phases, or implementation planning.
- The user wants to prepare a PRD for Beads execution tracking but needs an approved plan first.
- The user asks how to break a PRD into implementation work without immediately creating issue files.

## Inputs

- The PRD: `docs/prd.md` unless the user names another path (ask only if neither exists). Plan from a PRD with `status: approved`; if it is still `draft` or `blocked`, say so and ask whether to proceed.
- Optional repo context. Inspect only the files needed to understand architecture, existing commands, integration points, and constraints.

## Default Output

Write one Markdown artifact to:

```text
docs/project-plan.md
```

If the user requests a different path, use that path instead. Do not create local task issue files in this skill.

Canonical template:

`.agents/templates/artifacts/project-plan.md` in the project if present, otherwise [`templates/project-plan.md`](./templates/project-plan.md) in this skill.

## Process

### 1. Read and ground

1. Read the PRD.
2. Identify upstream opportunity IDs, resolved decisions, user stories, functional requirements, constraints, success metrics, explicit non-goals, assumptions, risks, and open questions.
3. Explore the repository only enough to avoid planning work that conflicts with the existing architecture.
4. State assumptions when missing PRD details affect sequencing, acceptance criteria, security, operations, or user-visible behavior.

### 2. Draft epics

Create epics around coherent user-visible outcomes, not code components. Each epic should have:

- **Epic ID**: `E01`, `E02`, etc.
- **Title**: outcome-focused.
- **Goal**: what user or business capability this epic unlocks.
- **PRD coverage**: referenced PRD sections, requirements, or user stories.
- **Completion signal**: how someone can tell the epic is done.

Prefer a small number of meaningful epics over many thin categories.

### 3. Draft vertical-slice tasks

Tasks must be independently verifiable slices of behavior. A task can touch multiple layers, but it should deliver one narrow observable capability.

Each task should have:

- **Task ID**: `T001`, `T002`, etc.
- **Epic**: the owning epic ID.
- **Title**: action-oriented and concrete.
- **Type**: `AFK` or `HITL`.
- **Depends on**: task IDs or `None`.
- **What to build**: concise end-to-end behavior.
- **Acceptance criteria**: checkbox list of observable outcomes.
- **PRD traceability**: source requirement, section, or user story.
- **Execution-ready**: `Yes` when it can be sent to `plan-to-beads-unified`; `No` when it needs human clarification first.
- **Parallel-safe**: `Yes` when it can run alongside other ready tasks without likely file, schema, data, contract, or rollout conflicts.
- **Collision domain**: likely files, modules, data models, external contracts, or operational surfaces this task may touch.
- **Can run with**: task IDs known to be safe in parallel, or `Unknown`.
- **Must not run with**: task IDs likely to conflict, or `None`.
- **Agent Handoff Packet**: complete implementation brief described below.

Use `AFK` for tasks an implementation agent can complete without additional human decisions. Use `HITL` when the work requires a product, design, security, architecture, credential, compliance, or rollout decision.

### Agent Handoff Packet

This packet is the kit's single definition of "execution-ready": plan-to-beads-unified trusts it, and refine-beads builds on it. For every `Execution-ready: Yes` task, include a packet with:

- **Context to read:** specific PRD sections, project-plan sections, files, docs, or commands to inspect before coding.
- **Expected public interface:** user-facing UI, API, CLI, event, config, or documented behavior the implementation must expose or preserve.
- **Constraints:** security, privacy, compatibility, dependency, rollout, or data constraints relevant to this task.
- **Dependencies:** hard blockers and assumptions needed before starting.
- **Verification command:** smallest relevant command to prove the task, plus broader command if known.
- **Closeout criteria:** tests pass, acceptance criteria checked, tracker updated, and follow-ups filed.

(What to build, acceptance criteria and parallelization already live in the task fields above; don't repeat them in the packet.)

Don't mark a task `Execution-ready: Yes` unless the packet has every field above and the task has its ID, dependency status, PRD traceability and parallelization metadata. Mark incomplete tasks `Execution-ready: No` and explain the missing decision or artifact.

### 4. Sequence the work

Order tasks so blockers come first. Prefer thin tracer bullets that prove an end-to-end path early, then expand behavior incrementally. Avoid horizontal plans that finish all backend work before any user-visible workflow is verifiable.

Flag risky dependencies explicitly:

- Unknown product decisions.
- Missing designs or copy.
- Security or privacy review needs.
- External service access, credentials, or cloud changes.
- Data migration or compatibility concerns.
- Parallel execution collisions between tasks that touch the same files, schemas, contracts, or rollout surface.

### 5. Write the draft and review it

Write the plan to `docs/project-plan.md` (create `docs/` if needed) from the template, with `status: draft`. Then summarize it and ask the user to confirm the calls you are least sure of:

- Whether epic boundaries are correct.
- Whether task granularity is too coarse or too fine.
- Whether dependencies and `AFK`/`HITL` classifications are accurate.
- Whether parallel-safety and collision-domain calls are accurate.
- Whether any tasks should be merged, split, added, or removed.

Revise the file until the user approves, then set `status: approved`. plan-to-beads-unified only converts an approved plan, so if the plan changes after approval (including edits from adversarial-review), set it back to `draft` and re-confirm.

## Project Plan Template

Use `.agents/templates/artifacts/project-plan.md`. Preserve its frontmatter, epics, task fields, Agent Handoff Packet, sequence, risk/open-question, and handoff sections unless a section is explicitly not applicable.

## Constraints

- Do not create GitHub, Jira, Linear, or other external tickets unless the user explicitly asks.
- Do not create Beads items or local issue files; use `plan-to-beads-unified` for Beads tracking after the user approves the plan.
- Do not invent PRD requirements. Mark missing information as an assumption, risk, or open question.
- Do not plan purely horizontal component phases unless the PRD is explicitly only about internal architecture.
- Keep task IDs stable once shown to the user; if the plan changes, preserve unchanged IDs where practical.
- Do not mark tasks `Parallel-safe: Yes` when they share a likely collision domain unless the plan explains why concurrent execution is safe.

## Final Response

After writing the plan, summarize:

- The path written.
- Number of epics and tasks.
- Any tasks blocked by `HITL` or missing decisions.
- Any tasks that are not parallel-safe and the collision domain that makes them risky.
- The recommended next step: optionally `adversarial-review` for a second-model critique, then `plan-to-beads-unified` against the approved plan.
