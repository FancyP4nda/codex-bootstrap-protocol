# Opt-In Configuration Guide

This guide documents optional Codex configuration patterns for projects created by Codex Bootstrap Protocol. Nothing in this repo automatically enables these settings, edits your shell profile, installs packages, calls the network, changes Git remotes, or mutates global Codex configuration.

Use the default scaffold first. Enable an optional control only when the target project needs it and the operator accepts the risk.

## Relocation And Paths

The scaffold should be relocation-safe. It may be checked out today at an example path such as `/home/echo/ACC/codex-bootstrap-protocol`, but installed targets and scripts should resolve paths relative to the repo or script root. Do not hardcode `/home/echo/ACC` in runtime logic after the repo moves.

## Optional PATH Or Symlink

Purpose: Run the bootstrap command from outside this checkout.

Risk level: Low. The main risk is invoking the wrong checkout if the symlink points at a stale repo.

Enable steps:

```bash
mkdir -p "$HOME/.local/bin"
ln -s "$(pwd)/bootstrap" "$HOME/.local/bin/codex-bootstrap"
codex-bootstrap --help
```

Disable steps:

```bash
rm -f "$HOME/.local/bin/codex-bootstrap"
hash -r
```

Verify:

```bash
command -v codex-bootstrap
codex-bootstrap --help
```

## Hooks

Purpose: Add project-local checks that run around selected Codex actions, such as validating generated files, blocking accidental secret exposure, or reminding agents about required verification.

Risk level: Medium. Hooks can interrupt workflows, produce noisy failures, or hide the real failure if they are too broad. Treat hook scripts as executable code and review them before enabling.

Enable steps:

1. Review hook examples under the installed `.codex/hooks/` directory.
2. Copy the selected example to the active hook path for the target project.
3. Enable hooks in project `.codex/config.toml` only after the project is trusted.
4. Keep hook commands local-only unless the operator explicitly approves network or external service access.

Disable steps:

1. Remove or comment the hook entry in `.codex/config.toml`.
2. Move the hook script out of the active hook path or rename it with a `.disabled` suffix.
3. Restart Codex in the target repo if the setting is not picked up automatically.

Verify:

```bash
rg -n "hooks|features" .codex/config.toml .codex/hooks
```

Then run the smallest command expected to trigger the hook and confirm the output is local, actionable, and free of secrets.

## Rules

Purpose: Add project-local Codex rules for recurring local constraints, such as no active `.claude/` runtime paths, no network actions by default, required Beads usage, or protected overwrite paths.

Risk level: Low to Medium. Rules can improve consistency, but stale or overbroad rules can block legitimate work or duplicate `AGENTS.md` guidance.

Enable steps:

1. Review examples under the installed `.codex/rules/` directory.
2. Keep each rule narrow and project-specific.
3. Prefer rules for recurring constraints, not one-off task instructions.
4. Relaunch Codex in the target repo if needed so project-local rules are loaded.

Disable steps:

1. Delete the rule file or rename it with a `.disabled` suffix.
2. Remove any reference from related project docs.
3. Relaunch Codex if the old rule still appears active.

Verify:

```bash
rg -n "bd|bootstrap|network|\\.claude|force|managed" .codex/rules AGENTS.md
```

## Custom Subagents

Purpose: Define repeatable delegated roles under `.codex/agents/`, such as navigator, reviewer, scoped worker, or scribe.

Risk level: Medium. Subagents can multiply token use and may produce conflicting recommendations if their role instructions overlap. Write-capable subagent fanout needs explicit collision-domain planning.

Enable steps:

1. Review each `.codex/agents/*.toml` file before use.
2. Confirm each agent has a clear `name`, `description`, and `developer_instructions`.
3. Keep provider, model, auth, telemetry, sandbox, and approval assumptions out of project agent files unless the operator intentionally opts in.
4. Ask Codex to use the specific custom agent by role when the task needs delegation.

Disable steps:

1. Rename the agent TOML file with a `.disabled` suffix or remove it from `.codex/agents/`.
2. Remove references to that role from related skills or docs.
3. Relaunch Codex in the target repo if the role still appears available.

Verify:

```bash
rg -n "name|description|developer_instructions|model|provider|auth|approval|sandbox" .codex/agents
```

Expected result: required fields are present, and any provider/model/auth/approval/sandbox settings are intentional and documented.

## Minion Settings

Purpose: Configure the `minion` workflow for explicit subagent fanout. `minion` supports report-only analysis and guarded write-capable execution when the operator explicitly asks for implementation, fixes, refactors, migrations, or Beads work.

Risk level: High for execution mode. Fanout increases token use, approval volume, synthesis overhead, merge work, and the chance of conflicting edits. Execution fanout is capped at 6 workers and remains subject to Codex runtime, account, environment, sandbox, approval, token, and local resource limits.

