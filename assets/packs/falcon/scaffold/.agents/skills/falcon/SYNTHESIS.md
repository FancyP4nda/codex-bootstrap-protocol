# Worker report synthesis

Read the complete dispatch record and current attempt. Verify `report_hash`
before interpreting its unique report. Earlier successful reports do not satisfy
a failed amendment/resume. Check branch/base identity, actual changed files
against scope and reported verification. Workers leave changes uncommitted.

Steering runs `handoff <id>` to audit actual changed/untracked files and current
report identity/schema/hash. Inspect the actual Git diff and reported tests/risks;
the helper's scope audit does not prove correctness. With commit authority, run
`commit <id> --message ... --report-hash <reviewed> --diff-hash <reviewed>`.
This produces a steering-owned scoped commit in the isolated branch and returns
its SHA. A report/diff change fails closed and requires a new review. The helper
uses a private index, preserving unrelated staged content and the main checkout.

Steering integrates the returned reviewed commit only with integration authority,
runs combined verification and then updates the established Beads/handoff/
changelog records through $session-wrapup. Publication needs its own applicable
authorization; the helper never pushes or changes Beads.
If the steering checkout has unrelated staged work, use a separate clean
integration worktree/branch for the authorized cherry-pick; Git may refuse a
dirty-index cherry-pick. Do not silently stash, reset or include unrelated work.
Preserve unresolved risks and queued amendments. Release the scope explicitly
only after the worker is inactive and its changes are accounted for. Worktrees
and logs remain available for recovery; no cleanup deletes unintegrated work.

If a steering commit was interrupted after preparing/publishing its commit,
`recover <id>` checks the saved parent/tree/branch identities. If the branch stayed
at the reviewed parent, it clears the pending record so handoff/commit can be
reviewed and retried. If the commit reached the branch, it finalizes only reviewed
index paths and records the commit without touching source. Any unexpected HEAD
is a manual-inspection blocker. Do not resume/release a pending commit; recover
first. Reports with no accepted current evidence cannot be committed: preserve
the worktree, inspect logs, amend/resume if a session exists, or release/redispatch
after accounting for the source changes.
