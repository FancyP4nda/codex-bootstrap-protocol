---
workflow_artifact: prd
artifact_version: 1
source_mode: existing_project
status: approved
upstream_ids: []
recommended_next_skill: project-planner
canonical_next_artifact: project_plan
---

# Product Requirements Document: Codex Bootstrap Protocol

## 1. Executive Summary

- **Target persona:** The repository owner/operator and Codex agents working in project repositories that need a repeatable planning-to-execution scaffold.
- **Core problem:** The current `bootstrap-protocol` scaffold is Claude-first. It installs `.claude/` runtime surfaces, refers to Claude slash commands, and includes Falcon behavior built on Claude background-session primitives. The user needs a Codex-native scaffold that preserves the workflow intent while using documented Codex surfaces.
- **Business goal:** Create a reusable local scaffold that initializes Codex-ready projects with repo-scoped skills, Beads-first execution tracking, Codex subagent workflows, and durable project documentation.
- **Product outcome:** A relocation-safe `codex-bootstrap-protocol` repo that exposes a `bootstrap` command, installs Codex-native project assets, rewrites bundled workflows away from live `.claude/*` dependencies, and verifies clean disposable installs under `/tmp`.
- **Status:** Approved.
- **Docs source of truth:** `\\wsl.localhost\Ubuntu\home\echo\ACC\codex-bootstrap-protocol\docs` is the operator-facing source-of-truth docs path. In-repo artifact links use `docs/...`; source-kit migration references use sibling paths under `../bootstrap-protocol/...`.

## 2. Upstream Traceability

- **Source opportunity IDs:** None.
- **Decision brief:** `docs/decision-brief-codex-bootstrap-protocol.md`
- **Key resolved decisions:**
  - Build a Codex-native-only fork; do not install Claude runtime compatibility files.
  - Deliver a scaffold repo first; plugin packaging is a later phase.
  - Copy and transform `bootstrap-protocol` with a strict allowlist.
  - Rewrite all bundled workflow skills in the first Codex fork.
  - Replace Claude slash-command concepts with Codex skills: `session-start`, `session-wrapup`, and `minion`.
  - Use `docs/CONTEXT.md` as the canonical glossary path.
  - Require Beads (`bd`) as a mandatory preinstalled dependency.
  - Keep project `.codex/config.toml` minimal and non-invasive.
  - Ship hooks/rules as opt-in examples with documentation, not active enforcement.
  - Make `minion` report-only in v1, default to 10-way fanout, and impose no scaffold-level hard cap.
  - Validate disposable installs under `/tmp` and keep the repo relocation-safe for a later move to `/home/echo/dev`.
- **Key unresolved HITL decisions:**
  - Whether `bootstrap` is a renamed script, a wrapper around an internal script, or installed through a setup flow.
  - Exact custom-agent TOML content.
  - Exact `minion` report/state schemas.
  - Whether any legacy skill concepts collapse into one renamed Codex-native skill during rewrite.
- **Repo grounding:**
  - `../bootstrap-protocol/init-project.sh` currently copies `.claude/` assets and initializes Beads.
  - `../bootstrap-protocol/Starting-workflow.md` describes the existing idea-to-ship pipeline and Claude command entry points.
  - `../bootstrap-protocol/.claude/CLAUDE.md` defines current product-truth, workflow, and precedence rules.
  - `../bootstrap-protocol/.claude/skills/*` contains the bundled workflow skill source material.
  - `../bootstrap-protocol/.claude/templates/artifacts/prd.md.hbs` defines the PRD structure used for this PRD.
- **Official Codex documentation evidence:**
  - `AGENTS.md` project guidance, discovery, fallback filenames, and `project_doc_max_bytes`: https://developers.openai.com/codex/guides/agents-md
  - Agent skills and `.agents/skills` repo/user discovery: https://developers.openai.com/codex/skills
  - Project `.codex/config.toml`, trust behavior, ignored project-local provider/auth/telemetry keys, and configuration precedence: https://developers.openai.com/codex/config-basic and https://developers.openai.com/codex/config-advanced
  - Hooks and `[features].hooks`: https://developers.openai.com/codex/hooks
  - Rules under `.codex/rules`: https://developers.openai.com/codex/rules
  - Subagents, project-scoped `.codex/agents/*.toml`, required custom-agent fields, and `[agents]` settings such as `agents.max_depth`: https://developers.openai.com/codex/subagents

