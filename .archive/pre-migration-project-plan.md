---
workflow_artifact: project_plan
artifact_version: 1
source_mode: existing_project
status: approved
upstream_ids: []
recommended_next_skill: plan-to-beads-unified
canonical_next_artifact: execution_task
---

# Project Plan: Codex Bootstrap Protocol

## Parent PRD

`docs/codex-bootstrap-protocol-PRD.md`

## Docs Source Of Truth

`\\wsl.localhost\Ubuntu\home\echo\ACC\codex-bootstrap-protocol\docs` is the operator-facing source-of-truth docs path. In-repo artifact links use `docs/...`; source-kit migration references use sibling paths under `../bootstrap-protocol/...`.

## Planning Assumptions

- The first implementation can be developed under `/home/echo/ACC/codex-bootstrap-protocol`, but all generated paths and scripts must be relocation-safe for a later move to `/home/echo/dev`.
- The sibling source `../bootstrap-protocol` tree remains available during implementation as migration input, not as a runtime dependency for installed projects.
- Beads (`bd`) is mandatory for real installs, but dry-run and static verification can run without Beads.
- Claude runtime compatibility is out of scope for installed targets; `.claude/` may be referenced only in migration notes, source-grounding comments, and verification fixtures.
- The initial Beads backlog has already been created from this plan. After operator review, Antigravity-authored T001/T002 implementation commits were removed from branch history and T001/T002 were reopened for fresh implementation.
- Installable scaffold assets live under `assets/scaffold/` in this builder repo. Files at the builder repo root, such as root `AGENTS.md`, root `README.md`, root `docs/`, root `.codex/`, and root `.agents/`, are builder-repo control files unless explicitly copied under `assets/scaffold/`.
- The canonical managed-path contract for installer planning is the file and directory set rooted at `assets/scaffold/`, plus Beads initialization for `.beads/`. Protected paths are always excluded from overwrite behavior: `.beads/`, `.git/`, credentials, ignored transient state, and any path outside the managed contract.
- The operator confirmed the intended GitHub identity as username `FancyP4nda` and email `zjones976@gmail.com`; the existing Beads owner/email pairing is approved for backlog fanout.

## Atomic Beads Standard

Every task intended for Beads fanout must be assignable to one subagent without requiring that subagent to coordinate unrelated implementation work. An atomic task must have one primary collision domain, one expected public interface or artifact family, explicit dependencies, testable acceptance criteria, and closeout criteria that let the assignee know when to stop. If a task spans multiple independent artifact families, changes both producer and consumer contracts without a stable boundary, or requires hidden sequencing inside the task, split it before promoting the Bead beyond backlog.

## Proof Statement

- **Repo evidence checked:** `docs/codex-bootstrap-protocol-PRD.md`, `docs/decision-brief-codex-bootstrap-protocol.md`, `docs/codex-bootstrap-protocol-PRD-review-log.md`, `.beads/issues.jsonl`, and local Beads command output showing T001/T002 reopened after Antigravity commit removal.
- **Existing domain fit:** The plan preserves the approved chain from scaffold repo to Beads execution: PRD -> project plan -> Beads backlog -> just-in-time refinement -> implementation.
- **Schema/data contract checked:** Existing Beads descriptions were compared against task IDs, dependencies, collision domains, acceptance criteria, and PRD traceability in this plan.
- **Security/privacy review points:** Installer tasks explicitly protect `.beads/`, `.git/`, credentials, ignored transient state, dry-run behavior, missing-`bd` fail-before-write behavior, and no external actions by default.
- **Dependency/order constraints:** T001 and T002 are open for fresh implementation, T002 depends on T001, T004 must precede T003, and T009 must precede T008. Existing Beads dependencies were reconciled before fanout so readiness reflects those ordering constraints.
- **Test or verification strategy:** Each task includes a verification command or a command family; T010/T012 own the broader verification suite and final acceptance evidence.
- **Official Codex surface check:** The Codex manual helper was run on June 7, 2026 and reported the local manual current. Based on that current manual snapshot, repo skills under `.agents/skills`, project-scoped `.codex/config.toml`, project-local hooks/rules trust behavior, project custom agents under `.codex/agents/`, required custom-agent fields, and `[agents].max_depth` are treated as verified platform surfaces.
- **Known unresolved assumptions:** Exact `minion` report/state fields, custom-agent TOML content, and any legacy skill merge decisions remain implementation-level decisions inside T008, T009, and T006/T007 respectively.

## Epics

### E01: Scaffold Repo and Bootstrap CLI

- **Goal:** Create a relocation-safe Codex-native scaffold repo with a first-class `./bootstrap` CLI that can preview, validate, and initialize targets safely.
- **PRD coverage:** G-001, G-002, G-005, FR-001, FR-002, FR-003, FR-005, FR-010, US-001, US-002, US-003, US-005, US-009.
- **Completion signal:** A clean checkout exposes `./bootstrap --help`, dry-run reports planned operations, real installs fail before writes without `bd`, and conflict handling protects existing repos.

### E02: Codex-Native Installed Project Surface

- **Goal:** Define and install the Codex-native target tree: repo instructions, docs, templates, config, state directories, opt-in guardrails, and durable workflow state.
- **PRD coverage:** G-002, G-006, FR-004, FR-009, NFR-001, NFR-002, C-001, C-004, C-005, C-006, US-004, US-008.
- **Completion signal:** A successful install produces the expected Codex-native file tree with no active `.claude/` runtime directory and includes documented opt-in configuration examples.

### E03: Workflow Skill and Custom Agent Rewrite

- **Goal:** Port all bundled workflow skills and delegated roles to Codex-native skill, template, docs, and custom-agent surfaces.
- **PRD coverage:** G-003, G-004, FR-006, FR-007, FR-008, AI-001, AI-002, US-006, US-007.
- **Completion signal:** Rewritten skills live under `.agents/skills/`, custom agents live under `.codex/agents/`, `session-start`, `session-wrapup`, and `minion` replace Claude command concepts, and reference scans show no live `.claude/*` runtime dependencies.

### E04: Verification, Documentation, and Release Readiness

- **Goal:** Prove the scaffold is safe, usable, documented, and ready for downstream Beads execution.
- **PRD coverage:** G-007, FR-011, M-001, M-002, M-003, R-001 through R-006, US-009.
- **Completion signal:** Syntax checks, reference scans, relocation scans, conflict tests, and disposable `/tmp` install/readback pass or clearly identify prerequisite blockers.

### E05: Interactive Bootstrap Wizard and Existing-Project Retrofit

- **Goal:** Add a human-friendly `bootstrap` wizard that preserves automation-safe non-interactive behavior while guiding operators through global skill preflight, target mode confirmation, prefix choice, plan preview, final confirmation, and non-destructive retrofit.
- **PRD coverage:** G-008, G-009, FR-012, FR-013, FR-014, FR-015, FR-016, NFR-007, NFR-008, C-007, C-008, C-009, M-004, US-010, US-011, US-012, US-013, AC-022 through AC-035.
- **Completion signal:** `./bootstrap --help` documents interactive/non-interactive modes, TTY wizard flows require confirmation before writes, global skill changes are optional and confirmed, non-TTY/CI invocations do not prompt, existing targets are handled as Non-Destructive Retrofits, and scripted verification covers prompt/no-prompt behavior.

