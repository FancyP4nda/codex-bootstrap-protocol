# Dispatch protocol

Steering reads the selected Beads and refines readiness before dispatch. Claim
issues in steering, not the worker. Write a bounded prompt and literal scopes.

The helper obtains an exclusive registry lock, rejects overlapping unreleased
scopes and creates falcon/<id> plus a worktree at
.codex/state/tmp/falcon/worktrees/<id>. Workers run codex exec with workspace-write
sandbox and approval_policy=never; permission failures become blocked reports.
They cannot request silent security bypass. The prompt prohibits external writes,
Beads changes and integration. Scope instructions are advisory; steering must
audit the actual Git diff before integration.

State transitions: prepared → starting → running → complete or failed.
An absent process becomes interrupted. cancel terminates the verified process
group and retains state; release unlocks scope after the process is inactive,
preserving worktree, commits and report for recovery. Process identity includes
PID and process start time to avoid signaling a reused PID.

amend queues text for the next explicit resume. It does not pretend to inject a
live prompt. Resume uses the saved Codex thread ID, reinstates workspace-write
and never approvals, and preserves reports/logs. No thread after a launch failure
means inspect logs, release and redispatch. Amendments to a released dispatch
require a new dispatch.

Validate reports, tests, diff scope and unresolved risks in steering before
cherry-picking worker commits. Steering owns final tests, issue closure and PRs.
