# Source Inventory

This file records the T001 source boundary for the Codex-native scaffold shell.

## Migration Input

- `../bootstrap-protocol/init-project.sh`
- `../bootstrap-protocol/Starting-workflow.md`
- `../bootstrap-protocol/.claude/CLAUDE.md`
- `../bootstrap-protocol/.claude/skills/`
- `../bootstrap-protocol/.claude/templates/`
- `../bootstrap-protocol/.claude/rules/`
- `../bootstrap-protocol/.claude/agents/`
- `../bootstrap-protocol/.claude/docs/`

These paths are migration inputs only. Later beads transform the useful concepts into Codex-native assets.

## Copied Into This Repo During T001

- Root planning docs already present under `docs/`
- Beads state under `.beads/`
- Builder instructions in `AGENTS.md`
- Builder README in `README.md`
- Placeholder repo-root `bootstrap`
- Empty structural directories: `.agents/`, `.codex/`, `.archive/`, and `verification/`

## Explicitly Excluded From Active Runtime Surface

- Source-kit `.claude/` runtime directory
- Claude slash-command files such as `commands/leroy.md` and `commands/wrapup.md`
- Claude background-session Falcon mechanics
- Source-kit `.beads/` database state
- Source-kit `.git/` data

Claude files may be referenced in migration notes and review logs, but installed Codex target assets must use `.agents/`, `.codex/`, `docs/`, `.archive/`, and `.beads/`.