## Tasks

### T001: Create the Codex scaffold repo shell

- **Epic:** E01
- **Type:** AFK
- **Depends on:** None
- **Execution-ready:** Yes
- **Parallel-safe:** No
- **Collision domain:** `/home/echo/ACC/codex-bootstrap-protocol`, repository initialization, top-level file layout.
- **Can run with:** None
- **Must not run with:** T002, T003, T004, T005, T006, T007, T008, T009, T010, T011, T012
- **What to build:** Create the new scaffold repo directory from the strict allowlist source material, establish its top-level structure, and add baseline metadata/docs needed for further tasks.
- **PRD traceability:** G-001, NG-001, A-001, A-003.

**Acceptance criteria**

- [ ] `/home/echo/ACC/codex-bootstrap-protocol` exists.
- [ ] The repo has a clean top-level structure for `bootstrap`, `README.md`, `AGENTS.md`, `docs/`, `.agents/`, `.codex/`, `.archive/`, and verification assets.
- [ ] The copied source material excludes active `.claude/` runtime directories from the new installed scaffold surface.
- [ ] The repo can be moved conceptually because source paths are resolved relative to the repo/script root, not hardcoded to `/home/echo/ACC`.

**Agent Handoff Packet**

- **Context to read:** `docs/codex-bootstrap-protocol-PRD.md` sections 1-3, 8, 11; `docs/decision-brief-codex-bootstrap-protocol.md`; `../bootstrap-protocol/init-project.sh`; `../bootstrap-protocol/Starting-workflow.md`.
- **Expected public interface:** A new local repository directory at `/home/echo/ACC/codex-bootstrap-protocol`.
- **What to build:** Create the repository shell and copy only source material needed for Codex transformation. Do not create installed target fixtures yet.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Do not delete or mutate `bootstrap-protocol`; do not preserve `.claude/` as a live installed surface; keep path handling relocation-safe.
- **Dependencies:** None.
- **Parallelization:** Parallel-safe: No. Collision domain: repo root and source copy. Can run with: None. Must not run with all downstream creation tasks.
- **Verification command:** `find /home/echo/ACC/codex-bootstrap-protocol -maxdepth 2 -type d -print`; `rg -n "/home/echo/ACC|\\.claude" bootstrap README.md AGENTS.md .agents .codex verification --glob "!**/__pycache__/**"`; document any expected matches that are source/migration notes rather than installed runtime dependencies.
- **Closeout criteria:** Repo shell exists, source copy choices are documented, and follow-ups are filed for any unclear legacy asset.

### T002: Implement the `./bootstrap` CLI skeleton

- **Epic:** E01
- **Type:** AFK
- **Depends on:** T001
- **Execution-ready:** Yes
- **Parallel-safe:** Yes
- **Collision domain:** `bootstrap`, CLI argument parsing, help text, command validation.
- **Can run with:** T004, T005, T006, T010
- **Must not run with:** T003
- **What to build:** Implement the repo-root `bootstrap` executable with `--help`, positional target parsing, `--prefix`, `--dry-run`, and `--force` flags.
- **PRD traceability:** FR-001, FR-002, US-001, US-002, AC-001, AC-002, AC-003, AC-004.

**Acceptance criteria**

- [ ] `./bootstrap --help` documents required arguments, `--prefix`, `--dry-run`, and `--force`.
- [ ] `./bootstrap --dry-run <target> --prefix <PREFIX>` parses successfully without requiring `bd`.
- [ ] The CLI resolves its source directory relative to the executable path.
- [ ] Documentation describes optional symlink/PATH setup without performing it.

**Agent Handoff Packet**

- **Context to read:** PRD FR-001, FR-002, US-001, US-002; existing `../bootstrap-protocol/init-project.sh` argument parsing.
- **Expected public interface:** `./bootstrap <target> --prefix <PREFIX>` and `./bootstrap --dry-run <target> --prefix <PREFIX>`.
- **What to build:** A shell CLI skeleton that validates arguments, prints help, and delegates planned install work to internal functions.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** No PATH mutation; no package install; no writes during dry-run.
- **Dependencies:** T001.
- **Parallelization:** Parallel-safe: Yes after T001. Collision domain: `bootstrap`. Can run with T004, T005, T006, T010. Must not run with T003 because both touch install execution wiring.
- **Verification command:** `bash -n ./bootstrap`; `./bootstrap --help`; `./bootstrap --dry-run /tmp/codex-bootstrap-smoke --prefix CBS`.
- **Closeout criteria:** CLI skeleton works, syntax passes, and unresolved parser behavior is documented.

### T003: Add prerequisite, dry-run, conflict, and Beads install flow

- **Epic:** E01
- **Type:** AFK
- **Depends on:** T002, T004
- **Execution-ready:** Yes
- **Parallel-safe:** No
- **Collision domain:** `bootstrap`, install planning logic, conflict detection, Beads initialization.
- **Can run with:** None
- **Must not run with:** T002, T004
- **What to build:** Complete installer control flow against the `assets/scaffold/` managed-path contract: dry-run planning, mandatory `bd` checks, fail-before-write behavior, conflict reporting, `--force` semantics, and Beads initialization/validation.
- **PRD traceability:** FR-002, FR-003, FR-005, M-003, US-002, US-003, US-005, AC-004 through AC-011.

**Acceptance criteria**

- [ ] Dry-run lists created paths, skipped paths, and conflicts without writes.
- [ ] Missing `bd` causes non-zero exit before target writes for real installs.
- [ ] Existing managed-path conflicts stop before writes by default.
- [ ] Conflict report includes path, planned action, reason, and suggested resolution.
- [ ] `--force` may overwrite managed scaffold files only and never overwrites `.beads/`, `.git/`, credentials, or ignored transient state.
- [ ] Existing `.beads/` is validated rather than replaced.

**Agent Handoff Packet**

- **Context to read:** PRD FR-002, FR-003, FR-005; T004 output under `assets/scaffold/`; `../bootstrap-protocol/init-project.sh` validation and `bd init` sections.
- **Expected public interface:** CLI install behavior and operator-facing diagnostics.
- **What to build:** Installer planning and safety gates around writes, conflicts, Beads, force behavior, and the canonical managed paths under `assets/scaffold/`.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Beads mandatory; dry-run does not require Beads; fail before partial writes; no destructive operations against protected paths.
- **Dependencies:** T002, T004.
- **Parallelization:** Parallel-safe: No. Collision domain: core CLI control flow. Can run with None. Must not run with T002 and T004.
- **Verification command:** `bash -n ./bootstrap`; `./bootstrap --dry-run /tmp/codex-bootstrap-smoke --prefix CBS`; run a missing-`bd` simulation if practical by invoking with a constrained `PATH`.
- **Closeout criteria:** Safety behavior is verified and documented with example outputs or commands.

### T004: Build the Codex-native install asset tree

