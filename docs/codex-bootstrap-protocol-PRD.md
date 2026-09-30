---
workflow_artifact: prd
artifact_version: 1
source_mode: existing_project
status: approved
---
# Codex Bootstrap Protocol product contract

The approved September 2026 migration supersedes the archived June PRD. Deliver a local installer and command that create/retrofit a native Codex project, install global core by default, offer a complete guided wizard, preserve user configuration/history, and expose all migrated optional workflows.

Users: developers using Bash on Linux/macOS/WSL; automation using deterministic flags. Prerequisites: Python 3.11+, Git, Codex and local Beads; Claude optional; Node22+ for web-design.

Requirements and acceptance are authoritative in [migration contract](migration-contract.md), [parity matrix](feature-parity.md) and [verification](verification.md). Global-first and self-contained local-core are both supported. Native hooks/footer/notifications/MCP are opt-in and never bypass trust. All source reusable assets are inventoried. Falcon has isolated local workers and a stoppable monitor; Herald is native; web-design remains explicitly unverified.

Success: one-time command setup followed by codex-bootstrap can install, discover skills, prepare selected native settings and offer session launch without manual copying. Non-TTY never prompts. Preflight and dry-run preserve destination state. Managed overwrites back up; modified/unmanaged files remain. Source/destination Beads and Git histories are not conflated.

Distribution remains the local installer. Marketplace publication, persistent services, automatic package installation and implicit remote infrastructure are outside this release. Historic PRD/reviews remain archived or in their original review logs.