## 3. Scope

### Goals

- **G-001:** Create `/home/echo/ACC/codex-bootstrap-protocol` as a Codex-native scaffold repo that can later move to `/home/echo/dev` without hardcoded-path breakage.
- **G-002:** Provide a repo-root `bootstrap` executable that initializes target projects with Codex-native assets.
- **G-003:** Rewrite all bundled workflow skills to use Codex-native paths, terminology, and workflow surfaces.
- **G-004:** Preserve the Bootstrap Protocol planning-to-execution chain while replacing Claude slash commands and agents with Codex skills and custom agents.
- **G-005:** Make Beads mandatory and fail safely before writes when Beads is unavailable.
- **G-006:** Provide opt-in hooks/rules/config examples with clear documentation.
- **G-007:** Validate the scaffold through syntax checks, reference scans, relocation checks, and disposable `/tmp` install/readback.

### Non-Goals

- **NG-001:** Support Claude runtime compatibility in installed target projects.
- **NG-002:** Package the scaffold as a Codex plugin in the first phase.
- **NG-003:** Auto-install Beads, Codex, packages, or other machine dependencies.
- **NG-004:** Enable aggressive hooks, command blockers, telemetry, network calls, or auto-approval rules by default.
- **NG-005:** Create PRs, push branches, deploy, comment on external systems, or call cloud services by default.
- **NG-006:** Depend on deprecated Codex custom prompts as the shared command surface.

## 4. Users and Use Cases

### Personas

- **P-001 Operator:** The human maintaining the scaffold and using it to create or retrofit projects.
- **P-002 Project Agent:** A Codex agent working inside a target project initialized by the scaffold.
- **P-003 Future Contributor:** A person or agent maintaining the Codex-native fork after it is moved or packaged.

### Primary Use Cases

- **UC-001:** The operator initializes a new target project from the scaffold with `./bootstrap <target> --prefix <PREFIX>`.
- **UC-002:** The operator previews file operations before writing with `./bootstrap --dry-run <target> --prefix <PREFIX>`.
- **UC-003:** The operator attempts to bootstrap an existing repo and receives a conflict report instead of accidental overwrites.
- **UC-004:** A Project Agent invokes repo-scoped Codex skills for planning, PRD generation, project planning, Beads conversion, session start, session wrapup, TDD, and `minion` fanout.
- **UC-005:** The operator reviews optional hook/rule/config examples and enables only the controls that fit the project.

## 5. Functional Requirements

- **FR-001 Bootstrap command:** The scaffold must provide a repo-root executable named `bootstrap`.
  - **Priority:** Must
  - **Source:** Decision brief resolved decisions
  - **Acceptance criteria:** AC-001, AC-002, AC-003

- **FR-002 Dry-run behavior:** The `bootstrap` command must support dry-run mode that reports planned operations and conflicts without writing files.
  - **Priority:** Must
  - **Source:** Decision brief acceptance signals
  - **Acceptance criteria:** AC-004, AC-005

- **FR-003 Mandatory Beads prerequisite:** The `bootstrap` command must require `bd` for non-dry-run installs and fail before writes when it is unavailable.
  - **Priority:** Must
  - **Source:** Decision brief resolved decisions
  - **Acceptance criteria:** AC-006, AC-007

- **FR-004 Codex-native target tree:** Successful installs must create the agreed Codex-native tree and avoid active `.claude/` runtime dependencies.
  - **Priority:** Must
  - **Source:** Decision brief installed tree
  - **Acceptance criteria:** AC-008, AC-009

- **FR-005 Existing repo conflict handling:** The scaffold must detect managed-path conflicts in existing repos and stop with a report by default.
  - **Priority:** Must
  - **Source:** Follow-up conflict decision
  - **Acceptance criteria:** AC-010, AC-011

- **FR-006 Skill rewrite coverage:** All bundled workflow skills must be rewritten for Codex-native paths, names, and surfaces.
  - **Priority:** Must
  - **Source:** Decision brief resolved decisions
  - **Acceptance criteria:** AC-012, AC-013

