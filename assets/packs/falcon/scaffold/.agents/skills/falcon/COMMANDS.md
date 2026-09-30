# Falcon command interface

Invoke as `$falcon <subcommand>`; the skill runs its bundled Python helper.

```bash
python3 <skill-dir>/scripts/falcon.py --root <repo> dispatch --prompt-file <file> --scope src/module --bead <id>
python3 <skill-dir>/scripts/falcon.py --root <repo> status
python3 <skill-dir>/scripts/falcon.py --root <repo> amend <id> 'bounded additional instruction'
python3 <skill-dir>/scripts/falcon.py --root <repo> resume <id>
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
