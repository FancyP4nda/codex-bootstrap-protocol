# Verification

Verification assets for the scaffold live here.

T001 owns this placeholder so later beads have a stable location for shell syntax checks, reference scans, relocation scans, conflict fixtures, and disposable install/readback helpers.

The first structural checks are:

```bash
find . -maxdepth 2 -type d -print
rg -n "<absolute source path>|<legacy Claude runtime path>" bootstrap README.md AGENTS.md .agents .codex verification --glob "!**/__pycache__/**"
```

Expected T001 result: no matches when the placeholders above are replaced with the real forbidden reference patterns from the Bead.