- **Epic:** E02
- **Type:** AFK
- **Depends on:** T001
- **Execution-ready:** Yes
- **Parallel-safe:** Yes
- **Collision domain:** `assets/scaffold/`, including installable `AGENTS.md`, `.agents/templates/`, docs stubs, `.codex/` examples, `.gitignore`, and state-directory placeholders.
- **Can run with:** T002, T005, T006, T010
- **Must not run with:** T003
- **What to build:** Create the files and directories under `assets/scaffold/` that `bootstrap` installs into target repos: Codex instructions, docs stubs, templates, minimal config, opt-in hook/rule examples, state directories, and ignore rules.
- **PRD traceability:** FR-004, FR-009, NFR-001, NFR-002, C-005, C-006, US-004, US-008, AC-008, AC-009, AC-018.

**Acceptance criteria**

- [ ] Scaffold assets include `AGENTS.md`, `docs/CONTEXT.md`, `docs/adr/`, `docs/prd.md`, `docs/project-plan.md`, `docs/architecture.md`, `docs/backend.md`, `docs/frontend.md`, `docs/data-model.md`, `docs/security.md`, `docs/handoff.yaml`, `docs/changelog.yaml`, `docs/enhancements.md`, `docs/standards-history.md`, `.agents/templates/`, `.codex/config.toml`, `.codex/hooks/`, `.codex/rules/`, `.codex/state/tmp/`, `.archive/`.
- [ ] `.codex/config.toml` stays minimal and does not set model, provider, auth, telemetry, network, sandbox, or auto-approval defaults.
- [ ] Transient `.codex/state/tmp/` is gitignored.
- [ ] No install asset creates active `.claude/` runtime directories.
- [ ] `assets/scaffold/manifest.txt` or equivalent records the canonical managed-path list consumed by T003 and T011.

**Agent Handoff Packet**

- **Context to read:** PRD FR-004, FR-009, C-005, C-006; Decision Brief target tree; Codex manual excerpts already captured in the session notes if available.
- **Expected public interface:** Installed target file tree and docs/config surfaces.
- **What to build:** Asset tree under `assets/scaffold/` used by the installer for Codex-native target projects.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Hooks/rules are examples only by default; durable state under `docs/`; transient state under `.codex/state/tmp/`.
- **Dependencies:** T001.
- **Parallelization:** Parallel-safe: Yes. Collision domain: asset tree. Can run with T002, T005, T006, T010. Must not run with T003 due install path integration.
- **Verification command:** `find assets/scaffold -maxdepth 4 -type f -print`; `rg -n "model_provider|openai_base_url|sandbox_mode|approval_policy|\\.claude" assets/scaffold`.
- **Closeout criteria:** `assets/scaffold/` exists, the managed-path manifest exists, the verification commands above run, and installer integration notes identify any manifest fields T003/T011 must consume.

### T005: Write operator documentation and opt-in config guide

- **Epic:** E02
- **Type:** AFK
- **Depends on:** T001
- **Execution-ready:** Yes
- **Parallel-safe:** Yes
- **Collision domain:** `README.md`, `docs/opt-in-configs.md`, docs examples.
- **Can run with:** T002, T004, T006, T007, T010
- **Must not run with:** None
- **What to build:** Document scaffold purpose, `./bootstrap` usage, optional symlink/PATH setup, Beads prerequisite, install safety behavior, opt-in configs, and relocation expectations.
- **PRD traceability:** FR-001, FR-003, FR-009, FR-010, NFR-005, US-001, US-003, US-008, AC-003, AC-007, AC-018, AC-019.

**Acceptance criteria**

- [ ] `README.md` explains Codex-native-only scope, primary `./bootstrap` usage, dry-run, force behavior, and Beads prerequisite.
- [ ] `docs/opt-in-configs.md` covers hooks, rules, custom subagents, `minion` settings, stricter approval/sandbox profiles, and any memory or automation examples shipped.
- [ ] Each opt-in config entry includes purpose, risk level, enable steps, disable steps, and verification.
- [ ] Docs explain optional PATH/symlink setup without performing it.
- [ ] Docs state the repo is relocation-safe and should not rely on `/home/echo/ACC` after move.

**Agent Handoff Packet**

- **Context to read:** PRD FR-009, NFR-005, R-003, R-004, R-005, R-006; Decision Brief resolved decisions.
- **Expected public interface:** Human-readable Markdown docs.
- **What to build:** Operator-facing docs and opt-in config guide.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Keep docs actionable, WSL-friendly, and explicit about no auto installs/network actions.
- **Dependencies:** T001.
- **Parallelization:** Parallel-safe: Yes. Collision domain: docs. Can run with T002, T004, T006, T007, T010. Must not run with None.
- **Verification command:** `rg -n "bootstrap|bd|opt-in|enable|disable|verify|/home/echo/ACC" README.md docs/opt-in-configs.md`.
- **Closeout criteria:** README and `docs/opt-in-configs.md` contain the required sections, the verification grep returns expected matches for bootstrap/Beads/opt-in terms, and any `/home/echo/ACC` examples are explicitly marked as examples rather than runtime dependencies.

### T006: Port planning-chain workflow skills to `.agents/skills`

- **Epic:** E03
- **Type:** AFK
- **Depends on:** T001, T004
- **Execution-ready:** Yes
- **Parallel-safe:** Yes
- **Collision domain:** `.agents/skills/brainstormer`, `.agents/skills/grill-with-docs`, `.agents/skills/product-architect`, `.agents/skills/project-planner`, `.agents/skills/plan-to-beads-unified`, `.agents/skills/tdd`, `.agents/templates/`.
- **Can run with:** T005, T007, T008, T010
- **Must not run with:** None after T001 and T004
- **What to build:** Rewrite the core planning-to-execution skills for Codex-native paths, especially `.agents/templates/`, `docs/CONTEXT.md`, `docs/adr/`, `docs/prd.md`, and `docs/project-plan.md`.
- **PRD traceability:** FR-006, FR-007, AI-001, US-006, AC-012, AC-013.

**Acceptance criteria**

- [ ] Core planning-chain skills exist under `.agents/skills/`.
- [ ] `grill-with-docs` uses `docs/CONTEXT.md` as canonical glossary path.
- [ ] Artifact templates resolve under `.agents/templates/`.
- [ ] Skill instructions do not refer to `.claude/*` as live runtime paths; any `.claude` references are explicitly marked as source-kit migration context.
- [ ] Workflow frontmatter/routing contracts are preserved where applicable.

**Agent Handoff Packet**

- **Context to read:** PRD FR-006, FR-007; source skills in `../bootstrap-protocol/.claude/skills/`; `../bootstrap-protocol/.claude/templates/artifacts/*`; current `docs/codex-bootstrap-protocol-PRD.md`.
- **Expected public interface:** Codex skills discoverable from `.agents/skills`.
- **What to build:** Codex-native rewrites of the planning-chain skills and their template references.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Preserve stable skill names; do not convert skills into deprecated custom prompts; do not write Beads items in planner skills.
- **Dependencies:** T001, T004.
- **Parallelization:** Parallel-safe: Yes after T004. Collision domain: planning-chain skills. Can run with T005, T007, T008, T010. Must not run with None after T001 and T004.
- **Verification command:** `rg -n "\\.claude|CONTEXT.md|\\.agents/templates|docs/CONTEXT.md" .agents/skills`; review any `.claude` matches and allow only source-kit migration references, not live runtime dependencies.
- **Closeout criteria:** Every required skill has a `SKILL.md` with `name` and `description`, template references resolve to `.agents/templates/`, and the reference scan shows no live Claude runtime paths.

