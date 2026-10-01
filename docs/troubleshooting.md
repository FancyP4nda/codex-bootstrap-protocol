# Troubleshooting and restore

## Prerequisites and conflicts

Bootstrap installs no packages. Missing Python 3.11+, Git, Codex or Beads produces actionable guidance before payload/global writes. Web-design also needs Node.js 22+. Install these separately and rerun the same command. `--dry-run` needs only Bash/Python/Git.

Existing Beads is validated read-only. If initialization fails, run `bd doctor` in the exact target and inspect its partially initialized .beads before rerunning the printed command. Git/Beads initialization can precede payload copy after full preflight; a failure is never reported as success.

Symlinks anywhere along destination paths are rejected, even internal links. Use real directories, inspect the exact link and reconcile manually. Never solve a safety failure using `--force`. Structural/cross-pack/protected-path conflicts always fail. Move or adapt a conflicting pack file explicitly after backing it up.

Unusual targeted TOML key layouts fail instead of guessing. Reformat just the named setting into an ordinary table/key while preserving unrelated content. Inline hooks and hooks.json cannot coexist at the same layer; review/reconcile in Codex first. Trust the project, then use `/hooks`. Changed definitions require renewed review.

## Backups and restore

Overwritten files and retired unchanged global files are backed up under the owning layer's `bootstrap-backups/<run-id>/<relative-path>`. Layers include the project, ~/.agents and CODEX_HOME. Command PATH edits back up the shell profile under the home layer. Web-design's opt-in editor uses adjacent uniquely named .bootstrap-backup files.

Stop active Codex/Falcon workers before recovery. Inspect the exact backup and destination, then copy the individual backup back to its matching path. Do not recursively overwrite a home directory or the entire repository. Restoring managed content can make recorded hashes stale; run dry-run and reconcile metadata through a subsequent explicit install/update. Hook restore still requires /hooks review.

Partial file-copy failure names its run-id and affected layers. Correct permissions or disk capacity, inspect backups, and rerun the exact invocation. Unmanaged files and modified obsolete globals are never deleted by an update.

Core updates retain opted-in personal configuration even when flags are not
repeated. If upgrading from the earlier release that deleted optional files,
inspect the CODEX_HOME backup for `config.toml`, `hooks.json` and
`hooks/session-context.py`. Compare each file and restore only missing intended
content, preserving newer personal settings. The fix cannot automatically
reconstruct configuration already removed by a previous invocation. Renew
`/hooks` review for restored or changed definitions; do not copy trust records.

`--doctor` is a read-only health check: missing/invalid required core fails;
valid differing content is reported as preserved customization. For local-core,
use `codex-bootstrap --doctor /exact/project`, or add `--local-core` if project
metadata is unavailable. A healthy local-core project needs no global core.
For only the personal/global installation, use `codex-bootstrap --doctor
--global-only`; this skips Beads and unrelated current-directory project state.

## Command and worker recovery

A command collision is reported before symlink/profile changes. Inspect `command -v codex-bootstrap` and PATH. Removal touches only this kit's owned link and optional marked PATH block; it does not uninstall project/global assets. If the kit alone moved, inspect/remove the old broken owned link and install from the new checkout.

Falcon `status` detects stale/interrupted processes. Keep worktrees and logs, queue an `amend`, then explicitly `resume`. `cancel` verifies process identity; `release` refuses an active worker and releases scope ownership without discarding reports/worktrees. Monitor `stop` is required when you no longer want polling. PR observations require optional authenticated gh; monitor failures remain visible.

A worker must not stage/commit under workspace-write. Use steering `handoff` to
audit current fresh report/hash and actual changed/untracked scoped paths, review
and test them independently, then `commit` with both reviewed hashes. Changed
hashes or out-of-scope files fail closed; inspect the exact worktree rather than
widening sandbox permissions. Root-checkout work is not staged by this command.
If commit publication was interrupted, inspect `pending_commit` and use
`recover <id>`; do not redispatch over unfinished integration. Resume reports
are attempt-specific: missing/malformed current output fails even if a previous
report succeeded. Preserve `.codex/state/tmp/falcon` history during recovery.

Linux process identities use start-time ticks; exited/zombie runners do not count
as active writers. Older timestamp-based records may still hold a live owner,
but cannot authorize automatic signaling. Preserve that record and inspect the
original process instead of deleting the lock or sending a numeric group kill.
Stop existing workers/monitors before replacing their runtime helpers.

Worker launch requires Linux/WSL subreaper and pidfd support. Unsupported
macOS/native Windows workers stop before launch; use a Linux/WSL environment
for Falcon and web copy-edit/validation, not a permission bypass. Installer
shell portability does not imply native Windows or macOS worker supervision.
Cancellation requests TERM, then the supervisor escalates only its owned
descendants, including detached children. Release/resume/rollback/retry require
a nonce-bound quiescence certificate, not just a missing runner PID. If shutdown
cannot be verified, keep the transaction, scope, worktree and owner evidence;
inspect the exact error and supervisor before proceeding. Do not kill that owner
or erase state to unlock a still-writing task. Server shutdown also awaits this
barrier before restoring copy edits.

Web manual Apply holds a durable project-local operation lease from before
recovery/snapshot until validation and transaction cleanup. Overlapping Apply,
rollback or discard returns HTTP 409 without restoring files; wait for the
current operation instead of repeatedly pressing Apply. After server SIGKILL,
startup refuses restoration until every registered supervisor has matching
quiescence evidence. Retry startup only after that shutdown completes. The lease
is serialized with a kernel lock so competing restart attempts cannot replace
a new live owner. Legacy transactions without ownership evidence and timed-out
external chat writers require manual inspection; they are deliberately not
automatically rolled back. Preserve their transaction/snapshots, confirm all
writers stopped, and review the exact recovery data before any manual restore.
Inspect `.impeccable/live/manual-edit-operation-owner.json`,
`manual-edit-apply-transaction.json`, and
`manual-edit-worker-evidence/<owner>/<nonce>.json` from the exact project root.
These records contain the owner identity, worker certificate and original file
snapshots. A blocked startup has no live status endpoint; use direct read-only
inspection. Failed restore retains its snapshot and pending buffer for repair.

Claude critique unavailable or failing falls back to isolated read-only Codex; failed authentication/network remains an actionable review failure. Never treat missing critique as approval.

Web-design is intentionally rejected by the release validator (evidence-null). Do not fabricate evidence, add a pack.stamp, or treat acknowledgment as vetting.
