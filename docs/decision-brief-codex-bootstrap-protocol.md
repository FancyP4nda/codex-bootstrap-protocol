---
workflow_artifact: decision_brief
artifact_version: 1
source_mode: existing_project
status: approved
upstream_ids: []
recommended_next_skill: product-architect
canonical_next_artifact: prd
---

## Decision Brief

- **Source opportunity:** Not provided.
- **Problem statement:** The existing `bootstrap-protocol` is a Claude-first scaffold. Its initializer copies `.claude/` machinery, relies on Claude slash commands, and includes Falcon behavior built on Claude background-session primitives. The new product should be a Codex-native scaffold repo in `/home/echo/ACC/codex-bootstrap-protocol` that preserves the Bootstrap Protocol workflow intent while mapping every runtime surface to documented Codex concepts.
- **Docs source of truth:** `\\wsl.localhost\Ubuntu\home\echo\ACC\codex-bootstrap-protocol\docs` is the operator-facing source-of-truth docs path. In-repo artifact links use `docs/...`; source-kit migration references use sibling paths under `../bootstrap-protocol/...`.
- **Resolved terminology:**
  - **Codex-native fork:** A new scaffold repo that uses Codex runtime surfaces only. Claude files may be used as source material or migration references, but are not installed as active workflow surfaces.
  - **Scaffold repo:** The primary deliverable for the first phase. It creates and updates target projects. It is not plugin-first.
  - **Workflow skill:** A repo-shared Codex skill under `.agents/skills/` that replaces Claude slash-command workflow entry points.
  - **Custom agent:** A Codex subagent role definition under `.codex/agents/*.toml`, used only for repeatable delegated work.
  - **Codex-Falcon:** A conceptual redesign of Falcon for Codex subagents. It keeps the goal of coordinated parallel execution, reporting, locks, and wrapup synthesis, but does not reuse Claude background-session mechanics.
  - **Project glossary:** `docs/CONTEXT.md`, not root `CONTEXT.md`. All relevant skills must be rewritten to treat this path as canonical.
  - **Durable workflow state:** Shared human/project continuity files in `docs/`, especially `docs/handoff.yaml` and `docs/changelog.yaml`.
  - **Transient runtime state:** Local scratch state under gitignored `.codex/state/tmp/`.
  - **Bootstrap command:** The user-facing CLI should be `bootstrap <target> --prefix <PREFIX>`, not `init-project.sh <target> --prefix <PREFIX>`.
  - **Minion:** The Codex-native replacement name for the Falcon concept. It provides explicit subagent fanout and structured report collection.