### T007: Create `session-start` and `session-wrapup` skills

- **Epic:** E03
- **Type:** AFK
- **Depends on:** T004, T006
- **Execution-ready:** Yes
- **Parallel-safe:** Yes
- **Collision domain:** `.agents/skills/session-start`, `.agents/skills/session-wrapup`, docs state schemas, `docs/handoff.yaml`, `docs/changelog.yaml`.
- **Can run with:** T005, T008, T009, T010
- **Must not run with:** None
- **What to build:** Rewrite `/leroy` and `/wrapup` behavior as Codex skills using `docs/handoff.yaml`, `docs/changelog.yaml`, Beads, Codex custom agents, and docs paths.
- **PRD traceability:** FR-006, FR-007, AI-001, US-006, AC-014.

**Acceptance criteria**

- [ ] `session-start` skill replaces `/leroy` with Codex-native startup/orientation behavior.
- [ ] `session-wrapup` skill replaces `/wrapup` with Codex-native closeout behavior.
- [ ] Both skills use `docs/handoff.yaml` and `docs/changelog.yaml`, not `.claude/handoff.yaml` or `.claude/changelog.yaml`.
- [ ] Both skills degrade clearly if expected docs or Beads state are missing.
- [ ] Neither skill performs external publication actions by default.

**Agent Handoff Packet**

- **Context to read:** PRD FR-006, FR-007, NFR-001, NFR-002; source files `../bootstrap-protocol/.claude/commands/leroy.md`, `../bootstrap-protocol/.claude/commands/wrapup.md`, navigator source agents.
- **Expected public interface:** `$session-start` and `$session-wrapup` Codex skill invocations.
- **What to build:** Codex skill rewrites for session orientation and closeout.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Do not rely on Claude session IDs, Claude transcript paths, TaskCreate/TaskUpdate, or Claude-only command syntax.
- **Dependencies:** T004, T006.
- **Parallelization:** Parallel-safe: Yes. Collision domain: session skills and state docs. Can run with T005, T008, T009, T010. Must not run with None.
- **Verification command:** `rg -n "claude|/leroy|/wrapup|\\.claude|handoff.yaml|changelog.yaml" .agents/skills/session-start .agents/skills/session-wrapup`.
- **Closeout criteria:** `session-start/SKILL.md` and `session-wrapup/SKILL.md` exist, both reference `docs/handoff.yaml` and `docs/changelog.yaml`, the verification scan has no live Claude runtime dependency, and each skill includes a short smoke-prompt example for an initialized target.

### T008: Design and implement `minion` fanout

- **Epic:** E03
- **Type:** AFK
- **Depends on:** T004, T009
- **Execution-ready:** Yes
- **Parallel-safe:** Yes
- **Collision domain:** `.agents/skills/minion`, `.codex/state/tmp/minion-*`, minion report schema docs.
- **Can run with:** T006, T007, T010
- **Must not run with:** T009
- **What to build:** Create the Codex-native `minion` skill for explicit subagent fanout with report-only and guarded execution modes, default 6-way fanout, a hard cap of 6 workers, warnings for execution fanout, disjoint write-scope requirements, and references to the worker agent owned by T009.
- **PRD traceability:** FR-008, R-004, AI-001, US-007, AC-015, AC-016, AC-017.

**Acceptance criteria**

- [ ] `minion` skill exists under `.agents/skills/minion`.
- [ ] `minion` defaults to 6-way fanout when no count is specified.
- [ ] `minion` caps fanout at 6 workers and warns that practical limits are subject to Codex runtime/account/environment constraints.
- [ ] Execution fanout is allowed only with disjoint write scopes, steering-session integration, and file-scope plus collision-domain planning.
- [ ] `minion` explicitly defers locks, cron/watch, auto-amend, auto-ack, cross-branch orchestration, and PR actions.
- [ ] Transient report path convention is documented under `.codex/state/tmp/minion-*`.
- [ ] `minion` references a scoped worker custom agent but does not create or edit `.codex/agents/worker.toml`.

**Agent Handoff Packet**

- **Context to read:** PRD FR-008, R-004, AI-001; source Falcon files under `../bootstrap-protocol/.claude/skills/falcon/` only as conceptual input; official Codex subagent documentation cited in the PRD.
- **Expected public interface:** `$minion` Codex skill invocation, structured report summaries, and execution worker summaries.
- **What to build:** Codex subagent fanout workflow and report/execution state contract. Do not create custom-agent TOML files in this task.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Do not invoke Claude commands; do not implement background cron/watch; do not create PRs; keep transient state gitignored.
- **Dependencies:** T004, T009.
- **Parallelization:** Parallel-safe: Yes. Collision domain: minion skill and report schema. Can run with T006, T007, T010. Must not run with T009 because T009 owns `.codex/agents/worker.toml`.
- **Verification command:** `rg -n "auto-amend|auto-ack|cron|PR actions|default 6|cap.*6|execution mode|disjoint write" .agents/skills/minion .codex/agents docs`; expected matches must show autonomous behaviors as deferred and executable fanout as capped, scoped, and parent-coordinated.
- **Closeout criteria:** `minion/SKILL.md` and the report schema doc exist, prohibited autonomous behaviors appear only as deferred-scope statements, and sample report-only plus execution prompt/readback fixtures are included.

### T009: Add Codex custom agents for delegated roles

- **Epic:** E03
- **Type:** AFK
- **Depends on:** T004
- **Execution-ready:** Yes
- **Parallel-safe:** Yes
- **Collision domain:** `.codex/agents/*.toml`, agent role docs, references from session/minion skills.
- **Can run with:** T007, T010
- **Must not run with:** T008
- **What to build:** Add project-scoped custom agent TOML files for repeatable delegated roles such as `navigator`, `reviewer`, scoped `worker`, and optional `scribe`. This task owns `.codex/agents/worker.toml`.
- **PRD traceability:** FR-006, FR-008, AI-001, Q-003.

**Acceptance criteria**

- [ ] `.codex/agents/navigator.toml` exists with `name`, `description`, and `developer_instructions`.
- [ ] `.codex/agents/reviewer.toml` exists with correctness/security/test-gap review instructions.
- [ ] `.codex/agents/worker.toml` or equivalent exists for `minion` report-only review/research workers and guarded execution workers.
- [ ] Optional `scribe` role is included only if session-wrapup delegates doc maintenance.
- [ ] Agent files avoid model/provider/auth assumptions unless explicitly needed and documented.

**Agent Handoff Packet**

- **Context to read:** PRD AI-001, FR-008, Q-003; Decision Brief custom-agent split; official Codex custom-agent documentation cited in the PRD; source navigator/scribe/quartermaster/herald agents under `../bootstrap-protocol/.claude/agents/`.
- **Expected public interface:** Codex custom agents available to spawned subagent workflows.
- **What to build:** Narrow TOML custom-agent role definitions, with any `worker` role constrained to explicit minion modes, assigned write scopes, and steering-session integration.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Include required TOML fields; avoid setting model/provider/auth defaults; keep roles narrow.
- **Dependencies:** T004.
- **Parallelization:** Parallel-safe: Yes. Collision domain: `.codex/agents`. Can run with T007, T010. Must not run with T008 because T009 owns `worker.toml` consumed by `minion`.
- **Verification command:** `rg -n "name =|description =|developer_instructions|model_provider|openai_base_url" .codex/agents`; `python3 -c "import pathlib, tomllib; [tomllib.load(open(p, 'rb')) for p in pathlib.Path('.codex/agents').glob('*.toml')]"`.
- **Closeout criteria:** Required TOML files parse, each has `name`, `description`, and `developer_instructions`, prohibited provider/auth keys are absent, and relevant skills reference the agent names they consume.

