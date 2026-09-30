# Workflow: Session Lifecycle

Purpose: How to start a session, reflect on completed work, and hand off cleanly.

> "Work item" / "item" / "issue" here means a **bead**, managed with the beads (`bd`) CLI.
> **Scope:** globally installed reference guidance, loaded only when relevant. Beads steps apply only where .beads exists; Markdown is not an auto-loaded execution rule.

Use this file at the **beginning and end** of every session. It covers startup
orientation, self-optimization after completing work, and clean handoff. Do not
use this file for implementation details — see `workflow-execution.md` for
branching, commits, and claim/execute checklists.

> **New to beads?** Start with just two commands: `bd create "task description"` to capture work and `bd close <id>` when it's done. The full workflow below is where you'll end up, but you don't need all of it on day one.

---

## Session Startup

Run `$session-start` when a session begins work. It checks the environment and git, orients from the last handoff and bead state in a subagent, and helps pick and claim work. Don't run a separate `bd ready`/`bd list` survey on top of it.

### First-Time Setup (Optional)

Install Codex hooks for automatic context refresh:

```bash
bd prime                # Orient this Beads workspace
codex-bootstrap --doctor  # Verify native setup (read-only)
```

---

## Self-Optimization Routine

After completing significant work, analyze if patterns should be captured.

### Analyze

Review the work just completed:
- Did the user correct your approach?
- Did you discover undocumented conventions?
- Did a command need extra flags?

### Capture Follow-ups

If you identify improvements or follow-up work:

```bash
bd create "Update [file] to document [pattern]" --type feature
bd create "Add [convention] to project guidance" --type chore --labels docs
```

> bd 1.0 valid types: `bug | feature | task | epic | chore | decision`. `enhancement` is accepted as an alias for `feature`; `docs` isn't a valid type — use `--type chore --labels docs` for documentation work.

### Compare

Check against current `.md` context files (workflow files, work-item-templates, development-standards, etc.).

### Recommend

If a documentation update is warranted, propose the specific edit:
- **Proposed Change:** Exact text to add/remove/change
- **Reasoning:** How this improves future interactions
- **Risk:** Any new burden this introduces

It is perfectly acceptable to find no patterns worth capturing. Improve slowly and iteratively.

---

## Session Completion

Run `$session-wrapup` before ending a session. It verifies the build, leaves a resume note on each in-progress bead, maintains the docs, writes the handoff, and commits and pushes it all on the work branch so the next `$session-start` finds it. Create a PR only when the user asks (see `workflow-execution.md`: Pull Requests).

Mid-session, run `$session-checkpoint` to commit, push and note in-progress beads in under a minute: before stepping away, before long or risky operations, or when context is getting full. A session that ends abruptly then loses nothing but the last few minutes.

### Doc upkeep at session completion

`$session-wrapup` "Update Context Docs" maintains the `docs/*.md` context docs from the session's changed-path list. That same step also keeps the **bootstrap-era docs alive past the ideation hand-off** — they must not freeze once the brief is handed off:

- **`docs/CONTEXT.md`** (the glossary): update a term's entry whenever this session renamed or changed its meaning. A domain term is defined once, here, and referenced everywhere else.
- **`docs/adr/NNNN-*.md`**: file an ADR when a decision passes the **three-part ADR test** — (1) hard-to-reverse AND (2) surprising-without-context AND (3) the result of a real trade-off (all three required). `grill-with-docs` applies the same test when it records decisions inline.

**Decision-record overlap rule** (each artifact stays single-purpose):
- `docs/adr/` — consequential, hard-to-reverse decisions: history + rationale.
- `docs/architecture.md` "Technology Decisions" — current-state stack summary, with pointers to the ADRs behind the big calls.
- `docs/CONTEXT.md` — the glossary, and only that; other docs reference terms rather than redefining them.
