---
name: github-readme-writer
description: Create, rewrite or update a repository's README.md. Scans the repo (stack, file tree, scripts, remote URL) and fills a standard README skeleton adapted to the repo type. Use when the user asks to write, generate, initialize, rewrite or update a README, or any section of one. Not for other documentation such as wikis, onboarding guides, changelogs, tutorials or API docs (use technical-writer), and not for style-only rewrites into STE (use ste-writing).
---

# GitHub README Writer

## Purpose

To autonomously analyze a local repository, accurately detect its architecture and dependencies, and write an elite, standards-grade `README.md` from a standard skeleton. Owns `README.md` only (create, rewrite, update a section). Works for any repo archetype (application, library, IaC, docs/intel hub, dataset) — not just runnable applications.

## Process

1. **Analyze Requirements:** Review the user's prompt for specific highlights, such as focusing on a particular API or Docker setup.
2. **Scan Repository:** Run the repository scanner to map the structure, detect the stack (manifests, Docker/Compose, Terraform, Ansible, Make, conda) and list `package.json` / `[project.scripts]` script names. In a git repo it lists files with `git ls-files`, so ignored files (e.g. `.env`) never appear.
   - Command: `python3 <this skill's base directory>/scripts/repo_scanner.py --dir <repo root>` (Codex prints "Base directory for this skill" when the skill loads; `--depth N` widens the tree, default 2).
3. **Synthesize Context & Classify Archetype:** Process the scanner output to identify the primary language, framework, and architectural patterns. **When `detected_stack` is empty** (no `package.json`/`pyproject.toml`/etc.), classify the repo by its contents into an archetype and adapt accordingly — do NOT force application semantics onto a non-app repo:
   - **application** → runnable: Installation = deps + run; Usage = run command.
   - **library** → Installation = package install; Usage = import/API example.
   - **IaC / infra** → Installation = clone + tooling (e.g. pre-commit, Ansible deps); Usage = "how you operate it" (apply playbooks, follow the runbook), not a single run command.
   - **docs / intel / planning hub** → Installation = clone + bootstrap (e.g. `bd bootstrap`); Usage = how the docs/workflow are consumed.
   - **dataset** → Installation = how to obtain/load; Usage = schema + access example.
4. **Load Skeleton:** Read `references/readme_template.md`. It is a skeleton, not a rendered template: each `{{ field }}` marker is a slot you fill by hand, and `| default("...")` shows the fallback text for that slot. Nothing renders it.
5. **Identify Gaps:** Determine if critical fields (usage examples, installation commands) are clear from the code; if not, infer them from the archetype's pattern or the prompt. Fill `installation_intro` / `usage_intro` / `contributing_section` / `license_section` to match the archetype rather than leaving app-centric defaults.
6. **Architect Content:** Prepare the content for each slot (name, description, tech stack, installation, usage, file tree, contributing, license, etc.). Take install/run commands from the scanner's `scripts` and the repo's real files. **Clone URL:** fill `repository_url` from the scanner's `remote_url` (credentials already stripped) or `git remote get-url origin`; never leave a placeholder URL and never write a URL with embedded credentials. No `origin` remote → ask the user. **Badges:** if `detected_stack` is empty, populate `tech_stack_badges` with fallback badges (visibility, license, status) instead of leaving it blank. **Contributing:** use the fork→PR flow only for repos open to outside contribution; for private/single-operator repos write a short note on how work is actually tracked (e.g. "tracked as beads; no external PRs").
7. **Write README:** Create or update `README.md` from the filled skeleton. No `{{ ... }}` marker may remain. For an update of one section, change only that section. Prose follows the `ste-writing` STE-flavored mode (short sentences, active voice, one name per thing).
8. **Finalize — License (accuracy-critical):** NEVER assert a license that isn't true. Determine `license_section` as follows:
   - A `LICENSE`/`LICENSE.md` file exists → name that license, link the file.
   - No license file AND the repo is **private** (check `gh repo view --json isPrivate,visibility`, or ask if `gh` is unavailable) → write **"Proprietary — all rights reserved"** and note no `LICENSE` file is present by design.
   - No license file AND the repo is **public** → do NOT default to MIT silently; ask the user which license, or write a flagged placeholder (`<!-- TODO: choose a license -->`) and surface it for review.
   Then provide the file for human verification.

## Constraints

- **DO NOT** guess or hallucinate installation commands; use actual scripts found in the codebase.
- **DO NOT** alter any files in the workspace other than `README.md`.
- **DO NOT** deviate from the H2 headers specified in the skeleton — but DO adapt each section's *content* to the repo archetype (Step 3). Keep the headers; don't force app/run-command/fork-PR semantics onto an IaC, docs, or private repo.
- **NEVER** assert a license the repo does not actually have. No `LICENSE` + private repo → "Proprietary — all rights reserved"; no `LICENSE` + public → ask or flag a TODO. Do NOT silently default to MIT.
- **NEVER** generate the README without first grounding the content in the repository scan and skeleton.