### T010: Add verification scripts and scans

- **Epic:** E04
- **Type:** AFK
- **Depends on:** T001, T002
- **Execution-ready:** Yes
- **Parallel-safe:** Yes
- **Collision domain:** verification scripts/docs, test fixtures, scan commands.
- **Can run with:** T002, T004, T005, T006, T007, T008, T009
- **Must not run with:** T012
- **What to build:** Add documented verification commands or helper scripts for shell syntax, `.claude` runtime references, relocation safety, protected-path checks, and `/tmp` install/readback. T010 authors the command suite; T012 validates final behavior after installer integration.
- **PRD traceability:** FR-010, FR-011, M-001, M-002, M-003, US-009, AC-019, AC-020, AC-021.

**Acceptance criteria**

- [ ] Verification includes `bash -n` for `bootstrap` and shell helpers.
- [ ] Verification scans for live `.claude/*` runtime dependencies in installed Codex runtime assets, with documented allowlists for migration/source references.
- [ ] Verification scans for hardcoded `/home/echo/ACC` runtime dependencies outside allowed examples, migration notes, `.archive/`, and review logs.
- [ ] Verification documents a disposable `/tmp` install/readback.
- [ ] Verification includes commands or fixtures for conflict behavior and missing-`bd` behavior; final behavioral pass/fail execution is owned by T012 after T003/T011.

**Agent Handoff Packet**

- **Context to read:** PRD FR-010, FR-011, M-001 through M-003, AC-019 through AC-021.
- **Expected public interface:** `README.md` or script-documented verification commands.
- **What to build:** Static and behavioral verification surface for maintainers.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Do not require network; do not destructively remove user directories; use `/tmp` target names that are clearly test-created.
- **Dependencies:** T001, T002.
- **Parallelization:** Parallel-safe: Yes. Collision domain: verification docs/scripts. Can run with most implementation tasks. Must not run with T012.
- **Verification command:** Run static verification commands that are valid at T010 time; document any behavior commands deferred to T012 with exact prerequisites.
- **Closeout criteria:** Verification docs/scripts identify runnable T010-time checks, deferred T012 behavior checks, exact prerequisites, and expected pass/fail outputs.

### T011: Integrate installer with final asset tree and docs

- **Epic:** E01
- **Type:** AFK
- **Depends on:** T003, T004, T005
- **Execution-ready:** Yes
- **Parallel-safe:** No
- **Collision domain:** `bootstrap`, asset root, README examples, install readback expectations.
- **Can run with:** None
- **Must not run with:** T003, T004, T005, T012
- **What to build:** Connect the CLI install planner to the finalized asset tree and documentation so real installs create exactly the expected files and report accurate instructions.
- **PRD traceability:** FR-001 through FR-005, FR-009, US-001 through US-005, US-008.

**Acceptance criteria**

- [ ] `./bootstrap --dry-run <target> --prefix <PREFIX>` reports the final asset tree accurately.
- [ ] `./bootstrap <target> --prefix <PREFIX>` creates the final asset tree when prerequisites are met.
- [ ] Installer summary points to `AGENTS.md`, `docs/opt-in-configs.md`, Beads status, and next workflow skills.
- [ ] README examples match actual CLI behavior.
- [ ] No install summary points users to `/leroy`, `/wrapup`, `/falcon`, or `.claude/`.

**Agent Handoff Packet**

- **Context to read:** T003 output, T004 asset root, T005 docs, PRD AC-001 through AC-018.
- **Expected public interface:** Final install behavior of `./bootstrap`.
- **What to build:** End-to-end integration between installer, assets, and docs.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Preserve fail-before-write behavior; do not overwrite protected paths; keep dry-run write-free.
- **Dependencies:** T003, T004, T005.
- **Parallelization:** Parallel-safe: No. Collision domain: integrated install behavior. Can run with None. Must not run with T003, T004, T005, T012.
- **Verification command:** `./bootstrap --dry-run /tmp/codex-bootstrap-smoke --prefix CBS`; real install command when `bd` is available.
- **Closeout criteria:** Dry-run output, README examples, and installer summary use the same CLI flags and managed-path names; `rg -n "/leroy|/wrapup|/falcon|\\.claude" bootstrap README.md docs` has no live-runtime matches outside migration notes; any mismatch is filed as a Beads follow-up.

### T012: Run final acceptance validation and fix gaps

- **Epic:** E04
- **Type:** AFK
- **Depends on:** T006, T007, T008, T009, T010, T011
- **Execution-ready:** Yes
- **Parallel-safe:** No
- **Collision domain:** Whole repo, final verification, `/tmp` disposable target.
- **Can run with:** None
- **Must not run with:** All implementation tasks
- **What to build:** Run the full verification suite, perform disposable `/tmp` install/readback when prerequisites are available, and patch any acceptance gaps found.
- **PRD traceability:** All Must-priority FRs, AC-001 through AC-021, M-001 through M-003.

**Acceptance criteria**

- [ ] Shell syntax checks pass.
- [ ] Reference scans show no live `.claude/*` runtime dependencies in installed Codex runtime assets, with documented allowlists for migration/source references.
- [ ] Relocation scan reports no hardcoded `/home/echo/ACC` runtime dependency outside allowed examples, migration notes, `.archive/`, and review logs.
- [ ] Dry-run output matches expected file plan.
- [ ] Missing-`bd` behavior fails before writes.
- [ ] Disposable `/tmp` install/readback confirms the expected tree when `bd` is available.
- [ ] Any skipped validation is explained with the exact command to run after prerequisites are met.

**Agent Handoff Packet**

- **Context to read:** Full PRD; this project plan; verification docs/scripts; `./bootstrap --help`.
- **Expected public interface:** Final acceptance evidence for the scaffold repo.
- **What to build:** Execute validation, fix discovered gaps, and leave a concise verification record.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Do not delete unrelated `/tmp` or workspace content; only clean clearly test-created directories when safe; do not perform external actions.
- **Dependencies:** T006, T007, T008, T009, T010, T011.
- **Parallelization:** Parallel-safe: No. Collision domain: entire repo and final acceptance state. Can run with None. Must not run with all implementation tasks.
- **Verification command:** The finalized verification command set from T010, plus `./bootstrap --dry-run /tmp/codex-bootstrap-smoke --prefix CBS` and a real `/tmp` install when `bd` is available.
- **Closeout criteria:** Acceptance evidence is recorded, blockers are explicit, and the plan is ready for `plan-to-beads-unified`.

### T013: Add interactive and non-interactive mode contract

