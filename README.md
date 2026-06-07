# Codex Bootstrap Protocol

Codex Bootstrap Protocol is a local-first scaffold repo for creating Codex-native project workspaces from the legacy Bootstrap Protocol source kit. It is Codex-native only: installed target projects should use `AGENTS.md`, `.agents/skills/`, `.codex/`, durable `docs/`, and Beads (`bd`) instead of active Claude runtime directories.

The repo-root `bootstrap` command is the primary operator entry point. Early implementation beads build out its argument parsing, dry-run planning, conflict handling, managed scaffold paths, and Beads initialization.

## Current State

- Planning source of truth: `docs/codex-bootstrap-protocol-PRD.md`
- Execution plan: `docs/codex-bootstrap-protocol-project-plan.md`
- Work tracker: Beads via `bd`
- Migration input: sibling `../bootstrap-protocol`

This repo is Codex-native. Claude runtime files from the source kit are migration references only and must not be installed into target projects as active runtime surfaces.

## Requirements

- Ubuntu or WSL shell with Bash.
- Codex installed and launched from the target repo when using repo-scoped skills.
- Beads (`bd`) preinstalled for real installs.
- No automatic package installs, network calls, Git remote changes, cloud calls, or PATH changes are performed by this scaffold.

Dry-run mode is allowed to run without `bd` because it only previews planned file operations. A real install must fail before writing target files when `bd` is missing.

## Primary Usage

From this repo checkout:

```bash
./bootstrap <target-project-path> --prefix <PREFIX>
```

Example:

```bash
./bootstrap /tmp/codex-bootstrap-smoke --prefix CBS
```

The `<PREFIX>` is the project-specific Beads prefix used when initializing work tracking in the target project. Use a short uppercase identifier that is meaningful for the target project.

## Dry Run

Preview an install without writing scaffold files:

```bash
./bootstrap --dry-run <target-project-path> --prefix <PREFIX>
```

Dry-run output should show planned created paths, skipped paths, and conflicts. It must not create scaffold files and must not require `bd`.

## Force Behavior

By default, `bootstrap` should stop before writes when a target already has managed scaffold-path conflicts. The conflict report should name the path, planned action, reason, and suggested resolution.

Use `--force` only when you have reviewed the conflict report and intend to overwrite managed scaffold files:

```bash
./bootstrap <target-project-path> --prefix <PREFIX> --force
```

`--force` is limited to managed scaffold files. It must never overwrite `.git/`, `.beads/`, credentials, ignored transient state, or paths outside the managed scaffold contract.

## Optional PATH Setup

The supported default is to run `./bootstrap` from this checkout. If you want a shorter command, create your own symlink or PATH entry after reviewing the path you want to expose.

Example symlink:

```bash
mkdir -p "$HOME/.local/bin"
ln -s "$(pwd)/bootstrap" "$HOME/.local/bin/codex-bootstrap"
codex-bootstrap --help
```

Example PATH entry for Bash:

```bash
printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
```

These commands are examples only. The scaffold does not run them, edit shell startup files, or install commands globally.

## Opt-In Configuration

Optional hooks, rules, custom subagents, `minion` settings, stricter approval/sandbox profiles, memory examples, and automation examples are documented in `docs/opt-in-configs.md`.

Those controls are opt-in because they can change how Codex approves commands, delegates work, or enforces local project rules. Review the purpose, risk level, enable steps, disable steps, and verify command before enabling any optional config.

## Verification

Run the T010 static verification suite from the repo root:

```bash
./verification/run-static-checks.sh
```

The suite checks shell syntax, live `.claude/*` runtime references, hardcoded `/home/echo/ACC` runtime dependencies, and documented allowlists for migration/source references. See `verification/README.md` for the disposable `/tmp` dry-run check and the T012-deferred install/readback, conflict, protected-path, and missing-`bd` behavior commands.

## Relocation Safety

The repo may be developed at an example path such as `/home/echo/ACC/codex-bootstrap-protocol`, but runtime logic and installed targets should not depend on `/home/echo/ACC`. Scripts should resolve paths relative to the script or repo root so the checkout can move later, for example to `/home/echo/dev/codex-bootstrap-protocol`.

References to `/home/echo/ACC` in documentation are examples or migration notes, not runtime dependencies.

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
