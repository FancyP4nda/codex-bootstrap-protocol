# Systems review remediation evidence

Review baseline: `190f8daa13abeff033916b4b8556d464723d5d4e`, 2026-09-30.
The earlier 84 passing checks missed these lifecycle and integration failures.
This record supplements, rather than replaces, the migration history. Beads
epic `codex-bootstrap-protocol-d0p` and children `.1`–`.6` hold remediation and
independent review dispositions.

## Finding-to-contract mapping

| Finding | Implemented acceptance contract | Regression evidence |
|---|---|---|
| F01 | Optional/merged configuration ownership is separate from core retirement; omitted flags retain prior choices and personal edits | `test_installer_remediation.py`: global/project update, repeat, legacy metadata, modified settings, hook deduplication |
| F02 | Workspace-write workers implement/test only; steering audits actual scope and fresh report and owns hash-bound commit/recover/integration | `test_falcon_remediation.py`: real no-model sandbox source edit/Git denial and steering integration preserving unrelated work |
| F03 | Linux/WSL owned-descendant subreaper uses exact pidfd signaling and nonce-bound quiescence proof before rollback/retry; unsupported workers fail before launch | `test_web_shutdown_remediation.py`: late/resistant/detached descendants, leader/caller exit, interrupts, rollback/retry, inspection failure and real server lifecycle |
| F04 | Empty arrays expand safely on Bash 3.2 and failures return truthful status | `test_installer_remediation.py`: real Bash 3.2 dry-run/global/project/local-core/config/metadata/conflicts |
| F05 | Required core resources resolve from the loaded skill; delegated roles receive resolved paths or choose project-local before global | `test_prompt_remediation.py`: clean-home installed local-core links and stale global resources |
| F06 | Supporting guides honor current request/project authority; checkpoint has no implied commit/push; normal Git does not imply Dolt remote sync | `test_prompt_remediation.py`: shared contract checks and independent scenario review |
| F07 | All consumers use dispatch, current attempt report pointers and steering verification; sequential work is explicit ordered dispatch | `test_prompt_remediation.py`, Falcon lifecycle regressions and non-author consumer review |
| F08 | Attempt-specific fresh outputs require full report schema/types; prior evidence remains history | `test_falcon_remediation.py`: absent/stale/malformed/partial/wrong-type/fresh output and resumed schema flags |
| F09 | Managed leaves/ancestors reject hostile links; non-following regular-file opens and exclusive random atomic writes | `test_falcon_remediation.py`: state/log/report/lock/worktree sentinels; not same-UID active-race isolation |
| F10 | Native hooks point to the validated actual installed project script, not an outer Git root | Dedicated hook remediation tests and nested-project diagnostics |
| F11 | Configuration presence is not trust/execution; unknown or disabled/broken hooks retain bounded manual QA | Dedicated hook remediation tests; no trust manufactured |
| F12 | Stop output uses its native event contract, with explicit advisory delivery and bounded deduplication | Dedicated hook tests and separately approved disposable real `/hooks` trust/delivery check |
| F13 | Canonical report-only navigator explicitly selects read-only sandbox; parent overrides and connectors are separate limitations | `test_prompt_remediation.py`, existing native role/helper tests and official-docs review |
| F14 | Strict health fails missing/invalid required core, reports valid customization and supports local-core without globals | `test_installer_remediation.py`: status/output/optional helper/custom CODEX_HOME/inventory semantics |
| F15 | Active labeling example uses the supported comma-separated labels form | `test_prompt_remediation.py`: disposable real Beads 1.3.0 mutation and label readback |

## Baseline and verification provenance

All installer/configuration/runtime fixtures use temporary homes, CODEX_HOME,
repositories and sentinels. The source sibling remains read-only at
`f89f7f3dffb1150fa7df30b180b397dd25a711f9`. No personal installation, credential
copy, personal hook trust grant, model pin or OS service is part of remediation.
The user separately approved one bounded authenticated smoke and a normal
`/hooks` review of only a disposable test handler. Those gates are recorded
individually below; permission is not a passing result.

Installer baseline checks reproduced optional-config deletion, false healthy
doctor status and Bash 3.2 false-success/incomplete installs before fixing.
Ten core prompt regressions cover local resources, role-layer selection, supported
metadata, native mode, supporting
authority, command/report contracts and actual Beads label behavior; the first
five failed before edits. Falcon's retained baseline reproducer shows old-report
acceptance and predictable-temporary-file sentinel overwrite. Web process tests
use real spawned delayed/resistant writers, not mocked shutdown promises.

The fresh GNU Bash 3.2 fixture is built from the GNU distribution into a
temporary directory. This is shell behavior on Linux, not an executed macOS or
WSL platform matrix. A missing Bash fixture is a skipped gate, never a pass.

Final full-suite totals, independent reviews and integration boundaries are
recorded below. Individual author tests were not substituted for acceptance.

## Final integrated acceptance

