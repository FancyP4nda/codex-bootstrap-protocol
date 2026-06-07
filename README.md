# Codex Bootstrap Protocol

Codex Bootstrap Protocol is a local-first scaffold repo for creating Codex-native project workspaces from the legacy Bootstrap Protocol source kit.

The first phase keeps this repo as the builder. Target-project install assets will live under `assets/scaffold/` once the asset-tree bead is implemented. The repo-root `bootstrap` command is the public entry point; early beads fill in its argument parsing, dry-run planning, conflict handling, and Beads initialization.

## Current State

- Planning source of truth: `docs/codex-bootstrap-protocol-PRD.md`
- Execution plan: `docs/codex-bootstrap-protocol-project-plan.md`
- Work tracker: Beads via `bd`
- Migration input: sibling `../bootstrap-protocol`

This repo is Codex-native. Claude runtime files from the source kit are migration references only and must not be installed into target projects as active runtime surfaces.

## Expected Builder Layout

```text
.
|-- AGENTS.md
|-- README.md
|-- bootstrap
|-- docs/
|-- .agents/
|-- .codex/
|-- .archive/
|-- verification/
`-- .beads/
```

## Development Flow

1. Use `bd ready` to find unblocked work.
2. Claim one bead with `bd update <id> --claim`.
3. Keep each bead inside its documented collision domain.
4. Run the bead-specific verification command before closeout.
5. Close the bead with evidence in the close reason, then export/push Beads state.

## Source Boundary

T001 establishes the repo shell only. It does not copy active source-kit runtime machinery into the installed target surface. The source-copy decisions and exclusions are documented in `.archive/source-inventory.md`.
