# Artifact Templates

Templates for the planning artifacts the workflow skills write. Edit them to change the shape of this project's briefs, PRD and plans; the skills fall back to their own bundled copies when a file here is missing.

These files are references for skills and operators. The installer ships short
placeholders in `docs/` (e.g. `prd.md`, `decision-brief.md`) to mark where real
artifacts go; the owning skills write the real artifacts from these templates when that
workflow stage runs, replacing the placeholders.

| Artifact | Template | Owner |
|---|---|---|
| Opportunity Brief | `opportunity-brief.md` | `brainstormer` |
| Decision Brief | `decision-brief.md` | `grill-with-docs` |
| ADR | `adr.md` | `grill-with-docs` |
| PRD | `prd.md` | `product-architect` |
| Project Plan | `project-plan.md` | `project-planner` |
