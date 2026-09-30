#!/usr/bin/env python3
"""Advisory Codex SessionStart hook; reads only bounded project context."""
import json
from pathlib import Path
import subprocess
import sys


def context(event):
    if event.get("hook_event_name") != "SessionStart":
        return {}
    cwd = Path(event.get("cwd", "."))
    try:
        result = subprocess.run(["git", "-C", str(cwd), "rev-parse", "--show-toplevel"],
                                capture_output=True, text=True, timeout=2)
        root = Path(result.stdout.strip()) if result.returncode == 0 else cwd
    except (OSError, subprocess.TimeoutExpired):
        root = cwd
    notes = ["Bootstrap orientation: follow AGENTS.md. Invoke $session-start for the current work queue."]
    for rel in ("docs/CONTEXT.md", "docs/handoff.yaml", "docs/changelog.yaml"):
        p = root / rel
        if p.is_file() and not p.is_symlink():
            with p.open() as stream:
                notes.append(f"{rel}:\n{stream.read(5000)}")
    if (root / ".beads").is_dir():
        notes.append("Beads is present. Run bd prime and inspect bd ready before claiming work.")
    else:
        notes.append("No Beads workspace: orient from Git status, recent commits and README; skip Beads operations.")
    return {"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "\n\n".join(notes)}}


if __name__ == "__main__":
    try:
        print(json.dumps(context(json.load(sys.stdin))))
    except (ValueError, OSError, TypeError) as exc:
        print(f"bootstrap orientation: {exc}", file=sys.stderr)
        sys.exit(1)
