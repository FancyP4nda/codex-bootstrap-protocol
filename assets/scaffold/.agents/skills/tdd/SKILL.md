---
name: tdd
description: Test-driven development with red-green-refactor loop. Use when the user wants to build features or fix bugs using TDD, mentions red-green-refactor, wants integration tests, or asks for test-first development.
protocol_version: 1.0
origin: SCAR Labs
cognitive_tier: Foundational
---

# Test-Driven Development

## Purpose

Implement approved Beads tasks or Markdown `execution_task` artifacts through behavior-first red-green-refactor cycles.

TDD is an execution discipline, not a product planning skill. It consumes approved tasks and implements scoped behavior. Do not reshape PRD scope, project-plan task boundaries, acceptance criteria, or product decisions inside this skill.

## Philosophy

Tests should verify behavior through public interfaces, not implementation details. Code can change entirely; tests should not.

Good tests exercise real code paths through public APIs and describe what the system does. They survive refactors because they do not care about private structure.

Bad tests mock internal collaborators, test private methods, or verify behavior through unrelated internals. If a test breaks when behavior has not changed, it is probably coupled to implementation.

## Workflow Role

If a task includes workflow routing metadata, it should identify:

```yaml
workflow_artifact: execution_task
artifact_version: 1
status: execution_ready
recommended_next_skill: tdd
```

If routing metadata is missing but the Beads task or Markdown issue has a complete Agent Handoff Packet, continue. If metadata and body conflict, stop and leave a task note instead of guessing.

## Intake

If starting from a Beads task:

1. Run `bd show <id>` and read the full task description.
2. Confirm the task is execution-ready by checking for `AFK`, `Execution-ready: Yes`, or a clear source from `docs/project-plan.md`.
3. Treat approved Beads tasks as already scoped for implementation.
4. Do not claim the task until Agent Handoff Packet validation passes.

If starting from a Markdown issue file, read the issue and confirm it contains the same Agent Handoff Packet fields. If it references a Beads task, prefer the Beads task as execution state.

Map the task into the TDD loop:

- **What to build** -> Target behavior.
- **Acceptance criteria** -> Behavior checklist and red-green cycle queue.
- **Traceability** -> PRD/plan context to consult only when needed.
- **Dependencies** -> Blockers.
- **Expected public interface** -> Test entrypoint and externally visible contract.
- **Verification command** -> Command to run after each useful green/refactor checkpoint.
- **Closeout criteria** -> Conditions for closing the task.

Validate that the Agent Handoff Packet includes context to read, expected public interface, what to build, acceptance criteria, constraints, dependencies, parallelization metadata, verification command, and closeout criteria.

If the task lacks acceptance criteria, clear observable behavior, dependency status, or verification guidance, stop and add a Beads comment or issue note explaining what is missing instead of guessing.

Do not start implementation when the task is marked `HITL`, `Execution-ready: No`, `status: blocked`, or has unresolved hard dependencies.

After validation passes, claim the Beads task before implementation if it is not already claimed:

```bash
bd update <id> --claim
```

## Planning

Before writing code:

- Confirm the public interface from the task packet.
- Identify the first observable behavior to prove.
- Find the smallest relevant test command.
- Inspect only the files needed for the first tracer bullet.

Skip extra user confirmation for approved Beads tasks or Markdown issues when the Agent Handoff Packet is complete and the public interface, acceptance criteria, dependencies, and verification command are clear.

## Anti-Pattern: Horizontal Slices

Do not write all tests first, then all implementation. That treats RED as "write all tests" and GREEN as "write all code."

Correct approach: vertical tracer bullets.

```text
RED: write one failing test for one behavior
GREEN: write minimal code to pass
REFACTOR: improve design while tests stay green
REPEAT
```

## Incremental Loop

For each behavior:

1. Write one test that verifies one observable behavior through a public interface.
2. Run the smallest relevant test command and confirm it fails for the expected reason.
3. Write the minimal code needed to pass.
4. Run the same test command and confirm it passes.
5. Refactor only while green.
6. Move to the next acceptance criterion.

Rules:

- One test at a time.
- Only enough code to pass the current test.
- Do not anticipate future tests.
- Keep tests focused on observable behavior.
- Prefer integration-style tests unless the project has a clear unit-test convention for the surface being changed.

## Refactor

After all tests pass, look for natural refactor candidates:

- Remove duplication.
- Put complexity behind simple interfaces.
- Improve names where they clarify behavior.
- Preserve the project's established style.
- Run tests after each refactor step.

Never refactor while RED.

## Closeout

Before closing a Beads-backed task or Markdown issue:

1. Run the smallest relevant verification command, then the broader project check if defined.
2. Re-check every acceptance criterion from the Agent Handoff Packet.
3. If everything passes, close the task with `bd close <id>`.
4. If blocked or incomplete, leave the task open and add a concise note with the failing test, blocker, missing decision, or packet gap.

Do not close a Beads task just because code was written. Close it only when verification passes, acceptance criteria are satisfied, and closeout criteria are met.

## Checklist Per Cycle

```text
[ ] Test describes behavior, not implementation
[ ] Test uses public interface only
[ ] Test would survive internal refactor
[ ] Code is minimal for this test
[ ] No speculative features added
```
