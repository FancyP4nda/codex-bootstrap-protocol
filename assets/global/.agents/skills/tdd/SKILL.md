---
name: tdd
description: Test-first red-green-refactor loop for implementing a feature or bug fix, including a triage:ready bead. Use whenever you change behavior (the execution checklist expects it), not only when TDD is explicitly requested.
---

# Test-Driven Development

Implement the scoped behavior of a bead, or a behavior change the user asked for, test-first. This is an execution discipline, not planning: don't reshape PRD scope, task boundaries, acceptance criteria or product decisions here.

## Intake

For a bead, read it with `bd show <id>`. A `triage:ready` bead has passed the Readiness Checklist; implement only when the current request authorizes that work. The execution checklist (the [bundled execution guide](../../bootstrap/instructions/workflow-execution.md), resolved relative to this loaded skill) owns claiming; if the bead isn't `in_progress` yet, claim it (`bd update <id> --claim`) before coding.

Map the bead onto the loop:

- **Acceptance Criteria** → the queue of behaviors, one red-green cycle each.
- **Changes Needed / API Contract / Frontend Component** → the public interface the tests drive.
- **Testing Strategy** → the verification command for green and refactor checkpoints.
- **Dependencies** → don't start while a hard blocker is still open.

If something you need is genuinely missing, add a note (`bd comments add <id> "<what's missing>"`) and don't start. That means no observable acceptance criteria, an open blocker, or a `cynefin:disorder` / HITL bead. For a behavior change that isn't a bead, take the behaviors from the request.

Ask the user only if the public interface or an acceptance criterion is ambiguous.

## The loop

1. **Tracer bullet.** Write one test for the first behavior, watch it fail, then write the minimum code to pass. This proves the path end to end.
2. **Repeat per behavior, one at a time.** Write all the tests up front and you end up testing the shape you imagined rather than the behavior you actually built. Tests written one at a time respond to what the last cycle taught you.
3. **Refactor only on green.** Once everything passes, remove duplication and move complexity behind simpler interfaces, rerunning the tests after each step.

What makes a test worth keeping:

- **Test behavior through public interfaces**, the way a caller would, so tests survive refactors. If renaming an internal function breaks a test, that test was checking implementation.
- **Verify through the interface too.** Assert that a created user can be fetched with `getUser`, not by querying the users table directly.
- **Mock only at system boundaries:** external APIs, time, randomness, and sometimes the database or filesystem. Never mock your own modules. Passing boundary clients in as parameters keeps them easy to fake.
- **Prioritize.** Cover the critical paths and the complex logic; not every edge case earns a test.

## Closeout

1. Run the smallest relevant test command, then the project's broader verification command if it has one.
2. Re-check every acceptance criterion on the bead.
3. If all pass: `bd close <id>`. Otherwise leave the bead open and add a note with the failing test, blocker or missing decision (`bd comments add <id> "<note>"`).

Written code isn't the finish line. Close the bead only when the tests pass and the acceptance criteria hold.
