# Opt-in native configuration

No model, approval bypass or trust record is installed. Global core is automatic, personal configuration is not.

`--status-line` targets [tui] status_line with model-with-reasoning, context-remaining, git-branch and current-dir. `--notifications` enables native attention notifications. `--docs-mcp` adds the official documentation MCP URL; OAuth/API authentication is a separate user action. Never commit secrets.

`--hooks` installs a bounded read-only SessionStart helper and hooks.json. It supports startup/resume/clear/compact orientation and emits documented hookSpecificOutput additionalContext. It reads durable context/handoff/changelog; missing scaffold/Beads falls back to ordinary Git. It does not claim issues, edit documents or contact a network.

By default options apply to the project's .codex. `--promote-global` moves selected settings to CODEX_HOME, showing the diff and backing up changes. A global bootstrap orientation hook suppresses installation of a duplicate project hook. Existing project orientation must be reconciled before global promotion. JSON preserves unrelated groups; inline TOML hooks are a fail-closed conflict.

Once chosen, optional global settings/helpers are tracked separately from
exclusively owned core. A later `--update-global` without the same flags retains
them, including user changes; omission is not disable/uninstall consent. Merged
configuration is never retired as a core file. To disable a hook, review and
disable its definition through Codex `/hooks`; preserve unrelated handlers and
configuration. There is no implied blanket personal-config uninstall command.

Codex ignores untrusted project configuration. Trust the project through Codex and review new/changed hook hashes with /hooks. Installation does not consent on the user's behalf. Native agents inherit the user's model; read-only reviewers/navigators and scoped write-capable workers use explicit sandbox modes.

Official references: [configuration](https://developers.openai.com/codex/config-reference/), [hooks](https://developers.openai.com/codex/hooks/), [agents](https://developers.openai.com/codex/subagents/), [skills](https://developers.openai.com/codex/skills/), [MCP](https://developers.openai.com/codex/mcp/).