- **Epic:** E05
- **Type:** AFK
- **Depends on:** T011
- **Execution-ready:** Yes
- **Parallel-safe:** No
- **Collision domain:** `bootstrap`, CLI argument parsing, help text, TTY/CI mode detection.
- **Can run with:** None
- **Must not run with:** T014, T015, T016, T018
- **What to build:** Extend `bootstrap` with explicit `--interactive` and `--non-interactive` flags, TTY/CI mode selection, and a no-prompt contract that preserves existing automation-safe behavior.
- **PRD traceability:** FR-012, FR-014, NFR-007, US-010, US-012, AC-022, AC-023, AC-030, AC-031.

**Acceptance criteria**

- [ ] `./bootstrap --help` documents `--interactive` and `--non-interactive`.
- [ ] `./bootstrap --non-interactive <target> --prefix <PREFIX>` does not prompt and preserves current validation/install behavior.
- [ ] CI or non-TTY invocation defaults to non-interactive behavior and exits instead of waiting for input when required inputs are missing.
- [ ] TTY invocation without required choices routes into interactive mode.
- [ ] Conflicting mode flags fail with an actionable error before writes.

**Agent Handoff Packet**

- **Context to read:** PRD FR-012, FR-014, NFR-007, US-010, US-012, AC-022, AC-023, AC-030, AC-031; `bootstrap`; `README.md`; `docs/decision-brief-bootstrap-interactive-wizard.md`.
- **Expected public interface:** `./bootstrap --interactive`, `./bootstrap --non-interactive <target> --prefix <PREFIX>`, and existing `./bootstrap <target> --prefix <PREFIX>` behavior.
- **What to build:** CLI mode parsing, help text, TTY/CI mode detection, and no-prompt behavior for non-interactive paths.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Preserve dry-run write-free behavior; do not add global skill writes in this task; do not implement optional flags beyond `--interactive` and `--non-interactive`.
- **Dependencies:** T011 completed; existing installer behavior must be stable.
- **Parallelization:** Parallel-safe: No. Collision domain: `bootstrap` parser and mode selection. Can run with: None. Must not run with T014, T015, T016, T018.
- **Verification command:** `bash -n ./bootstrap`; `./bootstrap --help`; `./bootstrap --non-interactive --dry-run /tmp/codex-bootstrap-smoke --prefix CBS`; `CI=1 ./bootstrap --dry-run /tmp/codex-bootstrap-smoke --prefix CBS`.
- **Closeout criteria:** Mode contract is documented in help output, parser behavior is verified, Beads task is updated, and follow-ups are filed for any prompt behavior that needs terminal-specific testing.

### T014: Add recommended global skill preflight

- **Epic:** E05
- **Type:** AFK
- **Depends on:** T013
- **Execution-ready:** Yes
- **Parallel-safe:** No
- **Collision domain:** `bootstrap`, `assets/scaffold/.agents/skills/`, global skill comparison/copy logic.
- **Can run with:** T017
- **Must not run with:** T013, T015, T016, T018
- **What to build:** In interactive mode, check the recommended global skills before target mode selection, report missing/outdated/current state, and optionally install or update from scaffold-owned source files after confirmation.
- **PRD traceability:** FR-013, C-007, C-009, US-011, AC-026, AC-027, AC-028, AC-029, A-005, A-006, R-008.

**Acceptance criteria**

- [ ] Recommended global skill set is exactly `brainstormer`, `grill-with-docs`, `product-architect`, `project-planner`, `plan-to-beads-unified`, `tdd`, and `minion`.
- [ ] `session-start` and `session-wrapup` are not included in the recommended global skill set.
- [ ] Missing global skills can be installed from `assets/scaffold/.agents/skills/<name>` only after confirmation.
- [ ] Outdated global skills can be updated by scaffold-owned file comparison only after confirmation.
- [ ] Destination-only extra files in global skill directories are preserved unless they directly conflict with scaffold-owned files.
- [ ] Non-interactive mode does not perform global skill prompts or writes.

**Agent Handoff Packet**

- **Context to read:** PRD FR-013, C-007, C-009, US-011, AC-026 through AC-029; `docs/CONTEXT.md`; `docs/decision-brief-bootstrap-interactive-wizard.md`; `assets/scaffold/.agents/skills/`; `bootstrap`.
- **Expected public interface:** Interactive `bootstrap` global skill preflight prompt and report.
- **What to build:** Global skill status detection, confirmed install/update behavior, destination-extra preservation, and no-op behavior in non-interactive mode.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** No network calls; no package installs; no global writes without confirmation; target-local skills remain installed through the managed scaffold contract even when global updates are skipped.
- **Dependencies:** T013 mode contract.
- **Parallelization:** Parallel-safe: No for `bootstrap`; can run with T017 if documentation uses the accepted public interface. Collision domain: `bootstrap` global skill logic. Must not run with T013, T015, T016, T018.
- **Verification command:** `bash -n ./bootstrap`; run an interactive-path smoke test with a temporary `HOME` when practical; `rg -n "brainstormer|session-start|session-wrapup|\\.agents/skills" bootstrap`.
- **Closeout criteria:** Global preflight behavior is verified with a temp-home or documented manual prompt test, no unconfirmed global writes occur, task is updated, and any machine-specific verification gaps are filed.

### T015: Add target mode detection, prefix suggestion, and final confirmation

- **Epic:** E05
- **Type:** AFK
- **Depends on:** T013
- **Execution-ready:** Yes
- **Parallel-safe:** No
- **Collision domain:** `bootstrap`, interactive prompt flow, target classification, prefix derivation, plan preview.
- **Can run with:** T017
- **Must not run with:** T013, T014, T016, T018
- **What to build:** Add the interactive target workflow: detect new versus existing target, ask for confirmation, suggest a prefix from the target basename, allow override, print the existing dry-run-style plan, and require final confirmation before writes.
- **PRD traceability:** FR-012, FR-015, NFR-008, US-010, US-013, AC-023, AC-024, AC-025, AC-032, R-009, R-010.

**Acceptance criteria**

- [ ] Interactive mode identifies a missing or empty target as a new project before writes.
- [ ] Interactive mode identifies a non-empty target as an existing-project retrofit before writes and asks for confirmation.
- [ ] Interactive mode suggests a default prefix from the target directory name and allows override.
- [ ] Interactive mode prints a dry-run-style plan before writing.
- [ ] Interactive mode requires final confirmation before target writes.
- [ ] Declining target mode confirmation or final confirmation exits without target writes.

**Agent Handoff Packet**

- **Context to read:** PRD FR-012, FR-015, US-010, US-013, AC-023 through AC-025, AC-032; `bootstrap` functions `plan_install`, `print_plan_report`, and `print_install_summary`; `docs/decision-brief-bootstrap-interactive-wizard.md`.
- **Expected public interface:** Interactive prompts for target path, target mode, prefix, plan preview, and final confirmation.
- **What to build:** Prompt flow that reuses existing planning/report functions and gates writes on explicit confirmation.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Keep prefix suggestion deterministic and previewed; do not add per-file merge prompts; preserve non-interactive no-prompt behavior from T013.
- **Dependencies:** T013 mode contract.
- **Parallelization:** Parallel-safe: No for `bootstrap`; can run with T017 if documentation uses the accepted public interface. Collision domain: interactive prompt flow. Must not run with T013, T014, T016, T018.
- **Verification command:** `bash -n ./bootstrap`; use a pseudo-TTY/manual smoke test for `./bootstrap --interactive`; verify declined confirmation leaves no files in a clearly test-created `/tmp` target.
- **Closeout criteria:** Prompt flow is verified, prefix suggestion and override are documented by output or notes, and any terminal automation limitation is captured as a follow-up.