- **Resolved decisions:**
  - Build a Codex-native-only fork. Do not preserve Claude runtime compatibility in installed projects.
  - Deliver a project scaffold repo first. Plugin packaging is a later phase after the scaffold stabilizes.
  - Copy and transform `bootstrap-protocol` with a strict allowlist, rather than starting from an empty repo.
  - Rewrite all bundled workflow skills in the first Codex fork, not only an MVP subset.
  - Redesign Falcon around Codex subagents instead of porting Claude mechanics.
  - Replace Claude slash commands with shared Codex skills as the canonical command surface.
  - Ship `bootstrap` as a repo-root executable first, invoked as `./bootstrap <target> --prefix <PREFIX>`. Document optional PATH/symlink setup, but do not mutate PATH automatically.
  - In existing repos, fail fast with a conflict report by default. `--force` may overwrite managed scaffold files only; it must not overwrite `.beads/`, git files, credentials, or ignored transient state.
  - Preserve stable planning skill names, but rename Claude-command concepts:
    - `/leroy` -> `session-start`
    - `/wrapup` -> `session-wrapup`
    - `/falcon` -> `minion`
  - Use this installed tree:

    ```text
    /
    |-- AGENTS.md
    |-- docs/
    |   |-- CONTEXT.md
    |   |-- prd.md
    |   |-- project-plan.md
    |   |-- architecture.md
    |   |-- backend.md
    |   |-- frontend.md
    |   |-- data-model.md
    |   |-- security.md
    |   |-- handoff.yaml
    |   |-- changelog.yaml
    |   |-- enhancements.md
    |   |-- standards-history.md
    |   `-- adr/
    |-- .agents/
    |   |-- skills/
    |   `-- templates/
    |-- .codex/
    |   |-- config.toml
    |   |-- agents/
    |   |-- hooks/
    |   |-- rules/
    |   `-- state/
    |-- .beads/
    `-- .archive/
    ```

  - Store artifact templates under `.agents/templates/`.
  - Store schema/template references for handoff and changelog under `.agents/templates/schemas/`.
  - Store durable handoff/history in `docs/handoff.yaml` and `docs/changelog.yaml`.
  - Store transient dispatch/session state in gitignored `.codex/state/tmp/`.
  - Support both new target directories and conservative existing-repo installs.
  - Add `--dry-run` and `--force` behavior.
  - Make Beads mandatory. Remove any `--no-beads` behavior from the Codex-native fork.
  - Require preinstalled `bd`; do not auto-install dependencies. If `bd` is missing, fail before writes except for dry-run/dependency-check flows.
  - Use minimal `.codex/config.toml` defaults only:

    ```toml
    project_doc_max_bytes = 65536

    [agents]
    max_depth = 1

    [features]
    hooks = true
    ```

  - Cap `minion` fanout at 6 subagents. `minion` should default to 6 subagents for fanout, cap larger requests at 6, warn on execution fanouts, and state that practical limits are subject to Codex runtime/account/environment constraints.
  - Do not set model, provider, auth, telemetry, network, sandbox, or auto-approval defaults in project config.
  - Ship hooks/rules as opt-in examples, not active enforcement by default.
  - Add `docs/opt-in-configs.md` explaining optional hooks, rules, custom subagents, Codex-Falcon settings, stricter approval/sandbox profiles, and any memory/automation examples. Each entry must explain purpose, risk level, enable steps, disable steps, and verification.
  - Use custom agents only for repeatable delegated roles: `navigator`, `reviewer`, scoped `worker` for `minion`, and optionally `scribe`. `worker` supports report-only analysis and guarded write-capable execution when the steering session assigns disjoint write scopes.
  - Keep workflow orchestration as skills: `brainstormer`, `grill-with-docs`, `product-architect`, `project-planner`, `plan-to-beads-unified`, `session-start`, `session-wrapup`, `minion`, `tdd`, and related workflow skills.
  - `minion` is dual-mode parallel dispatch: explicit Codex subagents, report-only analysis, guarded write-capable execution, file-scope/collision planning before execution, structured reports, transient report files under `.codex/state/tmp/minion-*`, and steering-session synthesis. Defer lock registry, cron/watch, auto-amend, auto-ack, cross-branch orchestration, and PR actions.
  - Adopt secure-by-default, local-first behavior. No network calls, package installs, external service publication, cloud changes, PR creation, comments, deploys, or pushes by default.
  - Disposable install validation should run under `/tmp`. The scaffold must be relocation-safe because the project is expected to move from `/home/echo/ACC` to `/home/echo/dev` after it is built.
  - First produce this Decision Brief, then scaffold the new repo only after user approval.
- **Unresolved decisions:**
  - Whether the executable is implemented as a renamed script `bootstrap`, a thin wrapper around an internal script, or a shell-installed command. The required user-facing invocation is settled: `bootstrap <target> --prefix <PREFIX>`.
  - Exact custom-agent TOML content for `navigator`, `reviewer`, `worker`, and optional `scribe`.
  - Exact contents of `minion` state/report schemas.
  - Exact skill inventory names if two legacy concepts collapse into one Codex-native skill during rewrite.
- **Code/doc contradictions:**
  - Current `../bootstrap-protocol/init-project.sh` copies `.claude/` machinery into target repos and prints `/leroy` next steps. That contradicts the Codex-native-only goal.
  - Current workflow docs refer to `.claude/templates/artifacts/`, `.claude/handoff.yaml`, `.claude/changelog.yaml`, `/leroy`, `/wrapup`, and `/falcon`. These must move to `.agents/templates/`, `docs/*.yaml`, and Codex skills.
  - Current `grill-with-docs` assumes root `CONTEXT.md`. The new fork must rewrite it for `docs/CONTEXT.md`.
  - Current Falcon docs rely on `claude --bg`, `claude agents --json`, `claude rm`, `.claude/tmp`, and Claude settings. These are not portable to Codex and must be redesigned.
  - Current installer treats missing `bd` as a warning and continues. The Codex fork requires Beads and must fail before writes when `bd` is unavailable.
