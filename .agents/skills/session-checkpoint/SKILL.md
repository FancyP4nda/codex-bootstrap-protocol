---
name: session-checkpoint
description: Save a concise work checkpoint before compaction or interruption, using existing Beads and handoff formats when present.
---

Inspect current Git status and summarize what is finished, what is in progress,
the next command or file, and known blockers. Preserve existing changes.

If a usable Beads workspace exists, attach a resume note to each touched active
issue and export tracked records using the repository's established workflow.
If docs/handoff.yaml exists, preserve its schema and prior entries; use the
session-wrapup handoff-schema.md only when this project adopts that schema.
Otherwise give the checkpoint in chat. Do not create a new documentation tree
in an ordinary repo solely to checkpoint it. No commit or push is implied.
