# Web-Design Mission Guide

The workflow this pack installs. Read it once before your first build, then keep it open as a checklist.

The goal is to stop producing generic output. Model quality is not the constraint. A stronger model only moves what counts as generic. The constraint is that the model has no taste of its own, so you supply yours, deliberately, at three points in the process.

---

## Step 1: Build your inspiration library

Do this before you prompt for anything. Skipping it is the single most common reason output comes back generic.

**Collect.** Go to Dribbble (search `web design`, sort by popular), Pinterest (search `web design`), and X. X tends to be the richest source because designers post work there that never reaches the aggregators. Screenshot anything you like. Save the URL when the live site exists, because a URL carries motion, spacing, and load behavior that a screenshot loses.

Collect for the body of a page too, not only heroes. Layout, rhythm, and section transitions matter as much as the first viewport, and they are the part most people forget to gather.

**Organize.** Ask Codex to build you a small local inspiration-library app from the folder. Have it:

- group screenshots into aesthetic families and name each family
- write the design vocabulary for each family, so you can describe what you like in words a model can act on
- expose per-item `copy image prompt` and `copy brief` actions

The naming step is the one that pays. Once a family is called `print-tech paper` or `vast quiet cinematic` or `dither mono`, you can say "give me five variants across five families from my library" and get real spread instead of five versions of the same idea.

A folder of screenshots works. The app is better because it turns a pile into a vocabulary.

**Ask Codex:** `Build me a local inspiration-library app from ./inspiration. Group by aesthetic family, name each family, write the design vocabulary for it, and give each item copy-image-prompt and copy-brief buttons.`

---

## Step 2: Install the tools

This pack vendors two design skills. Both install with the pack; neither needs a key.

| Component | Role |
|---|---|
| **Impeccable** | Primary design engine. 23 commands covering build, evaluate, refine, enhance, and fix. Attacks generic output across typography, color, spatial design, responsiveness, interaction, motion, and UX writing. |
| **Taste Skill** | Second opinion. Same target, different judgment. Run it against the same brief to see a genuinely different reading. |

Running both against one brief and comparing is a feature, not redundancy. See `.agents/bootstrap/instructions/web-design-pack.md` for when each one leads.

**Asset generation is a slot this pack deliberately leaves open.** You need it only at the hero-polish step in Step 3, and only when you want a generated image rather than stock or a CSS-native treatment. `docs/web-design-notes.md` lists the backends and their tradeoffs. Pick one when you actually reach that step.

**21st.dev** is worth a bookmark. It is not a skill or a server. It is a component gallery where each item has a `copy prompt` button: buttons, cards, pricing sections, borders, backgrounds, calls to action, pagination. Use it when you need a specific component rather than a whole-page direction.

**One warning.** Resist collecting more design skills. Highly prescriptive skills produce one look, which is the problem you are trying to escape. Impeccable and Taste are flexible, which also means their output depends on how well you prompt them. That is the tradeoff, and it is the right one.

---

## Step 3: Build by elimination, never by one shot

Stop trying to one-shot a page. One prompt against one output is a lottery ticket, and "make it more premium" is not a design instruction.

Cast wide, then narrow:

```
5 variants, 5 aesthetic families     ->  pick a direction
3 variants inside that family        ->  pick a layout
1 layout, then tweak                 ->  ship
```

**Round 1: five directions.** Ask for five versions in five different aesthetic families and render them where you can see all five at once. Comparing side by side tells you what you want far faster than judging one page in isolation. If you built the Step 1 library, point at it: "pick five families from my library." If you did not, name five styles explicitly.

**Round 2: three layouts.** Take the winner and ask for three variations inside that family, changing body format rather than aesthetic. This is where the page structure gets decided: where the index sits, how sections are framed, how content is weighted.

**Round 3: one page, then tweaks.** Now go component by component. Nail the hero first. If the hero is not right, nothing downstream will be.

### The four-part prompt

Every build prompt carries exactly four things. Not a 10,000-line design document, which produces the same output every time for everyone who uses it.

1. **Aesthetic.** The design family. Five to eight lines. Name it, describe it, and mean it.
2. **Reference.** Screenshots from your library, live URLs, or both. State plainly that you are matching *feel*, not content and not layout. You are not copying the reference.
3. **Intent.** What is being built and why. What kind of product, who the visitor is, and what you want them to do. A page whose job is booking a demo is a different page from one whose job is being read.
4. **Guardrails.** Always and never. `never` is where you kill generic output by name: no purple-blue gradients, no Inter, no 3D SaaS blobs, no floating glass cards.

### The hero loop

Once a layout is chosen, generate four hero candidates, look at them, pick one, then generate variations of that one. Push it: "this is too monochrome, give me versions with a single restrained accent." Two rounds of four beats one round of sixteen.

Then handle the seams. Ask for the hero-to-body transition explicitly, because an abrupt cut reads cheap. Ask for load behavior with weight to it, so elements arrive rather than appear.

### Build a tweaks bar

When the page is close but not right, stop guessing in prose. Have Codex add a tweaks panel to the dev server exposing every aesthetic decision: heading font, body font, sizes, accent color, motion timing, reveal distance, section weight.

**Ask Codex:** `Add a tweaks panel to the dev server exposing every aesthetic decision on this page: heading and body font, scale, accent color, motion timing, reveal distance, section spacing. Be aggressive about what you expose.`

Seeing three fonts in two seconds beats asking for three rebuilds. This is the step that turns iteration from expensive into free, and it is where most of the final quality comes from.

---

## Checklist

- [ ] Inspiration library exists, families are named, body references collected alongside heroes
- [ ] Round 1: five families, viewed side by side, one direction chosen
- [ ] Round 2: three layouts inside that family, one chosen
- [ ] Every prompt carried aesthetic, reference, intent, and guardrails
- [ ] Guardrails named specific generic patterns to avoid
- [ ] Hero resolved before body polish
- [ ] Hero-to-body transition and load behavior handled explicitly
- [ ] Tweaks panel built before fine-tuning by prose
- [ ] Impeccable `critique` or `audit` run before shipping

---

## Deployment conditions

Read `docs/web-design-notes.md` before first use. It records what each vendored component executes on your machine and what it does not.