All F01–F15 are fixed, regression-covered and independently accepted. The final
stable integrated command exited **0**, with **no skips**:

```bash
BOOTSTRAP_TEST_BASH32=<actual-bash-3.2-fixture> \
PYTHON=<pinned-validator-venv>/bin/python ./verification/run-all.sh
```

- 166 behavioral tests passed (291.034 seconds): 60 installer tests including
  five actual Bash 3.2 cases; 15 Falcon; ten legacy workflows; two native-role;
  ten prompt/resource; six supervisor; four trusted-hook harness; six legacy web
  helpers; 22 hook adaptation; 31 web shutdown/HTTP/recovery.
- 28 validator and eight updater checks passed: **202 checks total**, plus static
  integrity/syntax/mirror checks and real CLI integration. Expected invalid
  fixtures and the real unverified web-design pack were correctly rejected.
- Real CLI 0.159.2 discovered and explicitly loaded all 22 skill bodies, loaded
  native configuration/footer identifiers and notifications, and observed hooks
  as untrusted without silently approving them. Codex's temporary PATH-alias
  warning did not prevent these checks.
- The separately approved authenticated and disposable trusted-hook smokes
  passed as recorded below. Personal config/trust/installation was not changed.
- Source sibling stayed clean and read-only; all 257 frozen source mappings and
  hashes were preserved. Native digests/mirrors were regenerated; no release
  stamp was written. Three confirmed stale disposable fixture processes were
  stopped with birth-verified pidfds, without signaling current/unrelated
  processes or zombies.

This is Omarchy/Linux execution evidence, including GNU Bash 3.2 on Linux.
macOS/WSL/native Windows execution was not performed. Linux/WSL workers require
the checked subreaper/pidfd capabilities; macOS/native Windows workers refuse
launch, and native Windows installation requires WSL. Native named-role spawning
remains client-dependent; the exec-config compatibility path is verified.
Connector/tool permissions are separate from shell sandbox settings. Web-design
remains opt-in, unverified and release-invalid until genuine external evidence
exists; these functional checks do not certify it.

## Supplemental gates performed in this remediation

- Fresh authenticated smoke: CLI 0.159.2, real disposable Beads initialization,
  local-core/Falcon/Herald installation, authenticated read-only `$session-start`
  and Beads stats, canonical TOML exec-config reviewer and real PTY footer all
  passed. No workers ran; tracked project content stayed unchanged. Fresh AGENTS
  verification placeholders were correctly reported by the reviewer, not hidden.
- Real hook client: `verification/trusted-hook-smoke.py` used a temporary home
  and project with exactly the reviewed bundled Stop handler. The normal Codex
  project trust and `/hooks` review UI persisted trust only inside that fixture.
  `hooks/list` observed the one enabled, trusted, non-managed handler. Real
  `hook/completed` delivered the bundled detector finding as a `warning` entry;
  a second turn delivered no duplicate. Exactly two loopback model requests
  occurred, with no automatic continuation and no warning in model context.
  The fixture (including its trust) was removed; personal configuration and
  credentials were not involved. This is client delivery evidence, not a claim
  that every installed project's hooks are trusted or provide current QA coverage.
- The hook test harness initially failed because one UI key toggled the freshly
  trusted handler off, then because buffered text transport hid queued events.
  Both fixture errors were corrected; neither attempt was counted as a pass.
- Non-author installer inspection and 25 fresh installer-remediation checks
  passed. Its author also ran all 60 installer tests, including five actual GNU
  Bash 3.2 cases. Independent prompt review covered all ten prompt checks,
  global-with-pack, local-with-stale-global and missing-local-resource fixtures.
- Independent hook review found and corrected additional malformed-handler and
  ownership-classification failures. Lead reran the final 22 dedicated hook
  regressions, all passing, after the additional actual legacy-command doctor
  regression. Six legacy-helper tests also pass. HTTP route/restart recovery and
  the integrated suite remain separate acceptance gates.
- Independent supervisor review reproduced a fork-during-`/proc`-enumeration
  race: a new detached writer was absent from the name snapshot, so the old
  supervisor falsely certified an empty live set. The fix requires kernel child
  exhaustion (`waitpid` reports ECHILD after the direct child is reaped), not
  another scan or a sleep. A deterministic real-fork regression checks both
  injected race and absence of later writes. Three no-launch failures also
  failed before correction and now certify no worker was launched, permitting
  safe recovery without weakening post-launch ownership.
- A second independent real-process reproduction killed the caller before the
  supervisor captured its parent. The old helper adopted a long-lived ancestor
  and launched an orphan writer after caller death. Both launchers now capture
  their actual PID and decimal `/proc` start-time before spawn and pass a required
  identity to the helper. Prelaunch death/reuse refuses launch with a durable
  no-worker certificate; postlaunch monitoring remains bound to that original
  identity. Tests cover actual reparenting and delayed interpreter startup, not
  only already-running supervision. Falcon shutdown certificates also reject
  booleans, zero, negative, fractional and string PIDs.
