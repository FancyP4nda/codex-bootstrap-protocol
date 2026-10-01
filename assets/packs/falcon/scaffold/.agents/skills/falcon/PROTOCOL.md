# Dispatch protocol

Steering reads the selected Beads and refines readiness before dispatch. Claim
issues in steering, not the worker. Write a bounded prompt and literal scopes.

The helper obtains an exclusive registry lock, rejects overlapping unreleased
scopes and creates falcon/<id> plus a worktree at
.codex/state/tmp/falcon/worktrees/<id>. Workers run codex exec with workspace-write
sandbox and approval_policy=never; permission failures become blocked reports.
They cannot request silent security bypass. Workers do not stage or commit:
`.git` and resolved worktree Git metadata remain protected in workspace-write.
The prompt prohibits external writes, Beads changes, staging/commits and
integration. Scope instructions are advisory; the steering `handoff`/`commit`
gate audits actual staged, unstaged and untracked paths and rejects out-of-scope
or unsafe paths. Steering still reviews correctness/tests before integration.

State transitions: prepared → starting → running → complete or failed;
complete → committed only through explicit steering-owned `commit`.
`complete` certifies a fresh, schema-valid report, not correctness or integration.
Every start/resume gets a unique attempt directory; prior reports/logs remain
separate. No output, wrong types, malformed JSON or failed CLI exit makes that
attempt failed with no current accepted report/hash.
An absent runner becomes interrupted, not proof that writers stopped. cancel
signals the verified owner using pidfd-bound identity; its Linux/WSL supervisor
stops all owned descendants, including detached children, and requires kernel
child exhaustion before certifying quiescence. release unlocks scope only with
that nonce-bound evidence, preserving worktree, commits and reports for recovery.
PID and process start time are checked; unsupported worker platforms fail before
launch. Missing proof preserves ownership and blocks retry rather than orphaning
writers or trusting an empty /proc scan.

amend queues text for the next explicit resume. It does not pretend to inject a
live prompt. Resume uses the saved Codex thread ID, reinstates workspace-write
and never approvals plus the same report schema, and preserves earlier attempt
reports/logs. No thread after a launch failure
means inspect logs, release and redispatch. Amendments to a released dispatch
require a new dispatch.

Validate reports, tests, actual diff scope and unresolved risks in steering.
Run `handoff <id>`, review its exact report/diff hashes and worktree diff, then
`commit <id> --message ... --report-hash ... --diff-hash ...` with explicit commit
authority. The helper uses a private index and a checked branch update; it never
includes another worktree's staged/unstaged content or runs commit hooks.
Steering owns any subsequent cherry-pick/integration, final tests, issue closure
and PRs. No commit/integration/publication is implied by dispatch or monitor.

State paths reject existing symlink ancestors/leaves and nonregular/multiply-
linked files. Python opens use non-following semantics and atomic random temporary
files. Codex writes inside private attempt directories whose output paths are
checked before launch and after completion. This protects pre-existing hostile
links, not an actively racing process with the same UID. Do not treat local state
as an adversarial multi-user isolation boundary.
