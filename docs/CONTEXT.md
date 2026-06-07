# Context

Codex Bootstrap Protocol is a local-first scaffold for initializing or
retrofitting projects with Codex-native workflow assets, Beads task tracking,
and durable project documentation.

## Language

**Recommended Global Skills:**
Reusable workflow skills that may be installed under `$HOME/.agents/skills` for
personal use across projects. The current recommended set is `brainstormer`,
`grill-with-docs`, `product-architect`, `project-planner`,
`plan-to-beads-unified`, `tdd`, and `minion`.
_Avoid_: Target-local skills, session lifecycle skills

**Target-Local Skills:**
Skills installed into a target project under `.agents/skills` so the project is
self-contained and portable. Target-local skills are installed or updated by the
bootstrap managed scaffold contract even when global skill updates are skipped.
_Avoid_: Global-only workflow dependency

**Non-Destructive Retrofit:**
The existing-project conversion mode. It adds or updates managed scaffold files,
preserves existing project-specific files, validates existing Beads state, and
blocks on managed-file conflicts unless explicit all-or-nothing `--force` is
used.
_Avoid_: Migration, overwrite conversion

**Managed Scaffold Contract:**
The set of files and directories declared by `assets/scaffold/manifest.txt`.
Bootstrap may create or update these paths, but protected paths such as `.git/`,
`.beads/`, credentials, symlinks, transient state contents, and unmanaged files
are outside the overwrite contract.
_Avoid_: Whole-repo overwrite
