---
name: session-wrapup
description: Verify and close a work session, preserve Beads and durable handoff where present, and commit or publish only under the repository's authorized workflow.
---

Run the checks appropriate to the changes, taking commands from project
instructions and manifests. Report failures with evidence; do not treat skipped
checks as passes. Inspect Git status and summarize the work.

If .beads and bd are usable, close verified work, leave resume notes on unfinished
issues and export tracked records through normal Git. Skip all Beads operations
in ordinary repos. Do not require a particular backend or remote Dolt sync.

Maintain existing project documentation when the session changed its contracts.
For projects adopting bootstrap state files, read [handoff-schema.md](handoff-schema.md)
and [changelog-schema.md](changelog-schema.md), prepend entries without replacing
history, and validate with an available YAML parser. In a plain repo, provide
the summary and next action in chat; no docs scaffold is required.

If Falcon reports exist, read the installed Falcon SYNTHESIS.md and validate
worker changes before closing issues. Integration belongs to steering.

Commit the scoped work and push only when the user or repository workflow
authorizes it. Preserve unrelated changes, stashes and remotes. State what was
verified, what remains and the precise next step. Publication failure is a
reported blocker; never say a failed push succeeded.