### T016: Implement non-destructive retrofit completion behavior

- **Epic:** E05
- **Type:** AFK
- **Depends on:** T015
- **Execution-ready:** Yes
- **Parallel-safe:** No
- **Collision domain:** `bootstrap`, existing-target retrofit behavior, `docs/changelog.yaml` or completion-note writes in target projects.
- **Can run with:** T017
- **Must not run with:** T013, T014, T015, T018
- **What to build:** Complete the existing-project retrofit path by validating existing `.beads/`, preserving protected/unmanaged paths, keeping all conflicts all-or-nothing for v1, and writing a lightweight project-local completion note after successful install or retrofit.
- **PRD traceability:** FR-015, FR-016, C-008, US-013, AC-033, AC-034, AC-035, Q-007, R-010.

**Acceptance criteria**

- [ ] Existing `.beads/` is validated instead of replaced during retrofit.
- [ ] `.git/`, `.beads/`, credentials, symlinks, transient state contents, and unmanaged files are not overwritten.
- [ ] Existing-project conflicts remain all-or-nothing for v1; per-file merge prompts are not offered.
- [ ] `--force` remains limited to managed scaffold files.
- [ ] Successful install or retrofit writes a lightweight completion note into target project docs.
- [ ] Completion note does not store private global machine details.

**Agent Handoff Packet**

- **Context to read:** PRD FR-015, FR-016, C-008, US-013, AC-033 through AC-035; `docs/CONTEXT.md` Non-Destructive Retrofit and Managed Scaffold Contract definitions; `assets/scaffold/docs/changelog.yaml`; `bootstrap`.
- **Expected public interface:** Existing-project retrofit behavior and target-local completion note.
- **What to build:** Retrofit validation and completion-note behavior that reuses the managed scaffold contract without broad migration semantics.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** No per-file merge prompts in v1; no private global machine details in target docs; no destructive operations against protected paths.
- **Dependencies:** T015 target mode and final confirmation.
- **Parallelization:** Parallel-safe: No for `bootstrap`; can run with T017 if documentation uses the accepted public interface. Collision domain: retrofit behavior and target-doc writes. Must not run with T013, T014, T015, T018.
- **Verification command:** `bash -n ./bootstrap`; create a clearly test-created non-empty `/tmp` target and verify dry-run/retrofit behavior; inspect target `docs/changelog.yaml` or completion note after success.
- **Closeout criteria:** Retrofit behavior is proven against a non-empty `/tmp` target, protected-path behavior is verified or documented with exact commands, task is updated, and any schema concerns are filed.

### T017: Document the interactive bootstrap workflow

- **Epic:** E05
- **Type:** AFK
- **Depends on:** T013
- **Execution-ready:** Yes
- **Parallel-safe:** Yes
- **Collision domain:** `README.md`, `docs/opt-in-configs.md`, wizard examples, operator docs.
- **Can run with:** T014, T015, T016
- **Must not run with:** None
- **What to build:** Update operator documentation for interactive mode, non-interactive automation, global skill preflight, existing-project retrofit, prefix prompts, and completion-note behavior.
- **PRD traceability:** FR-012, FR-013, FR-014, FR-015, FR-016, NFR-005, US-010 through US-013, AC-022 through AC-035.

**Acceptance criteria**

- [ ] README documents `--interactive` and `--non-interactive`.
- [ ] README explains when TTY mode enters the wizard and when CI/non-TTY mode stays non-interactive.
- [ ] Docs explain recommended global skill preflight, optional install/update behavior, and skipped global updates.
- [ ] Docs explain Non-Destructive Retrofit for existing projects and all-or-nothing conflict handling.
- [ ] Docs describe prefix suggestion/override and completion-note behavior.
- [ ] Documentation does not claim target projects depend on global skills.

**Agent Handoff Packet**

- **Context to read:** PRD US-010 through US-013, AC-022 through AC-035; `docs/decision-brief-bootstrap-interactive-wizard.md`; `README.md`; `docs/opt-in-configs.md`; current `./bootstrap --help`.
- **Expected public interface:** Operator-facing Markdown documentation.
- **What to build:** Documentation for wizard and automation workflows without implementing CLI behavior.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Keep examples WSL/Bash friendly; no package install or network instructions beyond existing prerequisites; do not imply global skills are required for target portability.
- **Dependencies:** T013 establishes mode names; later T014/T015/T016 may require doc refinements if prompt wording changes.
- **Parallelization:** Parallel-safe: Yes. Collision domain: docs. Can run with T014, T015, T016. Must not run with None.
- **Verification command:** `rg -n "interactive|non-interactive|global skill|Non-Destructive Retrofit|prefix|completion" README.md docs/opt-in-configs.md`.
- **Closeout criteria:** Docs match the current `./bootstrap --help`, acceptance criteria are checked, task is updated, and follow-ups are filed for any prompt wording still pending implementation.

### T018: Add wizard verification coverage

- **Epic:** E05
- **Type:** AFK
- **Depends on:** T014, T015, T016, T017
- **Execution-ready:** Yes
- **Parallel-safe:** No
- **Collision domain:** `verification/`, `bootstrap`, README verification examples, `/tmp` smoke targets.
- **Can run with:** None
- **Must not run with:** T013, T014, T015, T016, T017
- **What to build:** Extend verification scripts and documented smoke checks to cover interactive/no-prompt behavior, global skill preflight with temporary home directories, existing-project retrofit, and completion-note readback.
- **PRD traceability:** FR-012, FR-013, FR-014, FR-015, FR-016, FR-011, M-004, AC-022 through AC-035.

**Acceptance criteria**

- [ ] Verification checks `./bootstrap --help` includes `--interactive` and `--non-interactive`.
- [ ] Verification proves `--non-interactive` and non-TTY/CI paths do not prompt.
- [ ] Verification covers global skill preflight using a temporary `HOME` or documents the exact manual check if full automation is impractical.
- [ ] Verification covers existing non-empty target retrofit behavior.
- [ ] Verification checks successful install or retrofit completion-note readback.
- [ ] Verification remains safe for `/tmp` and does not mutate real global skill directories.

**Agent Handoff Packet**

- **Context to read:** PRD M-004, FR-011 through FR-016, AC-022 through AC-035; T014/T015/T016 outputs; `verification/run-static-checks.sh`; `README.md`.
- **Expected public interface:** Verification command output and documented smoke checks.
- **What to build:** Wizard-specific verification coverage and safe smoke fixtures.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Do not mutate real `$HOME/.agents/skills`; use temporary `HOME` or explicit manual checks; do not delete unrelated `/tmp` content; avoid network and package installs.
- **Dependencies:** T014, T015, T016, T017.
- **Parallelization:** Parallel-safe: No. Collision domain: verification suite and wizard acceptance state. Can run with: None. Must not run with T013, T014, T015, T016, T017.
- **Verification command:** `./verification/run-static-checks.sh`; any new wizard smoke script added by this task; `git diff --check`.
- **Closeout criteria:** Wizard verification passes or records exact skipped commands and blockers, task is updated, and the plan is ready for `plan-to-beads-unified`.

