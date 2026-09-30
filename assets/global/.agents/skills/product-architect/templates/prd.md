---
workflow_artifact: prd
artifact_version: 1
source_mode: new_idea | existing_project
status: draft
upstream_ids: [OPP-001]
recommended_next_skill: project-planner
canonical_next_artifact: project_plan
---

# Product Requirements Document: <feature name>

<!-- Template, not a form. Keep every section; write as many goals, requirements, stories,
     metrics, assumptions, questions and risks as the product needs (the single examples show the
     ID scheme). Write "None" or "Not applicable" rather than deleting a section, and "Unknown"
     rather than inventing a value. -->

## 1. Executive Summary

- **Target persona:** <target persona>
- **Core problem:** <problem statement>
- **Business goal:** <business goal>
- **Product outcome:** <product outcome>
- **Status:** Draft / Approved / Superseded

## 2. Upstream Traceability

- **Source opportunity IDs:** <source opportunity ids>
- **Decision brief:** <decision brief reference>
- **Key resolved decisions:** <key resolved decisions>
- **Key unresolved HITL decisions:** <key unresolved decisions>
- **Repo grounding:** <repo grounding reference>

## 3. Scope

### Goals

- **G-001:** <goal 1>

### Non-Goals

- **NG-001:** <non goal 1>

## 4. Users and Use Cases

### Personas

- **P-001:** <persona 1>

### Primary Use Cases

- **UC-001:** <use case 1>

## 5. Functional Requirements

Each requirement must describe externally observable product behavior. Use stable IDs so downstream plans and tasks can preserve traceability.

- **FR-001:** <functional requirement 1>
  - **Priority:** Must / Should / Could
  - **Source:** <fr 1 source>
  - **Acceptance criteria:** AC-001, AC-002

## 6. BDD Scenarios and Acceptance Criteria

Acceptance criteria must be verifiable through public user, API, CLI, or system interfaces. Avoid private implementation details unless they are explicit product requirements.

### US-001: <user story 1 title>

**Requirement coverage:** FR-001

**Scenario:** <user story 1 scenario>

- **Given** <user story 1 given>
- **When** <user story 1 when>
- **Then** <user story 1 then>

**Acceptance criteria**

- **AC-001:** <acceptance 1>
- **AC-002:** <acceptance 2>

## 7. Nonfunctional Requirements

- **NFR-001 Security:** <security requirement>
- **NFR-002 Privacy:** <privacy requirement>
- **NFR-003 Performance:** <performance requirement>
- **NFR-004 Reliability:** <reliability requirement>
- **NFR-005 Accessibility:** <accessibility requirement>
- **NFR-006 Observability:** <observability requirement>

## 8. Technical and Operational Constraints

Constraints are confirmed boundaries the implementation must respect. Do not use this section for speculative task design.

- **C-001 Supported interfaces:** <supported interfaces>
- **C-002 Compatibility:** <compatibility constraints>
- **C-003 Dependency policy:** <dependency policy>
- **C-004 Deployment or rollout:** <rollout constraints>
- **C-005 Data or migration:** <data constraints>

## 9. AI Behavior and Evaluation

Use this section only when the feature includes AI or model-mediated behavior. For non-AI work, write "Not applicable" and rely on the nonfunctional requirements above.

- **AI-001 Intended model behavior:** <ai behavior>
- **AI-002 Evaluation dataset or rubric:** <ai eval rubric>
- **AI-003 Quality threshold:** <ai quality threshold>
- **AI-004 Safety constraints:** <ai safety constraints>

## 10. Success Metrics

Do not invent baselines. If the baseline is unknown, mark it as unknown and add an open question.

- **M-001:** <metric 1>
  - **Baseline:** <metric 1 baseline>
  - **Target:** <metric 1 target>
  - **Measurement source:** <metric 1 source>

## 11. Assumptions

- **A-001:** <assumption 1>
  - **Source:** <assumption 1 source>

## 12. Open Questions and HITL Decisions

Open questions block planning or execution when a reasonable assumption would create product, security, operational, or user-visible risk.

- **Q-001:** <open question 1>
  - **Blocks:** FR-001 / US-001 / NFR-001 / None
  - **Needed from:** Product / Design / Engineering / Security / Legal / Operations

## 13. Risks

- **R-001:** <risk 1>
  - **Impact:** Low / Medium / High
  - **Mitigation:** <risk 1 mitigation>

## 14. Planning Handoff

Use this approved PRD as input to `project-planner`.

- Preserve opportunity, decision, requirement, story, acceptance-criteria, constraint, assumption, open-question, and risk IDs.
- Convert requirements into outcome-oriented epics and vertical-slice tasks in `docs/project-plan.md`.
- Mark tasks blocked by unresolved questions as `HITL` or `Execution-ready: No`.
- Do not create Beads items directly from this PRD; use `project-planner` first, then `plan-to-beads-unified`.
