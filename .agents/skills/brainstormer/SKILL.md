---
name: brainstormer
description: Use when the user needs to brainstorm AI use cases, identify opportunities, or refine ideas into Opportunity Briefs that can feed grill-with-docs or product-architect.
protocol_version: 1.0
origin: SCAR Labs
cognitive_tier: Foundational
---

# Brainstormer

## Purpose

Facilitate AI use-case discovery and turn raw ideas into traceable Opportunity Briefs. This skill starts the Bootstrap Protocol planning chain:

```text
New idea:
brainstormer -> Opportunity Brief -> grill-with-docs -> Decision Brief -> product-architect

Existing project:
brainstormer existing-project mode -> Opportunity Brief -> grill-with-docs -> Decision Brief -> product-architect
```

Do not create PRDs, project plans, Beads items, execution tasks, or implementation plans. Identify and sharpen opportunities with enough context that the next skill does not need to reconstruct intent.

## Workflow Artifact Contract

Opportunity Briefs are routing artifacts. Put YAML frontmatter before every downstream-ready brief so later skills can identify the artifact without parsing prose.

Canonical template:

```text
.agents/templates/artifacts/opportunity-brief.md
```

Required frontmatter:

```yaml
---
workflow_artifact: opportunity_brief
artifact_version: 1
source_mode: new_idea | existing_project
status: draft
upstream_ids: [OPP-001]
recommended_next_skill: grill-with-docs | product-architect
canonical_next_artifact: decision_brief | prd
---
```

The frontmatter is for routing and provenance only. The Markdown body remains the source of human-readable context. If the body and frontmatter disagree, fix the artifact before handing it to another skill.

## Use When

- Brainstorming AI ideas or generating use cases for specific roles, teams, or industries.
- Finding and expanding rough ideas into practical concepts.
- Categorizing, synthesizing, or prioritizing brainstorming results.
- Turning creative ideas into structured Opportunity Briefs.
- Exploring automation, agentic workflows, AI-enabled productivity improvements, or agent workflows.
- Running an innovation workshop or identifying AI quick wins.

## Process

1. **Intake:** Determine whether this is a new idea or an existing project.
   - **New idea:** Explore the opportunity space from the user's goals, constraints, audience, and success signals. Do not assume repository context exists.
   - **Existing project:** Inspect only enough repository/product context to avoid proposals that conflict with current architecture, constraints, product direction, or established domain language.
2. **Divergent ideation:** Generate a high volume of ideas using techniques like SCAMPER, analogy prompts, and future-back thinking. Assign stable opportunity IDs (`OPP-001`, `OPP-002`, etc.) as ideas become candidates.
3. **Thematic clustering:** Identify patterns, goals, users, and project fit. Organize results into a Thematic Map with broad themes, subthemes, and cross-theme connections.
4. **Evaluation:** Score opportunities on impact, feasibility, risk, confidence, time-to-value, and evidence strength. Categorize opportunities into Quick Wins, Strategic Bets, Differentiators, and items needing validation.
5. **Refinement:** Develop Opportunity Briefs for selected top ideas. Each brief must specify problem, target user, desired outcome, evidence/source, assumptions, risks, success signals, MVP boundary, non-goals, and recommended next skill.
6. **Recommendations:** Provide a final synthesis of key themes, top opportunities, recommended first MVP, and downstream handoff path. Prefer `grill-with-docs` for existing-project work or any opportunity with terminology, architecture, security, privacy, data, or rollout implications.

## Principles

- **Quantity before quality:** Explore broadly before narrowing.
- **Mixed directions:** Combine practical, conventional, and contrarian ideas.
- **Efficiency:** Proceed with stated assumptions if context is incomplete and the user wants immediate output.
- **Safety and ethics:** Evaluate privacy, bias, and security risks, especially in regulated or high-impact domains.
- **Traceability:** Preserve `OPP-*` IDs in every downstream-ready brief.
- **Separation of concerns:** Do not make implementation tasks. Product planning happens in `product-architect` and `project-planner`.

## Output Format

### Idea Burst

- **Thematic Categories:** Grouped ideas by theme.
- **Wild Cards:** Unusual or future-state ideas.
- **Standout Directions:** Most promising patterns.
- **Next Move:** One clear action.

### Thematic Map

- **Theme Name and Description:** Core logic of the group.
- **High-Potential Ideas:** Key ideas within the theme and why they matter.
- **Cross-Theme Connections:** Relationships between themes.

### Prioritized Opportunities

- **Scoring Table:** Opportunity ID, impact, feasibility, risk, confidence, time-to-value, evidence strength, and priority.
- **Top 5 Recommendations:** Problem solved, first experiment, and risks for each.

### Opportunity Brief

Use `.agents/templates/artifacts/opportunity-brief.md` for each selected opportunity. Preserve every section in the template unless it is explicitly not applicable; do not replace missing information with invented facts.

### Final Synthesis

Summarize top opportunities, quick wins, recommended first MVP, and downstream handoff path.
