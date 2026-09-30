# Migration guide

The current source is sibling `claude-bootstrap-protocol` at commit `f89f7f3dffb1150fa7df30b180b397dd25a711f9`, not the older bootstrap-protocol checkout. Source Git history, Beads, credentials, caches and planning history are excluded. Existing Codex repository history and useful native additions remain.

Core skills move to `~/.agents/skills`, source rules become referenced Markdown instructions, agents become standalone TOML, docs become `docs/`, templates become `.agents/templates/`, and runtime output becomes ignored `.codex/state/tmp/`. Commands use `$skill-name`. Native execution-policy rules are not confused with prose standards.

1. Commit or back up your target's current configuration.
2. Run `codex-bootstrap <target> --dry-run`; supply a prefix if no Beads exists.
3. Review differences and any duplicate local/global skills. Bootstrap never automatically removes an old target's Claude runtime.
4. Choose global default or `--local-core`, optional packs and personal settings.
5. Apply; inspect `.codex/bootstrap.json` and backup paths. Trust the project and review opt-in hooks in `/hooks`.
6. Start `codex -C <target> '$session-start'`. Existing docs stay authoritative; adapt their contents explicitly.

Repeating setup is safe. Use `--update-global` for backed-up global changes; `--force` applies only to managed base/core payload conflicts. Pack conflicts require explicit reconciliation. Unchanged obsolete globals can retire on update; modified files remain.

The kit's previous active CLAUDE.md and outdated planning documents are archived in `.archive/pre-migration-*`, not discarded. Old review logs and durable changelog/handoff history remain. Source checksums and per-asset acceptance categories are recorded in source-inventory.json; canonical native assets are under assets/.

Web-design has absent evidence and cannot pass the release gate. Its explicit install flag is an operator acknowledgment only. Migrated bytes and component digests differ from upstream and are never substituted for scan evidence.