- **FR-007 Codex command surface:** Claude slash-command concepts must be exposed as Codex skills with the agreed names.
  - **Priority:** Must
  - **Source:** Follow-up skill naming decision
  - **Acceptance criteria:** AC-014

- **FR-008 Minion fanout:** The scaffold must include a report-only `minion` workflow for explicit Codex subagent fanout.
  - **Priority:** Must
  - **Source:** Follow-up minion decision
  - **Acceptance criteria:** AC-015, AC-016, AC-017

- **FR-009 Opt-in configuration documentation:** The scaffold must document all optional hooks, rules, custom agents, stricter profiles, and related guardrails.
  - **Priority:** Must
  - **Source:** User follow-up on opt-in configs
  - **Acceptance criteria:** AC-018

- **FR-010 Relocation safety:** The scaffold must avoid hardcoded source paths that prevent moving the repo from `/home/echo/ACC` to `/home/echo/dev`.
  - **Priority:** Must
  - **Source:** User relocation statement
  - **Acceptance criteria:** AC-019

- **FR-011 Verification suite:** The repo must include or document verification commands for syntax checks, reference scans, dependency checks, and disposable `/tmp` install/readback.
  - **Priority:** Must
  - **Source:** Decision brief acceptance signals
  - **Acceptance criteria:** AC-020, AC-021

## 6. BDD Scenarios and Acceptance Criteria

### US-001: Run bootstrap from the repo checkout

**Requirement coverage:** FR-001

**Scenario:** Operator initializes a target project from the scaffold checkout

- **Given** the operator is in the `codex-bootstrap-protocol` repo and `bd` is available
- **When** the operator runs `./bootstrap <target> --prefix <PREFIX>`
- **Then** the command initializes the target project or prints actionable validation failures

**Acceptance criteria**

- **AC-001:** `./bootstrap --help` documents required arguments, `--prefix`, `--dry-run`, and `--force`.
- **AC-002:** `./bootstrap <target> --prefix <PREFIX>` is the documented primary invocation from the repo checkout.
- **AC-003:** Documentation includes optional symlink/PATH setup without performing it automatically.

### US-002: Preview without writing

**Requirement coverage:** FR-002

**Scenario:** Operator previews a target install

- **Given** a target path is supplied
- **When** the operator runs `./bootstrap --dry-run <target> --prefix <PREFIX>`
- **Then** the command reports planned Codex-native file operations and exits without writing scaffold files

**Acceptance criteria**

- **AC-004:** Dry-run output lists created paths, skipped paths, and conflicts.
- **AC-005:** Dry-run does not require `bd` to be present.

### US-003: Fail safely when Beads is missing

**Requirement coverage:** FR-003

**Scenario:** Operator runs a real install without Beads available

- **Given** `bd` is not available on `PATH`
- **When** the operator runs `./bootstrap <target> --prefix <PREFIX>`
- **Then** the command stops before writes and prints exact corrective instructions

**Acceptance criteria**

- **AC-006:** Missing `bd` causes a non-zero exit before target files are written.
- **AC-007:** The error explains that Beads is mandatory and gives the manual command or setup step needed before retrying.

### US-004: Install Codex-native scaffold assets

**Requirement coverage:** FR-004

**Scenario:** Operator installs into a clean target

- **Given** a clean target directory and available `bd`
- **When** the operator runs `./bootstrap <target> --prefix <PREFIX>`
- **Then** the target contains Codex-native instructions, skills, templates, config, docs, state directories, and initialized Beads

**Acceptance criteria**

- **AC-008:** A successful install creates `AGENTS.md`, `.agents/skills/`, `.agents/templates/`, `.codex/config.toml`, `.codex/agents/`, `.codex/hooks/`, `.codex/rules/`, `.codex/state/tmp/`, `docs/CONTEXT.md`, `docs/adr/`, `docs/prd.md`, `docs/project-plan.md`, `docs/architecture.md`, `docs/backend.md`, `docs/frontend.md`, `docs/data-model.md`, `docs/security.md`, `docs/handoff.yaml`, `docs/changelog.yaml`, `docs/enhancements.md`, `docs/standards-history.md`, `.archive/`, and `.beads/`.
- **AC-009:** The installed target has no active `.claude/` runtime tree created by the scaffold.

### US-005: Protect existing repo files

**Requirement coverage:** FR-005

