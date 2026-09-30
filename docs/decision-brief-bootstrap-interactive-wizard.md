---
workflow_artifact: decision_brief
artifact_version: 1
status: approved
---
# Guided setup decision

Replace the earlier no-write wizard stub with the full approved setup workflow. On a TTY, an invocation without a target enters the wizard; explicit --interactive is available. CI/non-TTY is deterministic and never launches.

The wizard reports prerequisites/global missing/current/differing assets, asks about backed-up global updates, chooses a target defaulting to PWD, identifies retrofit/new project, suggests an initials-based prefix only for new Beads, selects packs (with unverified acknowledgment), selects footer/notifications/hooks/docs MCP and optional promotion, previews all changes, then confirms once. Launch is a separate post-success offer.

Declining writes nothing. Global updates and personal promotion are explicit choices, not inferred consent. Unknown shells use manual PATH instructions; Bash/Zsh/Fish opt-in PATH blocks are idempotent. Command collisions and full project/global preflight happen before managed writes.
