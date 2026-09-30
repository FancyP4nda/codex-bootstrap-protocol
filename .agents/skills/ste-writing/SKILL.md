---
name: ste-writing
description: Style layer for technical prose in Simplified Technical English (ASD-STE100). Use when the user asks to rewrite text for clarity in STE, or when you write procedures, runbooks, safety text, or error messages. Also use when the user mentions STE, Simplified Technical English, ASD-STE100, or controlled language. Not for README.md (use github-readme-writer) or other documentation (use technical-writer). Those skills apply the STE-flavored mode to their own prose.
---

# STE Writing Skill

Write technical prose that a tired reader, a non-native English speaker, or a
parser can understand on the first pass. The rules come from ASD-STE100
Simplified Technical English, Issue 9.

STE removes voice on purpose. Do not apply it to marketing copy, conversational
replies, or writing that needs personality.

## Scope

**Apply to:** guides, cheatsheets, how-tos, instructions, runbooks, procedures,
technical documentation, README files, PR descriptions, release notes, error
messages, prose parts of code comments.

**Do not apply to:** code, identifiers, command syntax, file paths, quoted text,
log output, marketing copy, chat replies.

## Used by other skills

github-readme-writer and technical-writer apply the **STE-flavored** mode to
their own prose. When this skill runs with one of them, this skill controls the
style. The other skill controls the structure.

## Step 1 — Pick the mode

| Mode | Use for | Discipline |
|---|---|---|
| **strict** | Procedures, runbooks, safety text, error messages | Every rule. Both sentence caps. Dictionary discipline. |
| **STE-flavored** | Guides, cheatsheets, README files, PR text, general docs | Sentence and paragraph caps, active voice, one name per thing, no contractions, no semicolons, no phrasal verbs. Dictionary lockdown relaxed so the text keeps natural range. |

Default to **STE-flavored** unless the text tells the reader to do something
that can hurt them, break something, or fail silently.

## Step 2 — Classify each block of text

| Type | What it does | Form | Sentence cap |
|---|---|---|---|
| **Procedural** | Tells the reader to do something | Imperative | 20 words |
| **Descriptive** | Gives the reader information | No imperative | 25 words |

Never mix the two in one list.

## Step 3 — Write

Core rules, in order of how often they get broken:

1. **One name per thing.** Pick a term and repeat it. Never vary terminology
   for elegance. Repeating the key word is how sentences link.
2. **Active voice.** Passive is permitted only in descriptive text when the
   actor is unknown.
3. **Simple tenses only.** Infinitive, imperative, simple present, simple past,
   simple future, past participle as adjective. No perfect tense, no
   progressive, no stacked auxiliaries.
4. **Verbs, not nominalizations.** "Before you remove the unit," not "before
   the removal of the unit."
5. **One instruction per sentence.** Exception: simultaneous actions, or a
   result that follows immediately.
6. **Condition first, then command, split by a comma.** "When the light comes
   on, set the switch to NORMAL."
7. **No semicolons.** Write two sentences.
8. **No contractions.** Write "do not," not "don't."
9. **No phrasal verbs.** "extinguish," not "put out." "release," not "give off."
10. **Keep articles and the conjunction "that."** "Turn the shaft assembly."
    "Make sure that the valve is open."
11. **Multi-word nouns: three words maximum.** Break longer stacks with
    prepositions.
12. **Paragraphs: one topic, six sentences maximum, topic sentence first.**
    The topic sentences alone should read as an outline.
13. **Notes carry information only.** A limit or an instruction belongs in the
    step, not in a note. The procedure must still work with every note deleted.
14. **Safety text needs all three parts:** signal word, then command or
    condition, then the risk. WARNING means risk to people. CAUTION means risk
    to objects. Both risks together means WARNING.
15. **No Latin abbreviations.** Write "for example" and "that is."

High-frequency substitutions:

| Instead of | Write |
|---|---|
| begin, commence, initiate | start |
| utilize, leverage | use |
| facilitate | help |
| ensure | make sure that |
| prior to / subsequent to | before / after |
| obtain, acquire | get |
| demonstrate | show |
| additionally, furthermore, moreover | also |
| perform (an analysis) | do / analyze |
| regarding, concerning | about |
| acceptable | permitted |
| within | in |
| detect (general use) | find |

American English spelling.

## Step 4 — Self-check before returning the text

1. Any sentence over 20 words (procedural) or 25 words (descriptive)? Split it.
2. Any semicolon? Two sentences.
3. Any contraction? Expand it.
4. Any passive voice with a known actor? Make it active.
5. Any perfect tense, progressive tense, or stacked auxiliaries? Simplify.
6. Any "-ing" main verb, nominalization, or phrasal verb? Use a plain verb.
7. Same thing named two ways? Pick one name.
8. Any instruction hidden in a note, or limit separated from its step? Move it.
9. Paragraph over six sentences, or with two topics? Split it.
10. Safety text: signal word, command or condition, and risk — all three?

## Full rule set

`references/STE-RULES.md` holds all of Part 1, Sections 1 through 9, with the
official rule numbers. Read it when:

- You write in **strict** mode.
- You need to defend or cite a specific rule.
- A rewrite is hard and you need the worked examples.

The STE dictionary (Part 2, about 900 approved words) is copyright ASD and is
not reproduced here. Get the official copy free at https://www.asd-ste100.org.
