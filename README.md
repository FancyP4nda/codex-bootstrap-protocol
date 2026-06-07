# Codex Bootstrap Protocol

Codex Bootstrap Protocol is a local-first scaffold repo for creating Codex-native project workspaces from the legacy Bootstrap Protocol source kit. It is Codex-native only: installed target projects should use `AGENTS.md`, `.agents/skills/`, `.codex/`, durable `docs/`, and Beads (`bd`) instead of active Claude runtime directories.

The repo-root `bootstrap` command is the primary operator entry point. It reads `assets/scaffold/manifest.txt`, reports the managed asset tree in dry-run mode, copies the managed scaffold files during real installs, and initializes Beads when prerequisites are met.

## Current State

- Planning source of truth: `docs/codex-bootstrap-protocol-PRD.md`
- Execution plan: `docs/codex-bootstrap-protocol-project-plan.md`
- Install contract: `assets/scaffold/manifest.txt`
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

A successful real install creates the target directory when needed, copies every managed path from `assets/scaffold/manifest.txt`, initializes `.beads/`, and prints a summary pointing to target `AGENTS.md`, target `docs/opt-in-configs.md`, Beads status, and the next workflow skills.

## Bootstrap A New Project

Use this sequence when creating a new Codex-ready project workspace.

1. Start from this scaffold checkout:

   ```bash
   cd /path/to/codex-bootstrap-protocol
   ```

2. Confirm prerequisites:

   ```bash
   command -v bash
   command -v bd
   ./bootstrap --help
   ```

   `bd` is required for real installs because the target project is initialized with Beads. Dry-run mode does not require `bd`.

3. Pick the target directory and prefix. The prefix should be short, stable, and meaningful for the target project:

   ```bash
   target=/tmp/my-new-project
   prefix=MNP
   ```

4. Preview the install. This must not write target files:

   ```bash
   ./bootstrap --dry-run "$target" --prefix "$prefix"
   ```

   Review the created, skipped, and conflict sections. If conflicts are reported, inspect them before running a real install.

5. Install the scaffold:

   ```bash
   ./bootstrap "$target" --prefix "$prefix"
   ```

   Use `--force` only after reviewing a conflict report and only when you intend to overwrite managed scaffold files:

   ```bash
   ./bootstrap "$target" --prefix "$prefix" --force
   ```

6. Enter the target project and verify the installed surface:

   ```bash
   cd "$target"
   git status --short --branch
   bd ready
   test -f AGENTS.md
   test -f docs/CONTEXT.md
   test -d .agents/skills
   test -d .codex/agents
   ```

7. Start Codex from the target project directory so repo-scoped instructions, skills, custom agents, and docs are discoverable.

## Expected Target Workflow

After bootstrapping, the target project should use this planning-to-execution flow:

1. **Orient:** Run `$session-start` or manually read `AGENTS.md`, `docs/CONTEXT.md`, `docs/handoff.yaml`, `docs/changelog.yaml`, and Beads state.
2. **Shape the idea:** Use `$brainstormer` for an Opportunity Brief when the idea is still broad.
3. **Resolve decisions:** Use `$grill-with-docs` to turn an opportunity or rough plan into a Decision Brief grounded in existing docs.
4. **Write product truth:** Use `$product-architect` to create or update `docs/prd.md`.
5. **Plan execution:** Use `$project-planner` to create or update `docs/project-plan.md` from an approved PRD.
6. **Create Beads work:** Use `$plan-to-beads-unified` to turn the approved project plan into Beads issues.
7. **Implement one Bead at a time:** Use `bd ready`, `bd show <id>`, and `bd update <id> --claim`; keep work inside the Bead collision domain and run the Bead verification command.
8. **Use report-only fanout when useful:** Use `$minion` for parallel review, research, or planning reports. In v1 it is report-only and does not run write-heavy implementation fanout.
9. **Close out:** Use `$session-wrapup` to verify work, close completed Beads, update `docs/handoff.yaml` and `docs/changelog.yaml`, and create a local handoff.
10. **Sync through Git:** Commit code, docs, and tracked Beads exports, then use normal `git push`. This repo does not require `bd dolt push/pull`.

Durable project knowledge should live in `docs/`; task state should live in Beads; transient Codex scratch output should stay under `.codex/state/tmp/`.

## Dry Run

Preview an install without writing scaffold files:

```bash
./bootstrap --dry-run <target-project-path> --prefix <PREFIX>
```

Dry-run output should show planned created paths, skipped paths, and conflicts. It must not create scaffold files and must not require `bd`.

The dry-run summary uses the same managed-path names as a real install and ends with a note that no target files were written.

## Managed Target Tree

The manifest-driven install creates this Codex-native target surface:

```text
.
|-- AGENTS.md
|-- docs/
|   |-- CONTEXT.md
|   |-- opt-in-configs.md
|   |-- adr/
|   |-- prd.md
|   |-- project-plan.md
|   |-- architecture.md
|   |-- backend.md
|   |-- frontend.md
|   |-- data-model.md
|   |-- security.md
|   |-- handoff.yaml
|   |-- changelog.yaml
|   |-- enhancements.md
|   `-- standards-history.md
|-- .agents/
|   |-- skills/
|   `-- templates/
|-- .codex/
|   |-- agents/
|   |-- hooks/
|   |-- rules/
|   |-- state/tmp/
|   `-- config.toml
|-- .archive/
|-- .beads/
`-- .gitignore
```

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

For installer smoke checks, use clearly test-created `/tmp` targets:

```bash
./bootstrap --dry-run /tmp/codex-bootstrap-smoke --prefix CBS
./bootstrap /tmp/codex-bootstrap-smoke-real --prefix CBS
```

The suite checks shell syntax, live `.claude/*` runtime references, hardcoded `/home/echo/ACC` runtime dependencies, and documented allowlists for migration/source references. See `verification/README.md` for additional install/readback, conflict, protected-path, and missing-`bd` behavior commands.

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