**Scenario:** Operator bootstraps a repo that already has managed paths

- **Given** the target repo already contains one or more managed scaffold paths
- **When** the operator runs `./bootstrap <target> --prefix <PREFIX>` without `--force`
- **Then** the command exits before writes and prints a conflict report

**Acceptance criteria**

- **AC-010:** The conflict report includes path, planned action, conflict reason, and suggested resolution.
- **AC-011:** `--force` may overwrite managed scaffold files only and never overwrites `.beads/`, `.git/`, credentials, or ignored transient state.

### US-006: Invoke Codex-native workflow skills

**Requirement coverage:** FR-006, FR-007

**Scenario:** Project Agent works inside an initialized target

- **Given** the target contains repo-scoped Codex skills under `.agents/skills/`
- **When** Codex is launched in the target repo
- **Then** the bundled workflows are available as Codex skills using Codex-native paths and names

**Acceptance criteria**

- **AC-012:** Path/reference scans show no live `.claude/*` runtime dependencies in rewritten workflow skills, scoped to installed Codex asset roots and excluding documented migration/source-reference areas such as `docs/`, `.archive/`, and review logs.
- **AC-013:** `grill-with-docs` and related skills treat `docs/CONTEXT.md` as the canonical glossary path.
- **AC-014:** Claude command concepts are exposed as `session-start`, `session-wrapup`, and `minion` skills.

### US-007: Fan out with minion

**Requirement coverage:** FR-008

**Scenario:** Operator asks for parallel subagent review or research

- **Given** the target contains the `minion` skill and Codex subagent support is available
- **When** the operator invokes `minion` with a fanout request
- **Then** the workflow plans the fanout, launches explicit subagents, collects structured reports, and summarizes outcomes

**Acceptance criteria**

- **AC-015:** `minion` defaults to 10-way fanout when the user does not request a different number.
- **AC-016:** `minion` imposes no scaffold-level hard cap and warns that practical limits are subject to Codex runtime, account, and environment constraints.
- **AC-017:** `minion` v1 is report-only. Write-heavy fanout requests must be converted to planning/review reports or explicitly deferred; write-capable dispatch requires a later phase with file-scope and collision-domain planning.

### US-008: Review optional configs before enabling

**Requirement coverage:** FR-009

**Scenario:** Operator evaluates optional guardrails

- **Given** the scaffold includes opt-in hooks, rules, custom agents, and profile examples
- **When** the operator opens `docs/opt-in-configs.md`
- **Then** each optional config explains its purpose, risk, enable steps, disable steps, and verification

**Acceptance criteria**

- **AC-018:** `docs/opt-in-configs.md` covers hooks, rules, custom subagents, `minion` settings, stricter approval/sandbox profiles, and any memory or automation examples shipped by the scaffold.

### US-009: Verify relocation safety and disposable install

**Requirement coverage:** FR-010, FR-011

**Scenario:** Maintainer validates the scaffold before handoff

- **Given** the scaffold repo is ready for validation
- **When** the maintainer runs the documented verification commands
- **Then** the checks prove shell syntax, reference hygiene, relocation safety, and `/tmp` install/readback

**Acceptance criteria**

- **AC-019:** Verification reports no hardcoded `/home/echo/ACC` dependency in runtime/install logic, while allowing explicit examples and migration notes under documented allowlist paths such as `docs/`, `.archive/`, and review logs.
- **AC-020:** Shell syntax checks pass for the `bootstrap` executable and any helper shell scripts.
- **AC-021:** A disposable `/tmp` target install/readback confirms the expected Codex-native tree.

## 7. Nonfunctional Requirements

- **NFR-001 Security:** The scaffold must be secure by default: no secret exposure, no credential writes, no external publication, and no network/cloud operations by default.
- **NFR-002 Privacy:** Transient state, logs, transcript references, and dispatch scratch files must stay out of Git by default.
- **NFR-003 Performance:** Dry-run and conflict scanning should complete quickly enough for interactive use on normal project trees; no baseline is established yet.
- **NFR-004 Reliability:** The initializer must fail before partial writes for missing mandatory prerequisites and unmanaged conflicts.
- **NFR-005 Accessibility:** Documentation should use plain Markdown with clear commands, paths, and expected outcomes.
- **NFR-006 Observability:** Verification commands should produce enough output to identify failed prerequisites, conflicts, stale path references, and missing installed assets.

