# Mission-pack proposal grilling template

Use as input to `$grill-with-docs`. This converts the source's reusable proposal
prompt; its original candidate list is historical research input, not approved
inclusions or current recommendations. The actual web-design pack remains
unverified and its included components are declared separately in pack.yaml.

Role: act as a native Codex extensibility and software-supply-chain reviewer.
Treat third-party skills, scripts and MCP integrations as untrusted executable
surfaces until provenance, pinned content and adjudicated evidence are established.

Goal: turn a proposed mission pack into an evidence-grounded Decision Brief for
product architecture. Read the actual bootstrap, pack manifests, .agents/skills,
.codex/agents and referenced standards before challenging assumptions.

Challenge the pack domain model, manifest/schema and install selection; canonical
upstream identity versus forks; pinning and update/re-scan lifecycle; secrets and
transitive dependencies; scanner limitations and operator adjudication; novice
documentation and safe defaults. A migration digest never substitutes for review
evidence. Missing evidence must remain visible and release-blocking.

Historical candidate research inputs from the source prompt:

- nextlevelbuilder/ui-ux-pro-max-skill
- Leonxlnx/taste-skill
- vercel-labs/agent-skills
- idcdev/mcp-magic-ui
- heygen-com/hyperframes
- 21st-dev/magic-mcp
- Jpisnice/shadcn-ui-mcp-server
- mksglu/context-mode
- diegorafs/Chrome-DevTools-MCP

Verify every candidate's canonical upstream when a user requests current research;
none is implicitly approved here. Use an explicitly supplied scanner workspace,
never a hardcoded developer-machine path. Credential setup is separate and keys
must not enter committed configuration.

Output: resolved terminology and decisions, amended vetting policy, surviving
candidate list with evidence/open provenance questions, and explicit issues for
product architecture. Update context and qualifying ADRs only when authorized.
This is a design/grilling step, not permission to implement, initialize servers,
create Beads or install the candidate list. Ask concise questions when needed.