- An integrated 165-test run then exposed three legacy Falcon lifecycle failures:
  `ps lstart` treated exited-but-unreaped runners and monitors as alive, blocking
  cancel, resume and monitor restart. Linux identities now use `/proc` start-time
  ticks and exclude zombie/exited states. Legacy timestamp records conservatively
  retain live ownership but cannot authorize automatic signaling. Monitor stop
  signals the exact pidfd-bound owner, not a numeric process group. A real-zombie
  regression and all ten legacy workflow tests pass; the failed integrated run
  is not acceptance evidence.
- Independent real HTTP review reproduced overlapping Apply/rollback/discard
  restoring a live transaction, plus startup restore racing surviving writers
  after server SIGKILL. Durable operation ownership now fences these restoration
  paths before any write; concurrent recovery uses a kernel lock. Legacy unowned
  transactions and unconfirmed external chat writers fail closed for inspection.
  Transaction ownership must match current or certificate-verified prior owners;
  malformed records and failed restore retain snapshots instead of discarding
  recovery data. Proven no-launch errors remain retryable; uncertain launches
  retain ownership. These recovery edges have their own regressions and review.
- Recovery state is schema-checked before interpreting absence, completion or
  shutdown: malformed owner identity/certificates, transaction containers and
  snapshot records, and pending buffers preserve evidence and block mutation.
  Synchronous invalid launch arguments are rejected before durable worker intent;
  normalized environment values are exactly those passed to launch. Failed
  restoration throws through startup and every Apply/rollback/discard consumer,
  rather than letting a partial failure become a successful HTTP/UI result.
- The first integrated attempt caught two inventory destinations still pointing
  at deleted legacy MCP fixture JSON. The generator now maps those destinations
  to native TOML while preserving their original source names and frozen hashes.
  All 257 original source mappings remain intact; mirrors and supervisor copies
  are checked for byte equality by the static gate.
- Final current-docs review found and corrected local role fallback to stale
  globals, nonstandard Minion metadata, duplicate-skill precedence claims and
  first-run hook setup wording. All 22 skills pass the skill-creator validator;
  provenance metadata is retained in its supported container. Claude residue
  was classified rather than erased: bounded read-only optional review,
  compatibility, frozen provenance/licenses and history remain intentionally.
- Independent review of the hook acceptance harness found broad text matching
  could accept failed output or a missing second execution. It now requires
  exact successful native Stop completion and warning delivery, then successful
  silent second execution; negative fixtures cover false-delivery cases. Closed
  input aborts instead of sending implicit Enter/consent. The tightened real UI
  gate was rerun successfully; four harness regressions also passed.

## Current official interfaces

Final component acceptance used reviewers other than the relevant authors:

| Scope | Non-author acceptance |
|---|---|
| A: installer/config/doctor | Lead inspection and 25 fresh checks; full installer/Bash 3.2 gate is integrated below |
| B: prompts/native roles/docs/residue | Installer finishing reviewer, including clean/stale-global/missing-local scenarios |
| C: Falcon and canonical supervisor | Web runtime reviewer: 15 Falcon and 10 legacy workflow checks, six supervisor checks and independent startup/zombie reproductions |
| D: web shutdown/HTTP/recovery | Two independent reviewers: final 31 shutdown/recovery plus six legacy helper checks; separate 26 corrupt-state fixtures preserve data |
| E: hook configuration/output/ownership | Lead and installer reviewer inspected/tested the portions they did not author; final 22 hook and four delivery-harness regressions, plus approved real client delivery |

Environment: Omarchy/Linux `7.2.5-3-omarchy`, Bash `5.3.15(1)` and actual GNU
Bash `3.2.0(2)` built temporarily on Linux, Python `3.14.7`, Node `26.8.2`, Codex
CLI `0.159.2`, Beads `1.3.0`. The disposable pinned validator environment uses
PyYAML `6.0.3` and jsonschema `4.26.0`.

Fetched official pages on 2026-09-30; installed CLI `0.159.2` behavior is checked
separately from documentation. In particular, protected worktree Git metadata,
native omitted-setting inheritance, hook trust and event-specific output are
not inferred from legacy mocks.

- [Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [Approvals/security](https://learn.chatgpt.com/docs/agent-approvals-security)
- [Hooks](https://learn.chatgpt.com/docs/hooks)
- [Skills](https://learn.chatgpt.com/docs/build-skills)
- [Config reference](https://learn.chatgpt.com/docs/config-file/config-reference)
- [Environment](https://learn.chatgpt.com/docs/config-file/environment-variables)

Web-design remains explicitly unverified and release-invalid. Functional fixes,
native integrity hashes, regression evidence and inherited human triage do not
constitute the absent adjudicated scanner/operator release evidence. No stamp
or trusted-hook delivery claim is generated from JSON serialization alone.
