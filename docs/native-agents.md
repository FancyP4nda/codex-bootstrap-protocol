# Native roles and client compatibility

The kit ships documented standalone TOML agents with name, description,
developer_instructions and explicit sandbox modes. They inherit the user's model.
Ask a role-capable Codex client to use the named role, honoring live parent
permission overrides. Do not claim prose alone enforces read-only access.

On the tested Codex CLI 0.159.2, authenticated exec exposed a generic spawn
interface without a native-role selector. Reading a TOML and pasting its prose
into that interface does not verify native sandbox loading. The compatibility
helper instead parses the same canonical TOML and passes its instructions and
safe settings through supported native Codex exec config overrides:

```bash
python3 ~/.agents/bootstrap/scripts/run-agent.py --root <repo> --role reviewer --prompt-file <bounded-prompt>
# With --local-core:
python3 <repo>/.agents/bootstrap/scripts/run-agent.py --root <repo> --role herald-a11y --prompt-file <bounded-prompt>
```

Use --dry-run to inspect exact flags, --read-only to tighten any role, and
--isolated to exclude personal configuration while retaining existing auth.
This is an explicit separate CLI session, not a claim that generic spawn selected
a native role. It requires authorized delegation, uses the existing login,
disables lifecycle hooks for this isolated task, never bypasses sandbox/trust,
refuses unsafe modes/unknown settings and changes no persistent configuration.
Workers remain subject to steering-assigned scopes and integration ownership.

The authenticated smoke validates this native-config path; TOML schema checks
cover all ten roles. Native named-role spawning remains client-dependent. The
official standalone-file format is retained for clients exposing role selection.
