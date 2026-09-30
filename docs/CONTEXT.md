# Context

Codex Bootstrap Protocol now implements the complete native migration from sibling claude-bootstrap-protocol at f89f7f3dffb1150fa7df30b180b397dd25a711f9. Destination Git history, Beads and native minion work are preserved.

Canonical payloads: assets/global (18 core skills, six agents, standards), assets/scaffold (managed project instructions/docs/templates), assets/packs (Falcon, Herald, explicitly unverified web-design). Global-first is default; local-core is self-contained. Kit-local core copies are checked mirrors.

bootstrap is the relocatable Bash entrypoint; lib/plan-engine.sh preflights all writes and lib/native-config.py prepares parsed targeted changes/hashes. Command setup and full wizard are implemented. Hooks/configuration are opt-in and trust-gated; Claude review is optional/read-only; Codex fallback is isolated.

Read README, docs/migration-contract.md, feature-parity.md, troubleshooting.md and verification.md. Use bd prime for current work. Sync only through normal Git, including bd export -o .beads/issues.jsonl; never require bd dolt push/pull. Historic docs/reviews remain in .archive and the durable YAML history.
