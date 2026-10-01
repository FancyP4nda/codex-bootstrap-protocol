# Falcon command interface

Invoke as `$falcon <subcommand>`; the skill runs its bundled Python helper.

```bash
python3 <skill-dir>/scripts/falcon.py --root <repo> dispatch --prompt-file <file> --scope src/module --bead <id>
python3 <skill-dir>/scripts/falcon.py --root <repo> status
python3 <skill-dir>/scripts/falcon.py --root <repo> amend <id> 'bounded additional instruction'
python3 <skill-dir>/scripts/falcon.py --root <repo> resume <id>
python3 <skill-dir>/scripts/falcon.py --root <repo> handoff <id>
python3 <skill-dir>/scripts/falcon.py --root <repo> commit <id> --message 'reviewed scoped change' --report-hash <reviewed-report-hash> --diff-hash <reviewed-diff-hash>
python3 <skill-dir>/scripts/falcon.py --root <repo> recover <id>
python3 <skill-dir>/scripts/falcon.py --root <repo> cancel <id>
python3 <skill-dir>/scripts/falcon.py --root <repo> release <id>
python3 <skill-dir>/scripts/falcon.py --root <repo> paste <id>
python3 <skill-dir>/scripts/falcon.py --root <repo> watch-pr <id> <existing-pr-url>
python3 <skill-dir>/scripts/falcon.py --root <repo> monitor start
python3 <skill-dir>/scripts/falcon.py --root <repo> monitor status
python3 <skill-dir>/scripts/falcon.py --root <repo> monitor stop
```

Repeat --scope and --bead. --paste prepares a dispatch and prints the prompt
without starting a worker. No implicit remote execution. Existing PR watching
requires gh credentials and makes read-only observations; unavailable review
status is recorded as an error. Monitor does not merge or create PRs.

`autopilot start|status|stop` is an alias for the same stoppable monitor.

`handoff` is steering's read-only Git audit (it records the audit in ignored
dispatch state). Review its `files`, `report`, `report_hash`, `diff_hash`, tests
and risks together with the actual worktree diff. `commit` is a separate explicit
steering action: it revalidates those hashes and commits only scoped changes to
the isolated branch. It never changes the steering checkout, integrates, pushes,
closes Beads or opens a PR. A changed diff/report requires a new reviewed handoff.
`recover` reconciles an interrupted steering commit without overwriting source;
then inspect status before deciding whether to retry or integrate.

Sequential work is explicit: dispatch one scoped task, wait for current evidence,
review/commit/integrate as authorized, release, then dispatch the next. There is
no `work beads ... --sequential` command.

Workers require Linux/WSL subreaper and pidfd support; unsupported platforms
(macOS/native Windows included) fail before worker launch. `cancel` waits for
owned descendants, even detached/resistant children, to become quiescent.
`release`, `resume`, `handoff`, `commit` and `recover` require nonce-bound
shutdown evidence; runner exit alone is insufficient. If proof is unavailable,
keep scope/state/owner intact and inspect the error. Do not kill the supervisor
or remove locks to force retry. The monitor and report inspection are separate
from worker-launch capability. Only Linux has been exercised in this release.
