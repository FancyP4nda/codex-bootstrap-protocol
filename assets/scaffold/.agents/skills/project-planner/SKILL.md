---
name: project-planner
description: Create PRD-driven project plans with epics and vertical-slice tasks. Use this skill whenever the user asks to turn a PRD into a project plan, implementation roadmap, epic breakdown, task sequence, delivery plan, or planning artifact before execution tracking.
protocol_version: 1.0
origin: SCAR Labs
cognitive_tier: Structural
---

# Project Planner

## Purpose

Create a single project plan from an approved PRD. The plan groups user-visible outcomes into epics, breaks each epic into independently verifiable vertical-slice tasks, and prepares the approved breakdown for a downstream `plan-to-beads-unified` pass.

Every execution-ready task must include an Agent Handoff Packet so a fresh Codex agent or subagent can implement one Beads task without inferring context from the whole project.

Use this skill upstream of `plan-to-beads-unified`: this skill decides epic and task structure; `plan-to-beads-unified` can later create Beads work items after the user approves the plan.

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

## Canonical Repo Paths

- PRD input: `docs/prd.md`
- Project plan output: `docs/project-plan.md`
- Project plan template: `.agents/templates/artifacts/project-plan.md`
- Glossary: `docs/CONTEXT.md`
- ADRs: `docs/adr/`

## Use When

- The user has a PRD and wants a project plan.
- The user asks for epics, tasks, a roadmap, sequencing, delivery phases, or implementation planning.
- The user wants to prepare a PRD for Beads execution tracking but needs an approved plan first.
- The user asks how to break a PRD into implementation work without immediately creating issue files.

## Inputs

- A PRD file path. If the user does not provide one, default to `docs/prd.md` when it exists; otherwise ask for the path.
- Optional repo context. Inspect only the files needed to understand architecture, existing commands, integration points, and constraints.

## Process

### 1. Read And Ground

1. Read the PRD.
2. Identify upstream opportunity IDs, resolved decisions, user stories, functional requirements, constraints, success metrics, explicit non-goals, assumptions, risks, and open questions.
3. Explore the repository only enough to avoid planning work that conflicts with the existing architecture.
4. State assumptions when missing PRD details affect sequencing, acceptance criteria, security, operations, or user-visible behavior.

### 2. Draft Epics

Create epics around coherent user-visible outcomes, not code components. Each epic should include:

- **Epic ID:** `E01`, `E02`, etc.
- **Title:** Outcome-focused.
- **Goal:** What user or business capability this epic unlocks.
- **PRD coverage:** Referenced PRD sections, requirements, or user stories.
- **Completion signal:** How someone can tell the epic is done.

### 3. Draft Vertical-Slice Tasks

Tasks must be independently verifiable slices of behavior. A task can touch multiple layers, but it should deliver one narrow observable capability.

Each task must include:

- **Task ID:** `T001`, `T002`, etc.
- **Epic:** Owning epic ID.
- **Title:** Action-oriented and concrete.
- **Type:** `AFK` or `HITL`.
- **Depends on:** Task IDs or `None`.
- **What to build:** Concise end-to-end behavior.
- **Acceptance criteria:** Checkbox list of observable outcomes.
- **PRD traceability:** Source requirement, section, or user story.
- **Execution-ready:** `Yes` or `No`.
- **Parallel-safe:** `Yes` or `No`.
- **Collision domain:** Likely files, modules, data models, external contracts, or operational surfaces.
- **Can run with:** Task IDs known to be safe in parallel, or `Unknown`.
- **Must not run with:** Task IDs likely to conflict, or `None`.
- **Agent Handoff Packet:** Complete implementation brief.

Use `AFK` for tasks an implementation agent can complete without additional human decisions. Use `HITL` when the work requires a product, design, security, architecture, credential, compliance, or rollout decision.

### Agent Handoff Packet

For every `Execution-ready: Yes` task, include:

- **Context to read:** Specific PRD sections, project-plan sections, files, docs, or commands to inspect before coding.
- **Expected public interface:** User-facing UI, API, CLI, event, config, or documented behavior to expose or preserve.
- **What to build:** Same narrow end-to-end behavior as the task.
- **Acceptance criteria:** Observable checklist copied from the task.
- **Constraints:** Relevant security, privacy, compatibility, dependency, rollout, or data constraints.
- **Dependencies:** Hard blockers and assumptions.
- **Parallelization:** Parallel-safe, collision domain, can run with, must not run with.
- **Verification command:** Smallest relevant command to prove the task, plus broader command if known.
- **Closeout criteria:** Tests pass, acceptance criteria checked, tracker updated, follow-ups filed.

Hard gate: do not mark a task `Execution-ready: Yes` unless the Agent Handoff Packet includes every field above, stable task ID, dependency status, PRD traceability, and parallelization metadata.

### 4. Sequence The Work

Order tasks so blockers come first. Prefer thin tracer bullets that prove an end-to-end path early, then expand behavior incrementally. Avoid horizontal plans that finish all backend work before any user-visible workflow is verifiable.

Flag risky dependencies explicitly: missing product decisions, design gaps, security/privacy review needs, external services, credentials, cloud changes, data migrations, and parallel execution collisions.

### 5. Review Before Writing

Before creating or updating `docs/project-plan.md`, present the draft plan and ask the user to confirm epic boundaries, task granularity, dependencies, `AFK`/`HITL` classifications, parallel safety, and collision domains.

### 6. Write The Approved Plan

After approval, create or update `docs/project-plan.md` using `.agents/templates/artifacts/project-plan.md`. If `docs/` does not exist, create it.

Do not create downstream tracker items or issue files. End by telling the user that the approved plan is ready for `plan-to-beads-unified`.

## Final Response

After writing the plan, summarize the path written, number of epics and tasks, blocked HITL or unresolved decisions, non-parallel-safe tasks and collision domains, and the recommended next step: run `plan-to-beads-unified` against the approved plan and parent PRD.
