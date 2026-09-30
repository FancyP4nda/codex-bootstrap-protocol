---
name: grill-with-docs
description: Grilling session that challenges an Opportunity Brief, plan, or design against the existing domain model, sharpens terminology, and produces a Decision Brief for product-architect. Updates CONTEXT.md and ADRs inline when decisions crystallise. Also use for a plain "grill me" interview on any plan — the doc steps simply no-op when there are no docs.
---

<what-to-do>

Interview the user to resolve the decisions this plan depends on. Walk the design tree so each answer unblocks the next, and give your recommended answer with every question.

- Ask one question at a time when answers depend on each other. Batch independent, low-stakes choices into a single request_user_input_async (or a concise question).
- If the codebase or docs can answer a question, look it up instead of asking.
- **Stop** when every decision that would change the PRD (or, for a plain "grill me", the plan) is settled or explicitly parked as an open HITL question. Say which decisions were parked, then move to the output.

**Input:** an Opportunity Brief (`docs/opportunity-brief-<slug>.md` from `brainstormer`), a plan, or design notes.

If the input contains `OPP-*` opportunity IDs from `brainstormer`, preserve them in the final Decision Brief. If no opportunity ID exists, do not invent one unless you are explicitly refining brainstormer output.

If the input has workflow frontmatter, verify that the frontmatter and body agree before proceeding. If they disagree, ask the user to resolve the mismatch or state a low-risk correction before continuing.

</what-to-do>

<supporting-info>

## Workflow Artifact Contract

Accept `opportunity_brief`, raw plans, or design notes as input. Emit a `decision_brief` with this routing frontmatter:

Canonical Decision Brief template:

`.agents/templates/artifacts/decision-brief.md` in the project if present, otherwise [`templates/decision-brief.md`](./templates/decision-brief.md) in this skill.

Canonical ADR template:

`.agents/templates/artifacts/adr.md` in the project if present, otherwise [`templates/adr.md`](./templates/adr.md) in this skill.

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

Use `status: approved` only when the product, domain, architecture, security, privacy, data, and rollout decisions needed for PRD drafting are settled or clearly marked as non-blocking. Use `status: blocked` when unresolved HITL decisions would make a PRD misleading.

## Domain awareness

During codebase exploration, also look for existing documentation:

### File structure

Most repos have a single context:

```
/
├── docs/
│   ├── CONTEXT.md
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `CONTEXT-MAP.md` exists at `docs/CONTEXT-MAP.md`, the repo has multiple contexts. The map points to where each one lives:

```
/
├── docs/
│   ├── CONTEXT-MAP.md
│   └── adr/                          ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   └── docs/adr/                 ← context-specific decisions
│   └── billing/
│       ├── CONTEXT.md
│       └── docs/adr/
```

Create files lazily — only when you have something to write. If no `docs/CONTEXT.md` exists, create one when the first term is resolved. If no `docs/adr/` exists, create it when the first ADR is needed.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up — capture them as they happen. Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md). Add or edit entries under its `## Language` heading and leave any preamble above it alone; the shipped `docs/CONTEXT.md` opens with a short directory guide.

`CONTEXT.md` should be totally devoid of implementation details. Do not treat `CONTEXT.md` as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the canonical ADR template at `.agents/templates/artifacts/adr.md`; [ADR-FORMAT.md](./ADR-FORMAT.md) contains the decision criteria and numbering rules.

## Output: Decision Brief

When the session is feeding the pipeline (the input was an Opportunity Brief, or the user is heading for a PRD), end with a Decision Brief for `product-architect`. For a plain "grill me" on an unrelated plan, a summary of the resolved and parked decisions in chat is enough.

Write it from `.agents/templates/artifacts/decision-brief.md` to `docs/decision-brief.md`. If that file already holds a real brief (anything beyond the shipped placeholder), write `docs/decision-brief-<topic>.md` instead, so an earlier brief is never overwritten. Keep every template section so `product-architect` can work from the brief without replaying the interview, and state the path you wrote.

The Decision Brief is not a PRD, task list, or implementation plan. It is the decision record that lets `product-architect` draft product truth without replaying the interview.

</supporting-info>
