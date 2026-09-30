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

- **Source opportunity:** Not provided. This brief comes from a `grill-with-docs` review of the existing `bootstrap` script and desired operator workflow.

- **Problem statement:** The current `bootstrap` script is a non-interactive installer that accepts `--dry-run`, `--force`, `--prefix`, and a target path. It safely installs the managed scaffold tree, but it does not first check recommended global skills, ask whether to install or update them, ask whether the target is a new or existing project, or expose a distinct existing-project conversion flow. The operator wants a human-friendly wizard while preserving automation-safe CLI behavior.

- **Resolved terminology:**
  - **Recommended Global Skills:** Reusable workflow skills installed under `$HOME/.agents/skills` for personal use across projects. The v1 recommended set is `brainstormer`, `grill-with-docs`, `product-architect`, `project-planner`, `plan-to-beads-unified`, `tdd`, and `minion`.
  - **Target-Local Skills:** Skills installed under a target repo's `.agents/skills` so the project remains self-contained and portable.
  - **Non-Destructive Retrofit:** Existing-project conversion mode that applies the managed scaffold contract without deleting project-specific files and blocks on conflicts by default.
  - **Managed Scaffold Contract:** The file and directory set declared by `assets/scaffold/manifest.txt`; only those paths are managed by `bootstrap`.

- **Resolved decisions:**
  - `bootstrap` should gain an interactive wizard as the default for human use when required choices are missing.
  - Existing non-interactive invocation must keep working for agents and scripts.
  - Add explicit `--interactive` and `--non-interactive` flags.
  - In CI or non-TTY contexts, default to non-interactive behavior.
  - Global skill checking happens before target project mode selection.
  - Global skill install/update is optional and non-blocking.
  - Global skill install/update should be performed by `bootstrap` after confirmation, not merely printed as commands.
  - Global skill source should be `assets/scaffold/.agents/skills/<name>`, not repo-root `.agents/skills/<name>`.
  - The recommended global skill list should be a small explicit v1 list in `bootstrap`.
  - If a recommended global skill is missing, ask whether to install it.
  - If a recommended global skill exists but differs from scaffold-owned source files, ask whether to update it.
  - If a recommended global skill is current, report it as up to date.
  - Preserve destination-only extras in global skill directories unless they directly conflict with scaffold-owned files.
  - Target-local skills should still be installed or updated as part of the managed scaffold contract even when global skill install/update is skipped.
  - `session-start` and `session-wrapup` remain target-local by default and are not part of the recommended global skill set.
  - Existing-project conversion means non-destructive retrofit using the same managed scaffold contract as a new install.
  - For an existing target, validate existing `.beads/` instead of replacing it.
  - Never overwrite `.git/`, `.beads/`, credentials, symlinks, transient state contents, or unmanaged files.
  - Existing-project conflicts remain all-or-nothing for v1; do not add per-file merge prompts.
  - `--force` can overwrite managed scaffold files only, preserving the current safety model.
  - Interactive mode should detect whether a target is new or existing, then ask for confirmation.
  - New project means the target path does not exist or exists and is empty.
  - Existing project means the target path exists and contains any files.
  - Interactive mode should suggest a default prefix from the target directory name and allow override.
  - Non-interactive mode should keep requiring `--prefix <PREFIX>` when Beads initialization is needed.
  - Interactive mode should always show a dry-run-style plan before writing and ask for final confirmation.
  - After install or retrofit, `bootstrap` should write a lightweight project-local completion note into target docs, without storing private global machine details.

- **Unresolved decisions:**
  - Exact flag names beyond `--interactive` and `--non-interactive` are not fully settled. Candidate flags from the session were `--mode new|existing`, `--target <path>`, and `--global-skills ask|install|update|skip`.
  - Exact prefix derivation algorithm is not fully specified beyond examples such as `mission-control -> MC` and `codex-bootstrap-protocol -> CBP`.
  - Exact target-doc update schema for install/retrofit completion needs product specification. Current target files provide `docs/changelog.yaml` and `docs/handoff.yaml` minimal schemas.
  - Whether global skill checking should support a machine-readable report mode is not decided.

- **Code/doc contradictions:**
  - Current `bootstrap` only supports non-interactive CLI behavior and does not implement the wizard.
  - Current `bootstrap` has no global skill detection, install, or update path.
  - Current `bootstrap` does not expose separate `new` versus `existing` modes; it treats all targets through the same managed-path planner.
  - Current README explains how to bootstrap a new project, but it does not describe the proposed global-skill preflight or interactive existing-project conversion.
  - `docs/CONTEXT.md` did not exist before this grilling session; it has now been created with the resolved terms.

- **CONTEXT.md updates:** Added `docs/CONTEXT.md` with canonical definitions for Recommended Global Skills, Target-Local Skills, Non-Destructive Retrofit, and Managed Scaffold Contract.

- **ADR candidates:**
  - `Interactive Bootstrap Wizard With Optional Global Skill Management`: Candidate ADR because it changes the public CLI shape, separates personal global skills from target-local portability, and preserves non-interactive automation as a deliberate trade-off. Create an ADR if this design proceeds to implementation.

- **PRD inputs:**
  - **Goal:** Make `bootstrap` a guided operator workflow that checks recommended global skills, optionally installs or updates them, asks whether the target is new or existing, previews the managed-path plan, and then performs a safe new install or non-destructive retrofit.
  - **Non-goals:** Do not make target projects depend on global skills. Do not add per-file merge prompts in v1. Do not make global skill updates mandatory. Do not remove the existing non-interactive install path. Do not overwrite protected paths.
  - **Functional requirements:**
    - Interactive mode checks recommended global skills first.
    - Interactive mode asks install/update/skip for missing or outdated global skills.
    - Interactive mode detects target state and asks new versus existing confirmation.
    - Interactive mode suggests a prefix and allows override.
    - Interactive mode prints a dry-run-style plan before writes.
    - Interactive mode asks for final confirmation before real install or retrofit.
    - Existing-project retrofit applies the same managed scaffold contract and blocks on conflicts by default.
    - Non-interactive mode preserves current automation-safe behavior and supports explicit future flags.
  - **Constraints:** Bash/WSL friendly; no network calls; no package installs; no credential access; no global writes without confirmation; no destructive operations against protected paths; preserve relocation safety.
  - **Assumptions:** `bd` remains mandatory for real target setup. Recommended global skills are copied from `assets/scaffold/.agents/skills`. Global skill destination is `$HOME/.agents/skills`.
  - **Risks:** Interactive Bash flows can become complex; global home-directory writes need clear prompts and dry-run behavior; prefix derivation can be surprising if not previewed; existing-project retrofits can create trust issues if conflict reports are unclear.
  - **Acceptance signals:**
    - `./bootstrap` in a TTY enters the wizard when required choices are missing.
    - `./bootstrap --non-interactive <target> --prefix <PREFIX>` does not prompt.
    - `./bootstrap --dry-run <target> --prefix <PREFIX>` remains write-free.
    - Missing global skills are detected and can be installed after confirmation.
    - Outdated global skills are detected by content comparison and can be updated after confirmation.
    - Destination-only global skill extras are preserved.
    - Existing non-empty targets are identified as existing-project retrofits before writes.
    - Existing-project conflicts block by default and can only be overwritten through all-or-nothing managed-file `--force`.
    - Target-local skills are installed even if global skill updates are skipped.
    - Install/retrofit completion is recorded lightly in target docs.

- **Recommended next skill:** `product-architect` should turn this approved Decision Brief into a PRD update for the `bootstrap` CLI wizard and conversion flow.
