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

## Command and worker recovery

A command collision is reported before symlink/profile changes. Inspect `command -v codex-bootstrap` and PATH. Removal touches only this kit's owned link and optional marked PATH block; it does not uninstall project/global assets. If the kit alone moved, inspect/remove the old broken owned link and install from the new checkout.

Falcon `status` detects stale/interrupted processes. Keep worktrees and logs, queue an `amend`, then explicitly `resume`. `cancel` verifies process identity; `release` refuses an active worker and releases scope ownership without discarding reports/worktrees. Monitor `stop` is required when you no longer want polling. PR observations require optional authenticated gh; monitor failures remain visible.

Claude critique unavailable or failing falls back to isolated read-only Codex; failed authentication/network remains an actionable review failure. Never treat missing critique as approval.

Web-design is intentionally rejected by the release validator (evidence-null). Do not fabricate evidence, add a pack.stamp, or treat acknowledgment as vetting.