## 8. Technical and Operational Constraints

- **C-001 Supported interfaces:** The primary public interface is the repo-root CLI executable `./bootstrap`. The secondary operator interface is Codex skills under `.agents/skills/`.
- **C-002 Compatibility:** The scaffold targets Codex-native behavior only. Claude compatibility files may exist only as migration/source references, not installed runtime surfaces.
- **C-003 Dependency policy:** Beads (`bd`) is mandatory and must be preinstalled. The scaffold must not auto-install Beads or other dependencies.
- **C-004 Deployment or rollout:** Phase one is local-first. No plugin publishing, marketplace setup, external PR creation, cloud deployment, or shared distribution is required.
- **C-005 Data or migration:** Durable project continuity belongs under `docs/`; transient runtime state belongs under gitignored `.codex/state/tmp/`.
- **C-006 Project config:** `.codex/config.toml` must stay minimal and must not set model, provider, auth, telemetry, network, sandbox, or auto-approval defaults.

## 9. AI Behavior and Evaluation

- **AI-001 Intended model behavior:** Codex should discover and use repo-scoped skills for planning, PRD drafting, project planning, Beads conversion, TDD, session start, session wrapup, and `minion` fanout.
- **AI-002 Evaluation dataset or rubric:** Use deterministic readback checks for installed file paths, scoped reference scans for `.claude/*` runtime dependencies, scoped relocation scans for hardcoded `/home/echo/ACC` runtime dependencies, and manual review of rewritten skill instructions against the PRD requirements.
- **AI-003 Quality threshold:** All Must-priority functional requirements should have observable acceptance evidence before the first fork is considered done.
- **AI-004 Safety constraints:** Agent workflows must not initiate external actions, package installs, network calls, cloud changes, or destructive operations without explicit user approval.

## 10. Success Metrics

- **M-001:** Disposable install success.
  - **Baseline:** Unknown.
  - **Target:** `./bootstrap <tmp-target> --prefix <PREFIX>` creates the expected tree and initializes Beads when `bd` is available.
  - **Measurement source:** Verification command output and readback of the `/tmp` target.

- **M-002:** Runtime dependency rewrite coverage.
  - **Baseline:** Existing source has known `.claude/*` runtime dependencies.
  - **Target:** Reference scan finds no live `.claude/*` runtime dependencies in installed Codex workflow assets.
  - **Measurement source:** Repository reference scan.

- **M-003:** Conflict safety.
  - **Baseline:** Existing script overwrites target `.claude/` machinery with `--force` behavior.
  - **Target:** Existing managed-path conflicts stop before writes by default and print a conflict report.
  - **Measurement source:** Existing-repo dry-run and conflict test output.

## 11. Assumptions

- **A-001:** The first build may happen under `/home/echo/ACC`, but the finished repo should move cleanly to `/home/echo/dev`.
  - **Source:** User follow-up.

- **A-002:** Codex documentation remains the source of truth for runtime surface mapping. Current official docs confirm repo/user skills under `.agents/skills`, `AGENTS.md` discovery, project `.codex/config.toml` for trusted projects, hooks/rules under `.codex/`, and project-scoped custom agents under `.codex/agents/*.toml` with `name`, `description`, and `developer_instructions`.
  - **Source:** User instruction, Decision Brief, and official Codex docs cited in section 2.

- **A-003:** `bootstrap-protocol` remains available as source material during the copy-and-transform implementation.
  - **Source:** Repository grounding.

- **A-004:** The target environment can provide Beads (`bd`) before a real install.
  - **Source:** Mandatory Beads decision.

## 12. Open Questions and HITL Decisions

- **Q-001:** Should `bootstrap` be a renamed script, a wrapper around internal implementation files, or supported by an optional setup script?
  - **Blocks:** Does not block PRD approval; affects implementation plan details.
  - **Needed from:** Engineering / Operator.

- **Q-002:** What exact fields should `minion` reports and transient state files contain?
  - **Blocks:** FR-008 implementation details.
  - **Needed from:** Engineering.

- **Q-003:** What are the exact custom-agent TOML instructions for `navigator`, `reviewer`, `worker`, and optional `scribe`?
  - **Blocks:** Full custom-agent implementation.
  - **Needed from:** Engineering.

