# Migration verification evidence

Baseline: Linux, Codex CLI 0.159.2, Python 3.14.7, Node 26.8.2 and Beads 1.3.0,
2026-09-30. Validator dependencies are pinned separately; bootstrap needs no
third-party Python packages. Source commit: f89f7f3dffb1150fa7df30b180b397dd25a711f9.

## Automated gates

`PYTHON=<validator-venv>/bin/python ./verification/run-all.sh` runs:

- Bash/Python/all vendored JavaScript syntax; complete manifest coverage;
  22 unique skill headers/supporting references; ten native TOML agents;
  canonical kit mirrors, source inventory hashes and obsolete runtime scan.
- 30 installer tests: fresh/retrofit/repeat, custom CODEX_HOME, paths with spaces,
  local/global core, preservation/updates/obsolete hashes, Beads failures,
  conflict/force/backups, symlinks, malformed/cross-pack manifests, native config,
  hooks/trust/deduplication, every pack, command relocation/collision/removal,
  no-prompt automation, wizard decline, retained pack metadata and preserving
  an obsolete file modified during the final confirmation.
- Two native-role tests covering all ten TOML profiles, exact developer settings,
  sandbox modes, no model pins and unsafe role/traversal rejection.
- Six web-helper tests: native JSON merge/repeat/backup, inline-hook and malformed
  JSON rejection, symlink protection, user preferences and filename injection.
- Ten workflow tests: Falcon completion/amend/resume/release/cancel/paste, scope
  locks, stale records, monitor restart, missing launch, review restrictions and
  ordinary-repo/compaction orientation.
- 28 validator and eight updater checks; real web-design release rejection for
  absent evidence, with no pack.stamp.
- Real Codex app-server discovery of all 22 skills and explicit skill-input
  expansion of their full canonical bodies into a loopback mock model request.
  Valid native footer/notifications; orientation hook observed as untrusted.

Initial migration total: 84 behavioral/validator/updater checks, plus static and
real CLI gates. This is historical baseline evidence; the systems remediation
adds separate regressions and acceptance below.
All test projects/homes are temporary. The loopback mock is test-only and makes
no external model call. Process/socket sandboxes may require permission to run
that local fixture; rejection is not silently skipped.

## Authenticated disposable smoke

`python3 verification/authenticated-smoke.py` separately uses the existing Codex
login through a temporary auth link (no credential copy). Test sessions and
Beads are isolated. It verifies real local-core/project initialization, Falcon
and Herald installation, authenticated `$session-start`, read-only Beads stats,
a read-only native config reviewer, no tracked project edits, and actual TUI
footer rendering with model/context percentage/branch/directory in a PTY.

The reviewer correctly found that fresh AGENTS build/test commands are user-fill
placeholders. That is expected scaffold content, not a hidden success claim.

Codex 0.159.2's exposed generic spawn interface did not support named-role
selection. Initial tests truthfully failed that criterion, and ephemeral spawning
also exposed a thread-store limitation. The shipped compatibility loader parses
the canonical role TOML and applies supported native exec settings instead.
Named-role spawning is not claimed verified; see native-agents.md.

## Limits and truthful state

The real model smoke does not complete every long product/design workflow.
All skills are discovered and explicitly loaded; behavioral workflow checks use
controlled mocks where appropriate. macOS/WSL were not executed on this Linux
host. Hooks are prepared and payload-tested but never silently approved; real
CLI trust remained untrusted in the initial migration gate. The separately
approved remediation check below exercises only disposable hook trust.
Documentation MCP authentication is not automated.

Web-design remains unverified/release-invalid. Licenses, pins and digests are
preserved/refreshed; migration integrity and inherited human triage are not an
adjudicated scanner evidence bundle. No release stamp is manufactured.

Previous verification/PRD/plan history remains archived and in durable YAML;
old passing checks are not substituted for this migration's gates.

## Systems-review remediation

The F01–F15 contracts, baseline reproductions, independent review and fresh
acceptance results are maintained in [remediation-review.md](remediation-review.md).
Use `BOOTSTRAP_TEST_BASH32=/absolute/path/to/bash-3.2` with the pinned validator
environment for the real shell gate; missing that fixture is a skip, not a pass.
Linux/WSL worker supervision requires subreaper/pidfd capabilities and refuses
before launch on unsupported platforms. This Linux host is not a macOS/WSL or
native Windows execution matrix.

Both separately authorized supplemental checks passed in this remediation:

- `python3 verification/authenticated-smoke.py`: real Beads/local-core install,
  read-only authenticated session, native TOML compatibility loader, unchanged
  tracked content and native PTY footer.
- `python3 verification/trusted-hook-smoke.py`: normal project and `/hooks` UI
  review of one disposable handler; enabled/trusted native observation, real
  advisory Stop warning delivery, second-turn deduplication and no continuation
  or model-context warning. This uses a loopback model, not credentials or a
  trust bypass. At the handler review screen use `:trust` to send only the trust
  key, then `:check`; `:enter` on the enabled row would toggle it off. Every
  fixture and its temporary trust record is removed after the check.

Final remediation gate: exit 0; 166 behavioral tests (including five actual
Bash 3.2 cases), 28 validator and eight updater checks passed, with no skips.
Static integrity/syntax/mirror checks and real CLI discovery/explicit loading
of all 22 skills also passed. See the remediation record for the independently
reviewed contracts, intermediate failures/fixes, exact environment and boundaries.
