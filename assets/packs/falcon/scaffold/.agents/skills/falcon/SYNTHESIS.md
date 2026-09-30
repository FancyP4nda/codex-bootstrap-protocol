# Worker report synthesis

Read complete dispatch records and verify report_hash before interpreting a
report. Check branch/base identity, actual changed files against scope, worker
commits and the reported verification. Report mismatches as incomplete work.

Steering integrates reviewed commits, runs combined verification and then
updates the established Beads/handoff/changelog records through $session-wrapup.
Preserve unresolved risks and queued amendments. Release the scope explicitly
only after the worker is inactive and its changes are accounted for. Worktrees
and logs remain available for recovery; no cleanup deletes unintegrated work.
