# Optional native configuration

Use codex-bootstrap with --status-line, --notifications, --hooks or --docs-mcp
to prepare selected settings. Personal promotion is explicit --promote-global;
the default is project-local configuration with preserved unrelated settings.
Inspect the combined preview and backed-up changes before use.

The native footer shows model/reasoning, context remaining, branch and directory.
Notifications use native TUI attention alerts. Documentation MCP uses the official
server URL; authentication is separate and secrets never belong in tracked files.

Trust the project through Codex and review new/changed hooks with /hooks.
The installer never trusts hooks. JSON hooks are advisory; inline TOML hooks
cannot compete with hooks.json in the same layer. Orientation supports
startup/resume/clear/compact and reads bounded durable context without edits.

Global skills are normally under ~/.agents/skills and native agents under
CODEX_HOME/agents. --local-core installs the same core inside this repository.
Use $minion only for requested delegation, with disjoint write scopes and
steering-owned Beads, verification, integration and publication. Native sandbox
and approval controls enforce permissions; skill prose does not.

Standards under .agents/bootstrap/instructions are referenced Markdown, not
execution-policy .rules files. No security bypass, hardcoded model, automatic
package install or implicit network operation is enabled by bootstrap.

Falcon's optional polling monitor must be explicitly started/stopped; it is not
a persistent service. Web-design remains unverified even after install consent.

Official interfaces: https://developers.openai.com/codex/config-reference/,
https://developers.openai.com/codex/hooks/, https://developers.openai.com/codex/subagents/.
