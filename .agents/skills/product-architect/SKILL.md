---
name: product-architect
description: Generates machine-interpretable Product Requirements Documents (PRDs) and repo-grounded specifications. Synthesizes raw user interview transcripts, defines technical constraints, and writes local planning artifacts optimized for agentic execution.
protocol_version: 1.0
origin: SCAR Labs
cognitive_tier: Structural
---

# Product Architect

## Purpose

Transform ambiguous stakeholder intent, meeting transcripts, Opportunity Briefs, Decision Briefs, and raw feature requests into structured Product Requirements Documents optimized for downstream AI planning.

The PRD is product truth, not an implementation plan. It defines outcomes, scope, requirements, observable acceptance criteria, constraints, risks, assumptions, open decisions, and downstream handoff notes.

```text
Opportunity Brief / Decision Brief / raw request
  -> product-architect
  -> docs/prd.md
  -> project-planner
  -> docs/project-plan.md
  -> plan-to-beads-unified
```

## Workflow Artifact Contract

Accept `opportunity_brief` and `decision_brief` artifacts when present. Before drafting, verify that routing frontmatter and Markdown body agree on source mode, upstream IDs, status, and recommended next skill. If they disagree, surface the mismatch before treating the artifact as product truth.

Emit PRDs with this routing frontmatter:

```yaml
---
workflow_artifact: prd
artifact_version: 1
source_mode: new_idea | existing_project
status: draft | approved | blocked
upstream_ids: [OPP-001]
recommended_next_skill: project-planner
canonical_next_artifact: project_plan
---
```

The frontmatter is for routing and provenance only. The Markdown body remains the canonical product specification.

## Canonical Repo Paths

- PRD output: `docs/prd.md`
- PRD template: `.agents/templates/artifacts/prd.md.hbs`
- Downstream plan output: `docs/project-plan.md`
- Project glossary: `docs/CONTEXT.md`
- ADRs: `docs/adr/`

## Use When

- Drafting new feature specifications or PRDs.
- Turning `brainstormer` Opportunity Briefs into canonical PRDs.
- Turning `grill-with-docs` Decision Briefs into canonical PRDs.
- Turning client requests or rough product ideas into structured local PRDs.
- Synthesizing customer feedback into actionable, atomic user stories.
- Translating abstract ideas into strict, machine-verifiable acceptance criteria and constraints.

## Resource Discovery And Grounding

Before drafting a PRD, read only the resources needed for the user's input shape. Ground product claims in the user's brief, provided artifacts, and focused repository exploration.

Always read `.agents/templates/artifacts/prd.md.hbs` before drafting PRDs. For BDD stories, use this syntax:

```text
Given <precondition>
When <actor action or event>
Then <observable outcome>
```

For `source_mode: existing_project`, repository grounding is mandatory before PRD creation. Cite the files, docs, commands, or code paths used for grounding.

## Process

1. **Context aggregation:** Analyze inputs, identify missing details, and inspect the repository only as needed to understand behavior, architecture constraints, integration boundaries, and verification conventions.
2. **Structural planning:** Load `.agents/templates/artifacts/prd.md.hbs`. Decide which requirements are confirmed, assumed, blocked by open questions, or out of scope. Preserve upstream `OPP-*` IDs and Decision Brief decisions in traceability fields.
3. **Specification architecting:** Draft the PRD with stable IDs for goals, requirements, user stories, nonfunctional requirements, assumptions, open questions, risks, and acceptance criteria. Acceptance criteria must describe observable behavior through public interfaces.
4. **Review gate:** Present the draft PRD or material changes for user review before replacing an existing canonical `docs/prd.md`. Call out assumptions, open questions, and requirements blocked by missing decisions.
5. **Artifact generation:** After approval, write the PRD to `docs/prd.md` unless the user specifies a different path.

## Strict Constraints

- Do not invent metrics. Flag missing baseline data as a dependency.
- Do not output monolithic user stories; keep requirements atomic and testable.
- Do not create execution phases, epics, tickets, Beads items, or task sequences in the PRD.
- Do not couple acceptance criteria to private methods, internal data structures, or database state unless that state is directly exposed or explicitly required.
- Do not include raw API keys, secrets, or PII.
- Do not submit to external services unless explicitly requested.
- Do not include brittle code snippets or file paths unless required by the product behavior.
- Never skip repository grounding for codebase-dependent PRDs.
- Never overwrite an existing canonical `docs/prd.md` without surfacing material changes and getting user approval.
- Never drop upstream `OPP-*` IDs, resolved decisions, or unresolved HITL questions when present.

## Output Format

Return a summary of synthesized requirements, upstream traceability preserved, assumptions, risks, open questions, blocked decisions, and the path to the generated PRD artifact. End with the recommended downstream step: run `project-planner` against the approved PRD.
