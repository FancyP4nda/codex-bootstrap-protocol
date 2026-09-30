---
name: product-architect
description: Write or revise the canonical PRD (docs/prd.md) from an Opportunity Brief, Decision Brief, transcript or raw request, grounded in the repo for existing projects. Produces requirements and acceptance criteria, not plans or tasks (use project-planner for those).
---

# Product Architect

Turn briefs, transcripts and rough requests into the project's single product-truth document, `docs/prd.md`. The PRD defines outcomes, scope, requirements, observable acceptance criteria, constraints, risks, assumptions and open decisions. Breaking it into work is downstream:

```text
Opportunity/Decision Brief or raw request -> product-architect -> docs/prd.md -> project-planner -> plan-to-beads-unified
```

## Inputs

- **Briefs:** `docs/opportunity-brief-*.md` (from `brainstormer`) and `docs/decision-brief*.md` (from `grill-with-docs`). If several exist, use the ones the user names or ask which apply. Ignore the shipped placeholders (no routing frontmatter, only template prompts).
- **Frontmatter check:** if a brief's routing frontmatter disagrees with its body (source mode, upstream IDs, status), surface the mismatch before treating it as product truth.
- **Other inputs:** raw requests, transcripts or notes the user provides. For an existing project, also read the repo.

## Process

1. **Gather context.**
   - Read the inputs and note what's missing.
   - For `existing_project` work, ground the PRD in the repo before drafting: existing behavior, architecture constraints, integration boundaries, and how things are verified. Read only as much as the PRD needs.
2. **Structure.**
   - Work from the template `.agents/templates/artifacts/prd.md` (the project's `.agents/templates/artifacts/prd.md` if it has one, otherwise this skill's `templates/prd.md`), and follow `references/agile_user_story_guidelines.md` for the Given/When/Then scenarios.
   - Sort requirements into confirmed, assumed, blocked by an open question, or out of scope.
   - Carry every upstream `OPP-*` ID and Decision Brief decision into the traceability section.
   - If you're unsure how much detail each section needs, `examples/output_golden_prd.md` is a worked example. It's optional reading; don't copy its content or its counts.
3. **Draft.**
   - Use as many goals, requirements, stories, NFRs, assumptions, questions and risks as the product actually needs, with stable IDs (G-, FR-, US-, AC-, NFR-, Q-, R-).
   - Keep requirements atomic.
   - Acceptance criteria describe behavior observable through public interfaces (UI, API, CLI, events).
4. **Review.**
   - Present the draft, or the material changes to an existing PRD, and call out the assumptions, open questions and anything blocked.
   - The shipped placeholder `prd.md` isn't a real PRD, so replacing it needs no confirmation beyond this review.
5. **Write** `docs/prd.md` (or the path the user names).
   - Set `status: approved` only once the user approves.
   - Otherwise leave it `draft`, or `blocked` when open HITL decisions would make it misleading. project-planner only plans from an approved PRD.

## Constraints

- **Don't invent metrics or baselines.** Mark them unknown and list them as open questions. The planner and everything after it treat PRD numbers as truth.
- **Stay at product level:** no phases, epics, tickets, beads or task ordering (project-planner owns those).
  - Acceptance criteria shouldn't assert private methods, internal structures or database state unless that state is itself exposed or required.
  - Leave code snippets and file paths out unless the product requirement depends on them.
- **For existing projects, cite what you grounded on** (files, docs, commands), so reviewers can check it.
- **Carry forward** every upstream `OPP-*` ID, resolved decision and open HITL question present in the inputs.
- **Keep sensitive and external material out:** no secrets or PII in the PRD, and don't push to external trackers (GitHub, Jira) unless asked.

## Output

Summarize:
- the key requirements
- the traceability preserved
- the assumptions, open questions and blocked decisions
- the PRD path and its status

Then give the next step: run `project-planner` once the PRD is approved.
