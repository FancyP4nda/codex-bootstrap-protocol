---
name: grill-with-docs
description: Grilling session that challenges an Opportunity Brief, plan, or design against the existing domain model, sharpens terminology, and produces a Decision Brief for product-architect. Updates docs/CONTEXT.md and docs/adr/ inline when decisions crystallize.
protocol_version: 1.0
origin: SCAR Labs
cognitive_tier: Structural
---

# Grill With Docs

## Purpose

Interview the user about a plan, Opportunity Brief, or design until product, domain, architecture, security, privacy, data, and rollout decisions are clear enough for `product-architect`.

Ask one question at a time and wait for feedback before continuing. For each question, provide your recommended answer. If a question can be answered by exploring the codebase, inspect the codebase instead.

Do not create PRDs, project plans, Beads items, or execution tasks. End substantial sessions with a Decision Brief.

## Workflow Artifact Contract

Accept `opportunity_brief`, raw plans, or design notes as input. If the input contains `OPP-*` IDs from `brainstormer`, preserve them. If no opportunity ID exists, do not invent one unless the user explicitly asks to refine brainstormer output.

If the input has workflow frontmatter, verify that the frontmatter and body agree before proceeding. If they disagree, ask the user to resolve the mismatch or state a low-risk correction before continuing.

Canonical templates:

```text
.agents/templates/artifacts/decision-brief.md
.agents/templates/artifacts/adr.md
```

Decision Brief frontmatter:

```yaml
---
workflow_artifact: decision_brief
artifact_version: 1
source_mode: new_idea | existing_project
status: draft | approved | blocked
upstream_ids: [OPP-001]
recommended_next_skill: product-architect | grill-with-docs
canonical_next_artifact: prd | decision_brief
---
```

Use `status: approved` only when decisions needed for PRD drafting are settled or clearly marked as non-blocking. Use `status: blocked` when unresolved HITL decisions would make a PRD misleading.

## Canonical Repo Paths

- Glossary: `docs/CONTEXT.md`
- ADR directory: `docs/adr/`
- Decision Brief template: `.agents/templates/artifacts/decision-brief.md`
- ADR template: `.agents/templates/artifacts/adr.md`

Create files lazily. If `docs/CONTEXT.md` does not exist, create it only when the first term is resolved. If `docs/adr/` does not exist, create it only when the first ADR is needed.

## Domain Awareness

During codebase exploration, look for:

- `docs/CONTEXT.md` for canonical project language.
- `docs/adr/` for durable decisions.
- Existing product docs, architecture docs, source code, tests, and configuration that confirm or contradict the user's description.

If a project has multiple domain contexts, use `docs/CONTEXT.md` as the top-level glossary and add clear subheadings for context-specific language unless the user has already established another structure.

## During The Session

### Challenge Against The Glossary

When the user uses a term that conflicts with `docs/CONTEXT.md`, call it out immediately and ask which meaning is intended.

### Sharpen Fuzzy Language

When the user uses vague or overloaded terms, propose a precise canonical term and ask whether it should be adopted.

### Discuss Concrete Scenarios

Use specific scenarios and edge cases to test boundaries between concepts, roles, states, and workflows.

### Cross-Reference With Code

When the user states how something works, check whether the code and docs agree. If they contradict the statement, surface the contradiction and ask which source should win.

### Update `docs/CONTEXT.md` Inline

When a term is resolved, update `docs/CONTEXT.md` immediately. Do not batch glossary updates.

Use this format:

```md
# Context

One or two sentences describing the domain context.

## Language

**Canonical Term:**
One or two sentences defining what the term is.
_Avoid_: Ambiguous synonym, deprecated synonym
```

Keep `docs/CONTEXT.md` devoid of implementation details. It is a glossary, not a spec, scratch pad, or decision log.

### Offer ADRs Sparingly

Only offer or create an ADR when all three are true:

1. The decision is hard to reverse.
2. The decision would be surprising without context.
3. The decision involved a real trade-off.

ADRs live under `docs/adr/` and use sequential numbering such as `0001-short-title.md`. Use `.agents/templates/artifacts/adr.md`.

## Output: Decision Brief

End every substantial grilling session with a Decision Brief that can feed `product-architect`. Use `.agents/templates/artifacts/decision-brief.md` and preserve every section so `product-architect` can consume the brief without replaying the interview.

The Decision Brief is not a PRD, task list, or implementation plan. It is the decision record that lets `product-architect` draft product truth.