Enable steps:

1. Confirm `.agents/skills/minion/SKILL.md` exists in the target project.
2. Confirm `.codex/agents/worker.toml` exists in the target project.
3. Keep transient reports under `.codex/state/tmp/minion-*`.
4. Use the default 6-way fanout unless the task justifies fewer workers.
5. For execution mode, assign disjoint write scopes and keep commits, pushes, and Beads closeout in the steering session.

Disable steps:

1. Do not invoke the `minion` skill for the task.
2. Rename or remove `.agents/skills/minion/` if a target project should not expose the workflow.
3. Remove or disable the worker agent if it should not be used.
4. Clear stale transient reports from `.codex/state/tmp/` when they are no longer needed.

Verify:

```bash
rg -n "minion|6|report-only|execution|write scope|\\.codex/state/tmp/minion" .agents/skills .codex/agents docs
```

Expected result: execution fanout is capped at 6 workers, worker prompts require disjoint write scopes, worker agents do not commit or push, Beads closeout stays coordinated by the steering session, and transient reports stay in gitignored state paths.

## Stricter Approval And Sandbox Profiles

Purpose: Let a target project opt into tighter command approval or filesystem sandboxing when the project has higher-risk code, credentials, production data, or sensitive workflows.

Risk level: Medium to High. Stricter profiles can block useful commands and slow implementation. Looser profiles can allow dangerous writes or external actions. Do not change global Codex configuration from this scaffold.

Enable steps:

1. Decide the project-specific approval and sandbox policy outside this scaffold.
2. Add only the minimum project-local settings needed in `.codex/config.toml`.
3. Document why the profile is needed in project docs.
4. Avoid enabling network, package install, cloud, destructive file, or external publication actions by default.

Disable steps:

1. Remove the project-local profile entries from `.codex/config.toml`.
2. Keep a note in project docs if the profile was removed because it blocked normal development.
3. Restart Codex in the target repo.

Verify:

```bash
rg -n "approval|sandbox|network|install|cloud|push|force" .codex/config.toml AGENTS.md docs
```

Expected result: project-local profile choices are explicit, narrow, and do not silently enable external actions.

## Memory Examples

Purpose: Show operators where durable project knowledge belongs and how to keep generated memory separate from project source of truth.

Risk level: Medium. Memory can become stale, duplicate source docs, or accidentally capture personal or sensitive context.

Enable steps:

1. Prefer durable project state under `docs/`, especially `docs/CONTEXT.md`, ADRs, handoff files, and changelogs.
2. Add only examples that explain how Codex should read project docs; do not copy private profile material into scaffold docs.
3. Keep generated memory and user profile notes outside installed project assets unless the operator explicitly opts in.

Disable steps:

1. Remove memory examples from target docs if they duplicate project source of truth.
2. Delete local generated memory notes through the relevant local memory mechanism, not through this scaffold.
3. Keep sensitive personal context out of repo-tracked files.

Verify:

```bash
rg -n "memory|CONTEXT.md|handoff|changelog|profile|personal" docs AGENTS.md
```

Expected result: project memory guidance points to repo docs and does not require generated memory to operate.

## Automation Examples Intentionally Not Shipped

Purpose: Make clear which automation patterns are out of scope for the first Codex-native scaffold.

Risk level: High if added casually. Background automation can mutate code, create remote side effects, or hide approval boundaries.

Enable steps:

1. Do not enable these in v1 by default.
2. If a future project needs automation, write a separate design note with trigger, permissions, rollback, logs, and operator approval boundaries.
3. Add automation only through an explicit future bead with tests and docs.

Disable steps:

1. Remove cron/watch scripts, auto-amend behavior, auto-ack behavior, remote PR automation, and external publication scripts from active paths.
2. Remove references from `.codex/config.toml`, hooks, rules, and skills.
3. Confirm no background process remains active.

Verify:

```bash
rg -n "cron|watch|auto-amend|auto-ack|pull request|PR|network|publish|deploy" .agents .codex docs
```

Expected result: any matches are explicit deferred-scope documentation, not active v1 behavior.

## No Auto Installs Or Network Actions

Purpose: Preserve local-first, operator-controlled behavior.

Risk level: Low when followed, High if ignored.

Enable steps:

1. Keep install docs manual and explicit.
2. Require operator approval before package installs, network calls, cloud calls, remote Git changes, or external publication.
3. Keep dry-run local and side-effect free.

Disable steps:

1. Remove any scaffold script or hook that installs dependencies automatically.
2. Remove network or cloud commands from default verification.
3. Document manual setup steps instead of running them.

Verify:

```bash
rg -n "curl|wget|npm install|pip install|apt-get|gcloud|git push|network|auto install" README.md docs .codex .agents
```

Expected result: matches are documentation examples or explicit non-default warnings, not default executable behavior.
