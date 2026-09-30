---
workflow_artifact: project_plan
artifact_version: 1
source_mode: existing_project
status: approved
---
# Migration implementation plan

The September migration is tracked by Beads epic codex-bootstrap-protocol-ung and its four children; Beads, not Markdown, owns task status.

The implementation sequence is migration inventory/contract, hardened installer, native core/configuration, optional packs, command/wizard, release verification/documentation. Canonical assets live in assets/global, assets/scaffold and assets/packs; kit-local core mirrors are generated and checked for drift.

Acceptance follows [PRD](codex-bootstrap-protocol-PRD.md), [contract](migration-contract.md), [parity](feature-parity.md) and [verification](verification.md). Tests cover fresh/retrofit/repeat/global/local setup, safety/conflicts/backups, native discovery/config/hook trust, worker recovery and pack gates. Real CLI integration and a disposable authenticated session supplement mocks.

Old June plan and wizard scope are preserved in .archive/pre-migration-project-plan.md and .archive/pre-migration-wizard-brief.md. Their remaining implementation beads are reconciled where this migration delivers the same scope; unrelated historical records are retained. This repo syncs with normal Git, including Beads JSONL export; no Dolt remote sync is required.
