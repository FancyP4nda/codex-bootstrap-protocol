# Web-Design Pack: Component Notes

Per-component usage, setup, and what each vendored component runs on your machine.

> **Vetting status: pre-airlock.** The components below are vendored at pinned upstream commits but have **not** completed airlock scan and operator adjudication. `pack.yaml` carries null evidence fields, so this pack is schema-valid and release-invalid by design: it will not earn a `pack.stamp`. Treat it as a working development pack, not a released one. See "Vetting status" at the end.

---

## Impeccable

| | |
|---|---|
| Upstream | https://github.com/pbakaus/impeccable |
| Pinned commit | `d272b9bd5dcfcb52d32482d192d06045ca31c503` |
| License | Apache-2.0 |
| Installed at | `.agents/skills/impeccable/` |
| Vendored subset | `SKILL.md`, `reference/`, `scripts/` |
| Requires | Node.js |
| Requires a key | No |

The primary design engine. One skill exposing 23 commands across five categories:

- **Build:** `shape`, `init`, `document`, `extract`
- **Evaluate:** `critique`, `audit`
- **Refine:** `polish`, `bolder`, `quieter`, `distill`, `harden`, `onboard`
- **Enhance:** `animate`, `colorize`, `typeset`, `layout`, `delight`, `overdrive`
- **Fix:** `clarify`, `adapt`, `optimize`
- **Iterate:** `live`

Each command has a playbook in `.agents/skills/impeccable/reference/`. Invoking with no argument prints a context-aware menu rather than guessing.

### Setup

Run once per session, from your project root:

```bash
node .agents/skills/impeccable/scripts/context.mjs
```

This loads `PRODUCT.md`, `DESIGN.md`, and the matching surface brief. The skill's own instructions say not to rerun it. On a new project with no `PRODUCT.md`, run `/impeccable init` first to capture durable product context.

### Executable surface

Impeccable is not a documentation-only skill. It vendors roughly 2.6 MB of Node under `scripts/`, and you should know what that includes before you enable any of it:

| Script group | What it does |
|---|---|
| `hook-*.mjs` | Codex hooks that run a design detector after UI file edits and surface findings |
| `live-*.mjs`, `live-browser.js` | Local HTTP dev server plus a bundled browser-automation runtime for `live` mode |
| `context.mjs`, `doctor.mjs`, `pin.mjs` | Session context loading, drift repair, and `/command` shortcut registration |
| `generate-image.mjs` | Image generation, which calls whichever backend you configure |

Three things worth knowing:

1. **Hooks are opt-in and off until you turn them on.** `/impeccable hooks on|off|status` controls them. Once on, they execute after UI file edits. Leave them off until you want that.
2. **`live` mode starts a local server and drives a browser.** It binds `127.0.0.1` only and injects into the page under edit. Run it only against your own project.
3. **Skill prose is not permission enforcement.** Native Codex sandbox, approval and execution-policy settings govern access. The migration removes misleading allowed-tools declarations.

### Set these before first use

Vendor update pings and concept-choice telemetry default off in this migration. These environment variables also explicitly disable them:

```bash
export IMPECCABLE_NO_UPDATE_CHECK=1   # stops the per-session update ping to impeccable.style
export IMPECCABLE_NO_TELEMETRY=1      # stops the concept-choice ping (DO_NOT_TRACK=1 also works)
```

Also note: if `OPENAI_API_KEY` is set in your environment, `scripts/generate-image.mjs` can spend that credit against `api.openai.com`.

### Triage findings (2026-07-26)

A targeted human read of the executable surface was performed before airlock. **No malicious behavior was found.** Full detail and the adjudication checklist live on bead `z7f`; the open telemetry-payload question is `saa`.

What the code does well: `live-server` binds loopback only and validates origins by exact hostname (defeating `localhost.evil.com` substring attacks); there is **no `eval` or `new Function` anywhere** in the tree; **the edit hook makes no network calls at all**, so the file contents it inspects never leave the machine; it explicitly skips `.env`, `.git/`, `id_rsa*`, `*.pem`, and `*secret*`/`*credential*` files; the audit log is local-only and off unless configured.

What needs a decision at gate time:

| # | Finding | Location |
|---|---|---|
| F1 | Migration replaced filename interpolation in is-generated with argv execution; live's remaining hardcoded shell command is still a review surface. | `lib/is-generated.mjs`, `live.mjs` |
| F2 | Update check now defaults disabled; explicit re-enabling remains optional outbound behavior. | `context.mjs` |
| F3 | Vendor choice ping now defaults disabled. | `concept-seed.mjs` |
| F4 | Reads `OPENAI_API_KEY`, posts to OpenAI | `generate-image.mjs:216` |
| F5 | Migration replaced recursive Claude execution with native Codex workspace-write execution; still an opt-in model request. | `live-copy-edit-agent.mjs` |

