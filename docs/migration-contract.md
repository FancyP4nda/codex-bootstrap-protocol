# Complete migration contract

This contract supersedes the older repo-local-only assumptions in the original
PRD, project plan and wizard brief. The authoritative source is the sibling
`claude-bootstrap-protocol` at commit
`f89f7f3dffb1150fa7df30b180b397dd25a711f9`. No source history, Beads data,
credentials, caches or planning history is imported.

The Bash installer reuses the source manifest engine, with stricter preflight
for all layers. Core skills default to `~/.agents/skills`; native agents use
`${CODEX_HOME:-~/.codex}/agents`. `--local-core` installs those same canonical
payloads in the project. Personal UI, lifecycle hooks and docs MCP are opt-in.
Hooks are never trusted by the installer. Project guidance lives in `AGENTS.md`,
development standards in referenced Markdown and runtime state in ignored
`.codex/state/tmp`. Existing target Claude files are preserved.

Every source payload is mapped in `source-inventory.json`; non-runtime source
helpers are retained as tooling or explicitly replaced with a native interface.
The destination's minion workflow and history remain. Skills use Codex `$name`
invocation and native agents have name, description, developer_instructions and
appropriate sandbox permissions, with no model pin.

One combined preflight precedes all project/global writes. Malformed manifests,
protected paths, collisions, symlinks and structural conflicts fail closed.
Managed overwrites require the relevant explicit update flag and backups.
Unmanaged content and durable documentation are preserved. Obsolete global
files are removed only on explicit update and only at the recorded hash.
Dry-run neither prompts nor launches and writes no target or user config.

Falcon uses local Codex CLI workers in isolated worktrees and a stoppable polling
process, defaulting to 30 seconds. It installs no service. Remote dispatch is
explicit. Steering owns integration and PR actions. Optional read-only Claude
review advises the Codex owner; isolated Codex review is the labeled fallback.

Web-design retains upstream commits, licenses and incomplete evidence. Its
installation requires `--allow-unverified-pack` or explicit wizard acknowledgment.
Migration digests establish integrity, never substitute for release evidence.

Acceptance evidence must cover isolated installer/configuration/command/pack
tests, native CLI configuration/discovery, ordinary-repo session fallback and a
disposable authenticated session. Remaining integration limits must be reported
without claiming an unperformed check passed. Distribution is local; plugin
publication is deferred. Beads is required for project bootstrap, not global
setup; bootstrap installs no prerequisites and makes no network calls.

Official interfaces checked on 2026-09-30 against CLI 0.159.2:

- [Skills](https://developers.openai.com/codex/skills)
- [Custom agents](https://developers.openai.com/codex/subagents)
- [Hooks, payloads and trust](https://developers.openai.com/codex/hooks)
- [Configuration](https://developers.openai.com/codex/config-reference)
- [Project instructions](https://developers.openai.com/codex/guides/agents-md)

Implementation order: contract → installer → core workflows → native config →
packs → command/wizard → release verification. Work is tracked under Beads epic
`codex-bootstrap-protocol-ung` and its four scoped children.
