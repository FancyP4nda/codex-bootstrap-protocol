# Local polling monitor

This native replacement for provider cron tools runs while its process is alive.
Start with monitor start (default 30 seconds; --interval changes it), inspect with
monitor status and stop with monitor stop. Stale PID/start identity records are
recoverable by start. No systemd, launchd, OS scheduler or persistent service is
installed. After logout or restart, explicitly start another monitor if needed.

Each poll detects interrupted workers and reads existing PR state, review decision
and merge eligibility when a PR was explicitly attached through watch-pr. It
records observations only. Errors remain visible in dispatch state. Publication
or merge requires steering's separately authorized workflow.
