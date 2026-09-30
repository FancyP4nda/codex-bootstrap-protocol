# Web-Design Pack Rules

Auto-loaded. Governs how Codex runs front-end design work in this project.

Human-facing walkthrough: `docs/web-design-mission.md`. Component setup and what each one executes: `docs/web-design-notes.md`.

---

## 1. Never one-shot a design

When asked to build a page, a landing page, a hero, or a marketing surface, do **not** produce one version and present it as the answer.

Default sequence:

| Round | Output | Decision |
|---|---|---|
| 1 | 5 versions across 5 distinct aesthetic families | Which family |
| 2 | 3 versions inside the chosen family, varying body format | Which layout |
| 3 | 1 page, refined component by component | Ship |

Render each round so every version is viewable at once. Side-by-side comparison is the point; sequential single outputs defeat it.

Collapse the sequence only when the user explicitly says so ("just build it", "one version is fine"). Announce the collapse rather than doing it silently.

If an inspiration library exists in the project, read it and draw the five families from it before inventing your own.

## 2. Every build prompt carries four parts

Before generating, confirm all four are present. Ask for whatever is missing rather than filling it in silently.

1. **Aesthetic** — the design family, 5 to 8 lines, named and described.
2. **Reference** — screenshots or live URLs. Match the *feel*. Do not copy content, and do not reproduce layout one-for-one.
3. **Intent** — what is being built, for whom, and the single action the visitor should take.
4. **Guardrails** — explicit always and never lists.

A request with intent but no aesthetic and no reference is the request that produces generic output. Push back and gather the missing parts. That pushback is the highest-value thing in this rules file.

## 3. Generic-output guardrails

Never ship these unless the user asks for them by name:

- purple-to-blue gradients, and gradient-on-everything generally
- Inter as a default choice made by omission
- 3D blobs, floating glass cards, generic isometric illustration
- centered hero, three feature cards, identical testimonial row, as an unconsidered default
- emoji as section iconography
- `backdrop-blur` applied without a reason

The list is not exhaustive. The rule behind it: when a choice is the statistically obvious one, treat that as a signal to reconsider, not a reason to proceed. Deliberately choosing a common pattern for a stated reason is fine. Arriving at it by default is not.

## 4. Skill routing

Two design skills are installed. They overlap on purpose.

| Situation | Lead with |
|---|---|
| Any front-end design task, default | **Impeccable** |
| Named command work (`critique`, `audit`, `polish`, `bolder`, `quieter`, `typeset`, `layout`, `animate`, `colorize`, `clarify`, `adapt`, `harden`, `optimize`, `distill`, `delight`, `overdrive`, `onboard`, `shape`, `extract`, `document`, `init`, `live`) | **Impeccable**, load that command's reference file |
| "This still looks AI-generated", "make it distinctive", "give it a point of view" | **Taste Skill** |
| Round 1 of a build sequence | **Both**, one per half of the variant set, then compare |

Never blend both skills' doctrine inside one variant. Run them against separate variants so the difference stays legible. Blending averages two points of view into the generic output both exist to prevent.

Impeccable requires `node .agents/skills/impeccable/scripts/context.mjs` once per session before its commands run. Do not rerun it in the same session.

## 5. Hero before body

Resolve the hero before polishing anything below it. Body work against an unsettled hero gets redone.

Hero loop: generate 4 candidates, present them, take a pick, generate variations of that pick, take a final pick. Two rounds of four, not one round of sixteen.

After the hero lands, handle the hero-to-body transition and page load behavior explicitly. Abrupt section cuts and everything-at-once reveals are the two most common tells that a page was not finished.

## 6. Offer a tweaks panel before iterating in prose

Once a page is close, do not accept or act on vague refinement requests ("make it more premium", "add more punch"). Offer to build a tweaks panel on the dev server first, exposing every aesthetic decision: heading and body font, type scale, accent color, motion timing, reveal distance, section spacing and weight.

Be aggressive about what the panel exposes. Anything the user might want to compare visually belongs in it. One panel beats ten rebuilds.

## 7. Assets

No image or video generation backend is vendored with this pack. If a task needs generated imagery, read the options table in `docs/web-design-notes.md` and ask the user which backend to use. Do not assume one is configured.

Prefer, in order: a CSS or SVG-native treatment, licensed stock, then generation. Generation is the expensive option and often not the best one.

Keys and tokens live in environment variables. Never write a key into a committed file, and never into `.mcp.json`.

## 8. Verify before declaring done

Run Impeccable `critique` or `audit` against the result before calling a design finished. Report what it found. Do not claim a design is complete on the strength of it rendering without errors.