### T019: Decide optional advanced wizard flags and report mode

- **Epic:** E05
- **Type:** HITL
- **Depends on:** T013
- **Execution-ready:** No
- **Parallel-safe:** Yes
- **Collision domain:** Future CLI contract, optional `--mode`, `--target`, `--global-skills`, and machine-readable report behavior.
- **Can run with:** T014, T015, T016, T017
- **Must not run with:** None
- **What to build:** Human decision record for optional flags beyond `--interactive` and `--non-interactive`, and whether global skill checking should support a machine-readable report mode.
- **PRD traceability:** Q-005, Q-008, FR-014, FR-013.

**Acceptance criteria**

- [ ] Decision states whether to add `--mode new|existing` in v1 or defer it.
- [ ] Decision states whether to add `--target <path>` in v1 or keep positional target only.
- [ ] Decision states whether to add `--global-skills ask|install|update|skip` in v1 or keep global skill management interactive-only.
- [ ] Decision states whether machine-readable global skill report mode is in scope for v1.
- [ ] Any approved advanced flag is reflected in PRD/plan follow-up before implementation.

**Agent Handoff Packet**

- **Context to read:** PRD Q-005, Q-008, FR-013, FR-014; `docs/decision-brief-bootstrap-interactive-wizard.md`; current `./bootstrap --help`; T013 implementation notes.
- **Expected public interface:** Decision record or ADR candidate, not implementation.
- **What to build:** A concise HITL decision artifact that approves or defers advanced CLI/report behavior.
- **Acceptance criteria:** Same checklist as above.
- **Constraints:** Do not implement advanced flags in this task; keep core v1 wizard unblocked by deferring optional scope.
- **Dependencies:** T013 establishes the baseline mode contract.
- **Parallelization:** Parallel-safe: Yes. Collision domain: decision docs only. Can run with T014, T015, T016, T017. Must not run with None.
- **Verification command:** `rg -n "Q-005|Q-008|--mode|--global-skills|machine-readable" docs`.
- **Closeout criteria:** Human decision is recorded, any resulting PRD/plan changes are filed, and execution-ready implementation Beads are created only for approved scope.

## Recommended Sequence

1. **T001** - Establish the new repo shell; every other task depends on stable paths.
2. **T002** - Create the CLI skeleton early so user-facing behavior is testable.
3. **T004** - Build the target asset tree in parallel with CLI skeleton work after T001.
4. **T005** - Write operator docs and opt-in config guide while the asset tree takes shape.
5. **T003** - Add installer safety behavior once CLI parsing exists.
6. **T006** - Port the planning-chain skills after templates and docs paths are stable.
7. **T007** - Rewrite session-start/session-wrapup after core skills and state paths exist.
8. **T009** - Add custom agents; can run alongside T007 after target paths are stable.
9. **T008** - Implement dual-mode `minion` after the worker agent contract exists.
10. **T010** - Add verification scripts/scans while implementation proceeds.
11. **T011** - Integrate installer, assets, and docs once the CLI and assets are ready.
12. **T012** - Run final acceptance validation after all implementation tasks land.
13. **T013** - Establish the interactive/non-interactive mode contract before adding prompt behavior.
14. **T014** - Add global skill preflight after mode handling prevents accidental non-interactive global writes.
15. **T015** - Add target mode, prefix, plan preview, and final confirmation flow once mode handling is stable.
16. **T016** - Complete retrofit and completion-note behavior after interactive target confirmation exists.
17. **T017** - Update operator documentation after the public mode names are stable; refine alongside T014-T016 if prompt wording changes.
18. **T018** - Add wizard verification after wizard behavior and docs are in place.
19. **T019** - Resolve optional advanced flags/report mode only if the operator wants v1 scope beyond `--interactive` and `--non-interactive`.

## Risks and Open Questions

- **Q-001 affects T002/T003:** The internal implementation shape for `bootstrap` is not settled. The plan assumes a repo-root executable can own the public interface while internals remain an engineering choice.
- **Q-002 affects T008:** Exact `minion` report/state fields are not settled. T008 should define a minimal schema as part of its implementation.
- **Q-003 affects T009:** Exact custom-agent TOML content is not settled. T009 should create narrow first-pass agents grounded in the PRD and source roles.
- **Q-004 affects T006/T007/T008:** Legacy skill merge/rename choices beyond settled names may appear during rewrite. Default to preserving stable names and filing follow-ups for ambiguous merges.
- **Q-005 affects T019:** Optional flags beyond `--interactive` and `--non-interactive` are not settled. Core v1 wizard tasks should not add `--mode`, `--target`, or `--global-skills` unless T019 records that decision.
- **Q-006 affects T015:** Prefix derivation is not fully specified. T015 should choose a deterministic, previewed algorithm and allow override; if that choice feels product-significant, file a HITL follow-up before implementation.
- **Q-007 affects T016:** Completion-note schema is not fully specified. T016 should use the existing version 1 state-doc shape unless implementation discovers a schema conflict.
- **Q-008 affects T019:** Machine-readable global skill report mode is optional future automation scope and should not block the core v1 wizard.
- **R-001:** Claude-specific path assumptions can survive migration. Mitigate through T010/T012 scans and manual readback.
- **R-002:** All-skill rewrite scope is broad. Mitigate by keeping tasks vertical and preserving traceability.
- **R-003:** Mandatory Beads can block real install validation. Mitigate by making dry-run independent and documenting exact commands when real install is skipped.
- **R-004:** `minion` fanouts can become hard to synthesize and merge. Mitigate through default 6-way fanout, a hard cap of 6 workers, execution warnings, and collision planning.
- **R-005:** Codex project config/hooks may require project trust. Mitigate through `docs/opt-in-configs.md` and verification notes.
- **R-006:** Relocation to `/home/echo/dev` can break if paths are hardcoded. Mitigate through relative path resolution and relocation scans.
- **R-007:** Interactive Bash flows can become hard to test. Mitigate by reusing existing planner/report functions, keeping prompt functions thin, and adding T018 verification.
- **R-008:** Global skill writes can erode trust. Mitigate through explicit source/destination/status reporting, temporary-home tests, and confirmation before writes.
- **R-009:** Prefix suggestions can surprise operators. Mitigate through preview and override in T015.
- **R-010:** Existing-project retrofits can be mistaken for whole-repo migrations. Mitigate through consistent Non-Destructive Retrofit language, plan preview, and all-or-nothing conflict behavior.

## Handoff to `plan-to-beads-unified`

Use this reviewed plan plus the parent PRD to update the existing Beads backlog before further fanout.

- Convert only `Execution-ready: Yes` tasks into Beads work items when creating new backlog items.
- Preserve task order, task IDs, epic IDs, dependencies, PRD traceability, Agent Handoff Packets, and parallel-safety metadata.
- Keep `HITL` or `Execution-ready: No` items out of Beads until clarified.
- Existing Beads should be reconciled so T003 depends on T004, T008 depends on T009, T008/T009 are no longer co-runnable, and conditional `Must not run with` language is removed before `scribe-refine` or equivalent JIT refinement promotes tasks beyond backlog.
- For the interactive wizard update, convert T013 through T018 into Beads after plan approval. Keep T019 out of implementation Beads until the operator explicitly approves advanced optional flags or machine-readable report mode.
