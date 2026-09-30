---
name: to-questionnaire
description: Turn a decision you can't fully answer into a questionnaire for someone else to fill in.
---

Turn something the user can't answer alone into a **questionnaire**: a Markdown document they hand to one person to fill in async, or fill out together over a meeting. The recipient holds knowledge the user lacks; the questionnaire pulls it out of them.

**Grill the send, not the subject.** Interview the user only about the _send_, which they can always answer: who it goes to, and what they need back. The questions in the document then target the **gap** between what the recipient knows and what the user needs.

**It leaves the user's hands.** Never put secrets, credentials, internal hostnames or IPs, or sensitive work data in the questionnaire. Flag anything borderline (names, codenames, internal URLs, figures) to the user before writing it. Sending is the user's action: never send, share or post it yourself.

0. **Read before asking.** Skim what the repo already answers: `docs/CONTEXT.md`, the ADRs in `docs/adr/`, and `docs/decision-brief*.md` and `docs/prd.md` (ignore shipped placeholders). Skip silently when absent. Done when you know which questions the repo settles (drop them) and which **CONTEXT.md** terms the questions must use.

1. **Who is it going to?** Ask, in one exchange, the recipient's role, expertise, and relationship to the user. This fixes the questionnaire's tone and how much context it must carry. Done when you know who the recipient is and what they know that the user doesn't.

2. **What do you need back?** Ask, in one exchange, the specific decisions or facts the user can't resolve alone and needs from this person. Done when you have a concrete list of what the user must walk away able to do or decide.

3. **Write the questionnaire.** Draft questions aimed at the gap from steps 0–2, following the Document structure below. Check the draft against the send rule above. **Location:** in a bootstrapped repo (it has `docs/`), write `docs/questionnaire-<slug>.md` (slug from the topic); otherwise ask where, offering the current directory. Never default to the repo root. Done when the file exists, its path is reported, and every item the user named in step 2 is covered by a question.

## Document structure

Frame the document as a **discovery questionnaire**: the user lacks context, the recipient holds it. Order questions most-important-first, since async means you may only get one pass, and group them under `##` headings by theme once there are more than a handful. Write it using the template below.

<questionnaire-template>

# <Questionnaire title>

**Purpose:** why this questionnaire exists and the decision riding on it.

**From:** <the user>, **To:** <the recipient>, **How your answers will be used:** <where they go>

## Context

One paragraph orienting a recipient who wasn't in the user's head. Enough to answer well, not a page.

## How to answer

Deadline and rough effort. Partial answers and "I don't know" are useful: flag anything you're unsure of rather than skipping it.

## <Theme heading>

One `##` section per theme. Under each, its questions, most-important-first. Every question is one idea, never compound, with an answer stub directly beneath, and a one-line _why this matters_ only where the question could be misread or invite a throwaway answer.

<question-example>
### What load is the system expected to handle at launch?

_Why this matters: it decides whether we provision for burst traffic now or defer it._

>
</question-example>

## Anything else?

A closing catch-all: anything we didn't ask that we should know?

</questionnaire-template>

## When answers come back

Read the filled questionnaire, then route each answer to one home rather than leaving it in the document:

- **Decisions** that pass the ADR test (hard to reverse, surprising without context, and the result of a real trade-off: all three) go to `grill-with-docs`, which records the ADR in `docs/adr/`. Decisions that fail it go into the decision brief or PRD they affect.
- **Terms** the recipient defined or corrected go to `docs/CONTEXT.md`.
- **Follow-up work**, including questions left unanswered, becomes a bead (`bd create`); in a repo without beads, list it for the user.

Done when every answer has a home and you have told the user where each went.