This is **triage, not evidence.** It was a human read on the dev host, not a SkillSpector scan on the gate host, so none of it can populate the evidence fields below.

`scripts/` is vendored because the skill genuinely does not work without it: the mandatory setup step is a `node` invocation, and `pin`, `hooks`, `doctor`, and `live` are all script-backed. Shipping `SKILL.md` alone would install a skill whose first instruction fails.

---

## Taste Skill

| | |
|---|---|
| Upstream | https://github.com/Leonxlnx/taste-skill |
| Pinned commit | `e988add20dab0fa97d7a76781c48961c8184288e` |
| License | MIT |
| Installed at | `.agents/skills/taste-skill/` |
| Vendored subset | `skills/taste-skill/SKILL.md` (v2) |
| Requires | Nothing |
| Requires a key | No |

A single 87 KB `SKILL.md`. **Zero executable surface**: no scripts, no hooks, no network, no dependencies. It reads a brief, infers a design direction, and applies anti-generic doctrine to layout, typography, motion, and spacing.

Upstream ships 13 sibling skills (`brandkit`, `brutalist-skill`, `minimalist-skill`, `redesign-skill`, and others). This pack vendors only `taste-skill` v2, which is the one the workflow calls for. The others are deliberately out of scope; vendor them separately if you want them, and vet them first.

Version 2 is marked experimental upstream. Version 1 remains available upstream at `skills/taste-skill-v1/` if you want to compare.

---

## Asset generation (open slot)

This pack vendors **no** image or video generation component, on purpose.

You need one only at the hero-polish step, and only when a generated image beats stock photography or a CSS-native treatment. The whole five-variant and three-layout phase runs with graphics the model writes directly, no generation backend involved. Decide when you get there.

Options, with the tradeoffs that matter:

| Option | Delivery | Cost | Notes |
|---|---|---|---|
| **ComfyUI local** (`artokun/comfyui-mcp`, MIT) | Vendorable MCP server driving a local ComfyUI | None after hardware | Nothing leaves your machine. Needs ComfyUI installed and real GPU capacity. |
| **mcp-image** (`shinpr/mcp-image`, MIT) | Vendorable MCP server, bring your own key | Per API call | Gemini-backed, actively maintained, small. Prompt optimization built in. |
| **MeiGen** (`jau123/MeiGen-AI-Design-MCP`, MIT) | Vendorable MCP server, bring your own key | Per API call | Supports GPT Image 2 and Seedance. Highest star count of the set. Owner account is recent; weigh that. |
| **fal.ai** (`luminarylane/fal-mcp-server`, MIT) | Vendorable MCP server, bring your own key | Per API call | Images, video, music, audio. Thin publisher signal at the time of writing. |
| **Higgsfield** | Remote hosted MCP connector at `https://mcp.higgsfield.ai/mcp` | Credit-based subscription | Broadest model access. **Cannot be vendored**: there is no local server, so no bytes to scan. Account OAuth, not an API key. |

Higgsfield sits outside this pack's delivery model rather than below it on quality. A remote connector has nothing to pin, scan, or reproduce, which is the opposite of how every other component here works. If you want it, add it to your own MCP settings directly and accept that it is unvetted by construction.

Whichever you choose, the pack rule holds: keys live in environment variables, never in committed files.

---

## Vetting status

The airlock gate (stage, scan, adjudicate, record evidence, promote, audit) has **not** run against these components. What that means concretely:

- `pack.yaml` carries `airlock_evidence_id: null`, `engine_pin: null`, `scan_date: null`, `content_hash: null`, and `vendored_tree_digest` computed locally rather than bound to scan evidence.
- The T006 validator will pass this pack in test mode and fail it in release mode. That is the intended result.
- No `pack.stamp` is written, so nothing downstream can mistake this for a released pack.

What has been verified: both components are pinned to exact upstream commits, both licenses are OSI-approved and recorded, the vendored trees contain no symlinks, and the vendored subsets are exactly the declared selected paths. A human triage pass over the executable surface found no malicious behavior (see "Triage findings" above, and bead `z7f`).

What has not: no scanner has run. Triage is a targeted read of the high-risk surface by one person, which is weaker than an engine sweep and much weaker than an adjudicated evidence bundle. There is also no transitive-dependency audit, because the vendored tree carries no `package.json` and no lockfile, so brief decision 6's `osv-scanner` gate has nothing to audit. Run the airlock lifecycle before this pack ships to anyone else.