- **Q-004:** Should any legacy workflow skills be merged or renamed during the Codex rewrite beyond the settled `session-start`, `session-wrapup`, and `minion` names?
  - **Blocks:** Skill inventory finalization.
  - **Needed from:** Operator / Engineering.

## 13. Risks

- **R-001:** Claude-specific assumptions may survive in rewritten skills.
  - **Impact:** High
  - **Mitigation:** Require reference scans and targeted readback of every installed skill path.

- **R-002:** The first fork may become too broad because all bundled workflow skills are in scope.
  - **Impact:** Medium
  - **Mitigation:** Preserve the PRD boundary, then use `project-planner` to sequence vertical slices and mark risky work as non-parallel-safe.

- **R-003:** Mandatory Beads can block installs on machines without `bd`.
  - **Impact:** Medium
  - **Mitigation:** Fail before writes with exact corrective instructions.

- **R-004:** Large `minion` fanouts can create token, approval, resource, and synthesis overhead.
  - **Impact:** Medium
  - **Mitigation:** Default to 10, warn on large fanout, and require collision-domain planning for write-heavy fanout.

- **R-005:** `.codex/config.toml` and project-local hooks may be ignored until the project is trusted.
  - **Impact:** Medium
  - **Mitigation:** Document trust behavior and verification in `docs/opt-in-configs.md`.

- **R-006:** Hardcoded source paths could break after the repo moves to `/home/echo/dev`.
  - **Impact:** Medium
  - **Mitigation:** Resolve paths relative to the script/repo root and run relocation-safety scans.

## 14. Proof Statement

- **Repo evidence checked:** `docs/codex-bootstrap-protocol-PRD.md`, `docs/decision-brief-codex-bootstrap-protocol.md`, `docs/codex-bootstrap-protocol-project-plan.md`, `docs/codex-bootstrap-protocol-PRD-review-log.md`, and `.beads/issues.jsonl` were reviewed during the Round 2/3 cross-model review cycle.
- **Existing domain fit:** The sibling source kit remains a migration input under `../bootstrap-protocol/...`; direct checks confirmed `../bootstrap-protocol/.claude/commands/leroy.md` and `../bootstrap-protocol/.claude/commands/wrapup.md` exist.
- **Schema/data contract checked:** Beads issue descriptions were treated as the execution contract, not only the passive `.beads/issues.jsonl` export.
- **Security/privacy review points:** The Antigravity test showed raw repo workspace access can mutate Beads and Git despite a read-only prompt; the global review skill was hardened to use pasted-content or a no-write adapter for Antigravity by default.
- **Official Codex surface check:** Current Codex manual fetch on June 7, 2026 reported the local manual current and verified `.agents/skills`, project-scoped `.codex/config.toml`, project-local hooks/rules trust behavior, project custom agents under `.codex/agents/`, required custom-agent fields, and `[agents].max_depth`.
- **Dependency/order constraints:** Antigravity-authored T001/T002 implementation commits were removed from branch history, and T001/T002 were reopened for fresh implementation. The project-plan review found that T003 must depend on T004 and T008 must depend on T009 before further fanout.
- **Test or verification strategy:** Verification scans must be scoped to runtime/install asset roots or use explicit allowlists so migration notes in `docs/`, `.archive/`, and review logs do not create false positives.
- **Known unresolved assumptions:** Exact `minion` report schemas and custom-agent TOML content remain implementation decisions. The operator confirmed GitHub username `FancyP4nda` and email `zjones976@gmail.com`; the Beads owner/email pairing is approved, and Antigravity-authored implementation work is no longer treated as a release baseline.

## 15. Planning Handoff

This approved PRD has already been used to produce `docs/codex-bootstrap-protocol-project-plan.md` and the initial Beads backlog. Use it as the governing requirements source for subsequent plan updates and implementation work.

- Preserve decision, requirement, story, acceptance-criteria, constraint, assumption, open-question, and risk IDs.
- Convert requirements into outcome-oriented epics and vertical-slice tasks in `docs/project-plan.md`.
- Mark tasks blocked by unresolved questions as `HITL` or `Execution-ready: No`.
- Do not create Beads items directly from this PRD; use `project-planner` first, then `plan-to-beads-unified`.
