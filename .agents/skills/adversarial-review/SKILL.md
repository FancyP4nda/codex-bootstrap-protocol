---
name: adversarial-review
description: Critique a planning artifact with optional read-only Claude CLI review or a labeled isolated Codex reviewer before implementation.
---

Codex owns the artifact, adjudicates findings and makes every revision. The
reviewer only returns critique. Read [runner.md](runner.md) for the bounded
round process and invoke scripts/review.py with the artifact path.

Use optional Claude CLI for cross-provider critique when available. Its tools
are restricted to Read, Grep and Glob, with plan permission mode. If missing,
unavailable or failed, invoke the isolated read-only Codex fallback and label
the result **same-provider review**. A failed call is never approval.

Review only the requested artifact and evidence. Record accepted/rejected
findings and their evidence in the owner's review log when requested or part
of the project's established process. Review does not authorize publication,
issue creation or implementation beyond the user's request.
