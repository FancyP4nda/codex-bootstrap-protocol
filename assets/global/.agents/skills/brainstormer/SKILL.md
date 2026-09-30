---
name: brainstormer
description: Generate and prioritize ideas or opportunities (new product ideas, AI/automation use cases, improvements to an existing project) and turn the chosen ones into Opportunity Briefs for grill-with-docs or product-architect. Use at the start of the pipeline, before a PRD exists. Not for PRDs, plans, or tasks.
---

# Brainstormer

Turn a raw idea space into a few well-evidenced Opportunity Briefs that the next skill can pick up without reconstructing intent. This is the first stage of the pipeline:

```text
brainstormer -> Opportunity Brief -> grill-with-docs -> Decision Brief -> product-architect -> PRD
```

Don't create PRDs, plans, beads or tasks here; `product-architect` and `project-planner` own those.

## Output contract

Write each selected opportunity to its own file, `docs/opportunity-brief-<slug>.md`, from the template `.agents/templates/artifacts/opportunity-brief.md` (the project's `.agents/templates/artifacts/opportunity-brief.md` if it has one, otherwise this skill's `templates/opportunity-brief.md`) (it carries the routing frontmatter: `workflow_artifact: opportunity_brief`, `source_mode`, `status`, `upstream_ids`, `recommended_next_skill`). Keep every template section. Mark unknowns as unknown rather than inventing evidence. Downstream skills find briefs at this path, so always state the paths you wrote in the final synthesis.

## Process

1. **Intake.** Decide whether this is a new idea or an existing project. For a new idea, work from the user's goals, audience, constraints and success signals. For an existing project, read just enough of the repo and `docs/` to avoid proposing things that conflict with the architecture, product direction or domain language.
2. **Diverge.** Generate ideas at a volume that fits the scope: dozens for an open-ended space, a handful for a narrow improvement. Mix practical, adjacent and contrarian directions. Give candidates stable IDs (`OPP-001`, …).
3. **Cluster.** Group ideas into themes, and note cross-theme connections worth combining.
4. **Evaluate.** Score candidates on impact, feasibility, risk, confidence, time-to-value and evidence strength, and flag privacy, bias or security concerns in sensitive domains. Present a compact scoring table and recommend the few worth pursuing.
5. **Select.** Ask the user which opportunities to carry forward (request_user_input_async (or a concise question), multi-select, with your recommendation first). If they asked for immediate output, take your top 1–3 and say so.
6. **Refine.** Write an Opportunity Brief file for each selected opportunity (see the output contract).
7. **Synthesize.** Summarize the themes, the briefs written (with paths), the recommended first MVP, and the next skill for each brief. Prefer `grill-with-docs` for existing-project work or anything with terminology, architecture, security, privacy, data or rollout implications; otherwise `product-architect` can take the brief directly.
