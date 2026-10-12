# Codex Bootstrap Protocol

Relocatable Bash setup for native Codex projects. Global workflow skills are the default; projects receive concise instructions, durable documentation and Beads tracking. The authoritative migration source is sibling `claude-bootstrap-protocol` at `f89f7f3`. Existing destination history and Beads records are preserved.

## Quickstart

Prerequisites: Bash, Python 3.11+, Git, Codex CLI and Beads (`bd`) with its supported local backend. The installer supports Linux, macOS and WSL Bash; real CLI integration baseline is Codex 0.159.2. Bootstrap installs no packages and makes no network calls. Native Windows is not a supported Bash installation target: use WSL for this kit.

```bash
./bootstrap --install-command --update-path
# Restart your shell if PATH changed.
codex-bootstrap                         # interactive wizard on a TTY
codex-bootstrap /path/to/project --prefix MY --non-interactive
codex -C /path/to/project '$session-start'
```

Command setup creates owned symlinks in `~/.local/bin`: `codex-bootstrap` and `herdr-qa` (see [herdr QA reviewer](#herdr-qa-reviewer)). PATH editing is explicit and idempotent for Bash, Zsh and Fish. Unknown shells receive manual guidance. Preserve the kit checkout: relocating the checkout together with the home tree keeps the relative link valid; moving only the kit requires repairing the old owned link and reinstalling. `./bootstrap` also works directly.

## Setup choices

```bash
codex-bootstrap /path/to/project --prefix MY --dry-run
codex-bootstrap /path/to/project --prefix MY --local-core
codex-bootstrap /path/to/project --pack falcon --pack herald
codex-bootstrap /path/to/project --pack web-design --allow-unverified-pack
codex-bootstrap /path/to/project --hooks --status-line --notifications --docs-mcp
codex-bootstrap --global-only --update-global
codex-bootstrap --doctor --global-only      # strict global health; no Beads needed
codex-bootstrap --doctor /path/to/project   # auto-detect local-core
codex-bootstrap --uninstall-command --update-path
```

An existing valid Beads database needs no prefix. Fresh setup requires one. Missing global core is installed under `~/.agents/skills` and `${CODEX_HOME:-~/.codex}/agents`; differences are preserved unless you choose `--update-global`. Global-only setup needs no Beads. `--local-core` installs the same core into the project and skips global core. Duplicate local/global skills are reported; Codex may expose both, so verify the loaded skill path rather than assuming name-based precedence.

The wizard checks prerequisites, reports global asset state, chooses target/prefix/packs/settings, shows a combined preview, confirms once, applies and offers launch. CI/non-TTY never prompts or launches. Use `--launch` or `--no-launch` for explicit launch preference; launch still requires a TTY. `--promote-global` explicitly promotes chosen personal settings, with a diff and backup; the default is project configuration.

## Safety and native configuration

Preflight rejects malformed manifests, traversal, protected paths, symlinks and cross-layer collisions before file installation. User-owned Claude files, credentials, Git/Beads data, extra files and existing durable docs are preserved. Managed instruction sections and ignore entries merge; native TOML keys and hook JSON update without replacing unrelated configuration. Unrepresentable TOML layouts fail with guidance.

`--force` backs up base/core conflicts; it never overrides structural protection or pack conflicts. Backups live in affected layers under `bootstrap-backups/<run-id>/`. Hash metadata tracks managed files; an explicit global update retires obsolete files only when unchanged. Modified obsolete files and destination-only extras remain.

Omitting prior UI/hook/MCP flags during a later core update does not uninstall
them or rewrite personal settings. Merged `config.toml` and `hooks.json` are
user configuration, not deletable core payloads. Legacy ownership metadata is
migrated conservatively. Doctor returns nonzero for missing/invalid required
core, but warns about valid customization without overwriting it. Local-core
health uses the project's resources and does not require a global install.

Hooks are advisory and opt-in. Trust the project through Codex, then inspect and approve definitions using `/hooks`; installation never trusts them. Inline TOML hooks and JSON hooks cannot compete in one layer. The footer uses native identifiers, not Claude token accounting. Documentation MCP is opt-in; authentication and secrets remain separate.

## Workflows and packs

The core contains all 17 source skills plus the retained dual-mode `$minion`, six native agents, standards and supporting templates. On clients without a named-role selector, the [native role compatibility helper](docs/native-agents.md) loads the same TOML through supported Codex exec settings. Session skills also work in ordinary Git repos without scaffold docs or Beads. Codex owns adversarial-review revisions; optional Claude critique is read-only, with an isolated read-only Codex fallback.

Falcon uses isolated Codex CLI worktrees and structured reports. Its local monitor is stoppable and never an OS service. Steering owns Beads, integration and PR creation. Herald adds design/prototype/accessibility/review specialists.

Falcon workers implement/test without staging or committing: workspace-write
protects Git metadata. After `dispatch`, steering reviews the current attempt's
fresh schema-valid report and actual scoped diff with `handoff`, then explicitly
uses its report/diff hashes for `commit`. Only then review and integrate the
returned worker-branch commit under the repository's workflow. Old attempts are
history, not evidence for a resumed task. See the installed Falcon COMMANDS.md
for `recover` after an interrupted steering commit.

Falcon and web copy-edit/validation workers require Linux or WSL with working
subreaper and pidfd support. They refuse before launching a worker on unsupported
platforms, including macOS/native Windows; the installer and non-worker workflows
remain separate. A scoped supervisor adopts even detached descendants and
certifies that all writers stopped before scope release, rollback or retry.
Missing shutdown proof preserves ownership and blocks retry; do not delete its
state or kill the supervisor to force progress. Only this Omarchy/Linux host was
tested; WSL is a supported capability path, not an executed platform check.
Web manual Apply uses a durable operation lease: overlapping Apply/rollback/
discard fails with 409 before touching the active transaction. Restart recovery
also waits for shutdown proof. Legacy unowned transactions or unconfirmed
external chat writers are preserved for explicit inspection, not guessed safe.

Core skill resource links resolve from the loaded skill directory, including
clean-home local-core installs. Shared guides do not auto-load or override user
and repository instructions. Checkpoint records authorized resume notes; it
does not imply a commit, push, PR or Dolt remote synchronization.

Web-design preserves pinned Impeccable and Taste components and licenses. It remains **unverified and release-invalid** because upstream review evidence is absent. Explicit opt-in does not certify it. Node.js 22+ is required. Optional browser, detector and image-generation features require their own dependencies/consent; vendor update pings and concept telemetry default off.

## Global packs

A global pack installs once for every project instead of into one project. It goes into the same places as the global core: skills under `~/.agents/skills` (and shared references under `~/.agents/references`), roles under `${CODEX_HOME:-~/.codex}/agents`. Codex CLI 0.162.1 loads skills from `~/.agents/skills` as well as `$CODEX_HOME/skills` and the project's `.agents/skills`.

```bash
codex-bootstrap --global-only --pack <name> --dry-run   # preview
codex-bootstrap --global-only --pack <name>             # install; a rerun reports 0 changes
codex-bootstrap --global-only --pack <name> --update-global   # take the kit's newer files, with backups
codex-bootstrap --remove-global-pack <name> [--dry-run]
```

Each pack keeps its own record of what it installed (`~/.agents/bootstrap/packs/<name>.json`, and `$CODEX_HOME/bootstrap-packs/<name>.json` when it ships roles), separate from the core's. A file you changed after installing is kept and reported, both on a rerun (until you pass `--update-global`, which backs it up under `bootstrap-backups/<run>/` first) and on removal, which deletes only the pack's files that are still as installed, then its record. Updating the core never removes a pack's files. A project pack (falcon, herald, web-design) cannot be installed globally, and a global pack cannot be installed into a project.

**craft** is the kit's global pack: 16 engineering-craft skills (incremental implementation, API and interface design, frontend UI, source-driven and doubt-driven development, debugging, browser testing, code review, simplification, security, performance, CI/CD, observability, shipping, deprecation and migration, constraint-driven development) and the 7 reference checklists they link to, vendored unchanged from [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) at commit `1be8e34` (MIT). It is opt-in because every session then lists its skills. `codex-bootstrap --global-only --pack craft` installs it; the installed `~/.agents/references/craft-pack-notes.md` lists what was left out (upstream's planning, TDD and Git skills, which this kit's own skills cover, and its commands and Claude Code agents) and how to read references to them.

## herdr QA reviewer

Global core also provisions the Codex side of the two-model review gate used by the sibling Claude kit: `${CODEX_HOME:-~/.codex}/qa.config.toml` (the `qa` profile: `gpt-6-astra`, high reasoning effort, read-only sandbox) and the `reviewer` role's QA passes and report shape (`VERDICT:` first line, then `Reviewed commit:`, findings, `Checks run:` and `Checks not performed:`). Codex 0.162 layers a profile file on `config.toml`, which stays untouched; do not also add a `[profiles.qa]` table or `profile = "qa"` there, because Codex then refuses `--profile qa`. An identical existing profile is left alone; a differing one is preserved unless you pass `--update-global`, which backs it up.

```bash
./bootstrap --install-command && ./bootstrap --global-only   # add --update-global to replace differing files
herdr-qa --check /path/to/project        # validates codex, profile and reviewer; starts no session
herdr-qa /path/to/project --no-alt-screen
```

`herdr-qa <dir>` execs interactive `codex --profile qa --sandbox read-only -C <dir>` with the reviewer instructions passed as `-c developer_instructions=...`, so herdr detects the pane as Codex. When `HERDR_TEAM_MANIFEST` is set, the session is told to read that manifest and the herdr-team `PROTOCOL.md` from the Claude config directory, if present. Flags were verified against Codex CLI 0.162.1.

## Verification and documentation

```bash
python3 -m venv /tmp/codex-bootstrap-tests
/tmp/codex-bootstrap-tests/bin/pip install -r verification/pack-validator/requirements.txt
PYTHON=/tmp/codex-bootstrap-tests/bin/python ./verification/run-all.sh
# Optional authenticated, disposable real Codex/Beads smoke:
python3 verification/authenticated-smoke.py
# Separately opt-in: review only the disposable hook via the real /hooks UI.
python3 verification/trusted-hook-smoke.py
```

The suite uses temporary homes/repos, mocked workflow CLIs, real Codex app-server discovery and expected validator rejection for web-design. The authenticated smoke uses existing login without copying credentials and makes bounded model requests; it is separate from offline tests.

See [migration guide](docs/migration-guide.md), [feature parity](docs/feature-parity.md), [configuration](docs/opt-in-configs.md), [troubleshooting and restore](docs/troubleshooting.md), [contract](docs/migration-contract.md), [asset inventory](docs/source-inventory.json) and [verification evidence](docs/verification.md). Marketplace publication is deferred.