- **CONTEXT.md updates:** None applied during this interview. The new fork must create and maintain `docs/CONTEXT.md` as the canonical glossary path.
- **ADR candidates:**
  - **Codex-native-only fork:** Hard to reverse once users adopt installed paths; surprising without context because the source kit is Claude-first; real trade-off against dual Claude/Codex compatibility.
  - **Canonical glossary at `docs/CONTEXT.md`:** Hard to reverse because every workflow skill must reference it; surprising because the existing skill expects root `CONTEXT.md`; real trade-off between root discoverability and keeping all durable docs under `docs/`.
  - **Beads mandatory:** Hard to reverse because execution workflows depend on tracker presence; surprising because the current script degrades when `bd` is missing; real trade-off between portability and a consistent Beads-first execution contract.
  - **Minion conceptual rewrite:** Hard to reverse if state/report schemas are adopted; surprising because it replaces Falcon while preserving the parallel-dispatch goal; real trade-off between preserving workflow capability and avoiding unsupported Claude primitives.
- **PRD inputs:**
  - **Goal:** Create `/home/echo/ACC/codex-bootstrap-protocol`, a Codex-native scaffold repo that initializes Codex-ready projects with repo-scoped skills, Beads-first planning/execution, Codex subagent workflows, and durable project docs. The repo must be relocation-safe for a later move to `/home/echo/dev`.
  - **Primary users:** The repository owner/operator and future Codex agents working in target projects.
  - **Non-goals:** Claude runtime compatibility, plugin packaging in phase one, auto-installing Beads, enabling aggressive hooks by default, installing local slash prompts as the shared command surface, or making external service changes by default.
  - **Key constraints:** Use official Codex-documented surfaces; keep project config minimal; require `bd`; keep transient state out of Git; avoid network/package-install behavior in the initializer; rewrite all bundled workflow skills away from `.claude/*` paths.
  - **Acceptance signals:**
    - `/home/echo/ACC/codex-bootstrap-protocol` exists as its own repo.
    - `./bootstrap <target> --prefix <PREFIX>` works from the repo checkout, with optional documented symlink/PATH setup.
    - User can run `bootstrap --dry-run <target>` and see planned Codex-native file operations.
    - User can run `bootstrap <target> --prefix <PREFIX>` as the primary CLI.
    - `bootstrap <target> --prefix <PREFIX>` fails before writes if `bd` is missing.
    - With `bd` present, the target gets `AGENTS.md`, `.agents/skills/*`, `.agents/templates/*`, `.codex/config.toml`, `.codex/agents/*.toml`, `.codex/hooks/`, `.codex/rules/`, `docs/CONTEXT.md`, `docs/adr/`, `docs/prd.md`, `docs/project-plan.md`, `docs/architecture.md`, `docs/backend.md`, `docs/frontend.md`, `docs/data-model.md`, `docs/security.md`, `docs/handoff.yaml`, `docs/changelog.yaml`, `docs/enhancements.md`, `docs/standards-history.md`, `.beads/`, and `.archive/`.
    - All bundled workflow skills are rewritten away from live `.claude/*` runtime dependencies.
    - `minion` is redesigned around Codex subagents, defaults to 6-way fanout, caps fanout at 6 workers, and warns on execution fanouts.
    - `docs/opt-in-configs.md` explains optional configs, purpose, risk, enable/disable steps, and verification.
    - Verification includes shell syntax checks, scoped path/reference scans showing no live `.claude` runtime dependencies in installed Codex runtime assets, scoped relocation-safety checks for hardcoded `/home/echo/ACC` runtime paths, and disposable `/tmp` install/readback.
  - **Risks:** Over-porting Claude-specific assumptions; making the first fork too broad; Beads dependency blocking users without clear instructions; Codex hooks requiring trust review; `.codex/config.toml` ignored in untrusted projects; skill path rewrites missing hidden references.
  - **Assumptions:** The first scaffold is local-first and WSL-friendly. Codex docs are the source of truth for runtime surfaces. The source `bootstrap-protocol` tree remains available as migration reference during implementation. The initial build may happen under `/home/echo/ACC`, but the finished repo should be movable to `/home/echo/dev` without code or docs changes beyond path examples.
- **Recommended next skill:** `product-architect` after user approval of this Decision Brief. If approved, use this brief to draft `docs/prd.md` for the new `codex-bootstrap-protocol` repo before implementation planning.
