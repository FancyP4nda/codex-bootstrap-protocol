---
title: STE Writing Standards - AI Reference
source: ASD-STE100 Simplified Technical English, Issue 9 (January 2025)
source_url: https://www.asd-ste100.org
derived_from: ASD-STE100_ISSUE9.md (local conversion of the official PDF)
retrieved: 2026-07-27
status: distilled reference, not the standard itself
license_note: >
  ASD-STE100 is copyright ASD (Brussels). This file is a paraphrased distillation
  of the writing rules for internal AI-agent use. It reproduces neither the
  specification text nor the Part 2 Dictionary. Do not publish or redistribute
  this file as a substitute for the standard. Get the official copy free at
  asd-ste100.org.
---

# STE Writing Standards — Reference for AI Writing

Rules distilled from ASD-STE100 Issue 9, Part 1 (Sections 1-9). Rule numbers
match the official standard so any rule can be checked against the source.
The standard has two halves: the writing rules (this file) and a controlled
dictionary of ~900 approved words (NOT included here — see "The dictionary"
at the end).

## When to apply

- **Applies to:** documentation, READMEs, PR descriptions, error messages,
  release notes, runbooks, procedures, code comments (prose parts).
- **Does not apply to:** code, identifiers, command syntax, quoted text,
  marketing copy, or writing that needs a voice. STE strips voice on purpose.
- **Two writing types with different rules:**
  - **Procedural** — tells the reader to do something (steps, runbooks,
    error remediation). Imperative form, max 20 words per sentence.
  - **Descriptive** — gives information (overviews, explanations, notes).
    No imperative form, max 25 words per sentence.

---

## Section 1 — Words

- **1.1** Use only: words approved in the STE dictionary, technical nouns,
  and technical verbs.
- **1.2** Use an approved word only as its approved part of speech.
  ("Test" is a noun, not a verb: "Do a test," not "Test the system.")
- **1.3** Use an approved word only with its approved meaning, which is often
  narrower than standard English. ("Follow" = come after. To comply, use
  "obey": "Obey the safety instructions.")
- **1.4** Use only approved verb and adjective forms as given in the dictionary.
- **1.5** Technical nouns (domain terms — parts, tools, systems, units, roles,
  damage types, IT terms, etc.) are allowed even though they are not in the
  dictionary. The standard defines 22 categories of technical nouns.
- **1.6** A non-approved word is usable only when it is a technical noun or
  part of one ("base of the triangle" yes; "base of the unit" no — "bottom").
- **1.7** Do not use technical nouns as verbs. Not "oil the surfaces" —
  "apply oil to the surfaces." Not "it will snow" — "snow will fall."
- **1.8** Use the technical nouns your project/company/field has approved.
- **1.9** When choosing a new technical noun, pick one that is short
  (max three words) and easy to understand.
- **1.10** No regional, slang, or jargon technical nouns ("brick the router,"
  "gear" for equipment).
- **1.11** One name per item, always. Never alternate synonyms for the same
  thing ("actuator" vs "servo control unit" vs "control unit").
- **1.12** Technical verbs (domain actions: drill, solder, boot, reboot,
  download, install, encrypt...) are allowed. Prefer a dictionary verb when
  one is accurate; use the precise technical verb over a vague one
  ("ream the hole," not "machine the hole").
- **1.13** Do not use technical verbs as nouns. Past participle as adjective
  is fine ("the reamed hole").
- **1.14** American English spelling.

## Section 2 — Multi-word nouns

- **2.1** Multi-word nouns: max three words. Break longer noun stacks with
  prepositions. "Runway light connection resistance calibration" →
  "calibration of the resistance of the runway light connection."
- **2.2** If an official technical noun is longer than three words, write it
  in full on first use, then use a defined shorter form or approved
  abbreviation, or hyphenate the words that act as one unit.
  Spell out short names instead of inventing abbreviations.

## Section 3 — Verbs

- **3.1** Use only dictionary-listed verb forms.
- **3.2** Allowed forms only: infinitive, imperative, simple present, simple
  past, simple future, past participle as adjective. NOT allowed: present/past
  perfect ("has adjusted"), progressive ("is adjusting"), and other complex
  constructions.
- **3.3** Past participle = adjective only, before a noun or after
  be/become/stay ("the disassembled unit").
- **3.4** No auxiliary-verb constructions. "The temperature must be adjusted"
  → "Adjust the temperature." "Can be adjusted" → "You can adjust."
- **3.5** No "-ing" main verbs. "-ing" words are allowed only as technical
  nouns ("Troubleshooting", "the air-conditioning system") or the few approved
  dictionary words (lighting, opening, routing, servicing, mating, missing,
  remaining, something, during).
- **3.6** Active voice, always in procedures. In descriptive text, passive is
  allowed only when the agent is unknown ("During transmission, the data was
  corrupted"). Conversion methods: promote the by-agent to subject; use the
  imperative; use "you" (reader) or "we" (organization) as subject.
- **3.7** Express actions as verbs, not nominalizations. "The ohmmeter gives
  an indication of 450 ohms" → "The ohmmeter shows 450 ohms."
  "Before the removal of the unit" → "Before you remove the unit."

## Section 4 — Sentences (both writing types)

- **4.1** Short, clear, concrete sentences. One topic per sentence. Never
  abstract where the reader needs an action ("No leaks are permitted" →
  "Make sure that there are no leaks").
- **4.2** Do not omit words or use contractions. Write full sentences:
  keep subjects, verbs, articles. "If installed, remove the shims" →
  "If shims are installed, remove them." "don't" → "do not."
- **4.3** Use a vertical list for complex text (part lists, multi-step
  actions). Colon after the lead-in; one item per line; capitalize each item;
  period only on full-sentence items and on the final item; never mix
  procedural and descriptive items in one list; repeat "DO NOT" per item in
  safety lists; make every item connect grammatically to the lead-in.
- **4.4** Connect related sentences with approved connectors: "and," "but,"
  "then," "thus," "as a result," "at the same time."
- **4.5** Use articles (the/a/an) and demonstratives (this/these) before
  nouns; do not drop them for brevity ("Turn shaft assembly" → "Turn the
  shaft assembly"). Omit articles for general statements ("Solvents can cause
  damage to paint") and before alphanumeric identifiers ("Tag circuit
  breaker 36L7").

## Section 5 — Procedural writing

- **5.1** Max 20 words per sentence (warnings and cautions included).
  Split long instructions; a sub-clause about the same simultaneous action
  can stay.
- **5.2** One instruction per sentence, unless actions occur at the same time
  ("Hold the panel in its open position and install the fastener") or a result
  follows immediately ("Measure the leakage... The leakage must not be more
  than 0.5 cc/minute").
- **5.3** Imperative form for every instruction. "The test can be continued"
  → "Continue the test." Reserve "must" for safety-critical emphasis.
- **5.4** Condition first, then command, separated by a comma. "When the
  light comes on, set the switch to NORMAL." Comma placement changes meaning
  — place it deliberately.
- **5.5** Notes give information only, never instructions, requirements, or
  limits. Note sentences: max 25 words. A limit belongs in the work step, not
  a note. Anything preventing damage or injury is a WARNING/CAUTION, not a
  note. Test: the procedure must work with all notes deleted.

## Section 6 — Descriptive writing

- **6.1** Give information gradually; one subject per sentence.
- **6.2** Repeat key words and phrases to link sentences — do not vary
  terminology for elegance. Same term, same concept, every time.
- **6.3** Max 25 words per sentence.
- **6.4** Group related information into paragraphs; start each paragraph
  with a topic sentence.
- **6.5** One topic per paragraph. The topic sentences alone should form a
  good outline of the text.
- **6.6** Max six sentences per paragraph.

## Section 7 — Safety instructions

- **7.1** Identify the risk level with a signal word:
  **WARNING** = risk of injury or death. **CAUTION** = risk of damage to
  objects. Both risks together → WARNING.
- **7.2** Start with a clear command or condition ("DO NOT SWALLOW THE
  SOLVENT." / "WHILE YOU USE THE SPRAY PAINT, POINT THE SPRAY AWAY FROM
  YOUR FACE.").
- **7.3** Add the explanation of the risk or consequence ("SOLVENTS ARE
  POISONOUS AND CAN CAUSE INJURY OR DEATH."). Command + risk, never an
  abstract statement ("extreme cleanliness is imperative" is not a safety
  instruction).

## Section 8 — Punctuation and word count

- **8.1** All standard punctuation EXCEPT the semicolon. Write two sentences
  instead. (The em dash is not banned by STE; ban it separately if desired.)
- **8.2** Hyphenate directly related words: compound modifiers
  ("high-pressure chamber"), two-word numbers ("forty-seven"), letter/number
  + noun ("O-ring," "3-prong connector"), compound verbs ("heat-treat"),
  vowel-boundary prefixes ("de-icing").
- **8.3** Parentheses are allowed for: references, item numbers, step IDs,
  abbreviations, singular/plural "(s)", explanations, alternatives.
- **8.4** In a vertical list, the colon ends the sentence for word-count
  purposes; each list item counts as its own sentence.
- **8.5** Parenthetical text counts as one word in its sentence (and as its
  own sentence internally).
- **8.6** Count as one word each: numbers, number+unit ("20 kg"),
  abbreviations, alphanumeric identifiers ("36L7"), quoted text, titles and
  headings, label/placard text, proper nouns of people/organizations/places.
- **8.7** Hyphenated words count as one word.

## Section 9 — Writing practices

- **9.1** When a word-for-word substitution fails (wrong part of speech,
  changed meaning, bad English), rewrite the sentence. Understand the meaning
  first, then reconstruct with approved words. "Lift the seat so that it
  clears the track locks" → "Lift the seat until it is away from the track
  locks."
- **9.2** Respect restricted meanings. Examples from the standard:
  "wear" = friction damage only ("put on protective clothing");
  "see" = with the eyes only ("make sure that," not "see if");
  "turn" = rotate only ("the color changes to green," not "turns green");
  "above/below" = physical position only ("more than / less than" for limits).
- **9.3** No phrasal verbs. "put out" → "extinguish"; "give off" → "release."
  Combining two approved words into a new idiom creates an unapproved meaning.
- **9.4** Consistent wording for repeated actions. Pick one sentence pattern
  for a recurring instruction and reuse it verbatim.

## General recommendations (GR-1 to GR-8, advisory)

- **GR-1** Keep the conjunction "that" ("Make sure that the valve is open").
- **GR-2** Watch "with" for ambiguity; state the instrument or condition
  explicitly, and put the primary action verb first ("Seal the opening with
  tool TS9867," not "Use tool TS9867 to seal...").
- **GR-3** Replace ambiguous pronouns with the noun they refer to.
- **GR-4** "This" must have an unmistakable referent; restate the context if
  it could point at two things.
- **GR-5** Beware false friends when writing for non-native readers.
- **GR-6** No Latin abbreviations (e.g., i.e., etc.) — write "for example,"
  "that is," or drop them.
- **GR-7** Gender-neutral language; "he"/"she" are not approved pronouns.
- **GR-8** Possessive 's is permitted but optional; rewrite if unsure.

---

## The dictionary (what this file does not contain)

The other half of STE is Part 2: a controlled dictionary of ~900 approved
words, each with one part of speech, one approved meaning, and approved
alternatives for unapproved words. This file does not reproduce it
(copyright, and ~200 pages). For strict-STE work, look words up in the
official copy. High-frequency substitutions the rules themselves illustrate:

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

## Two enforcement modes (practical adaptation for AI writing)

- **strict** — procedures, runbooks, safety text, error messages: every rule
  above, both sentence caps, dictionary discipline.
- **STE-flavored** — general prose (READMEs, PR text, docs): keep the
  sentence caps, paragraph caps, active voice, no contractions, no semicolons,
  no phrasal verbs, one-name-per-thing; relax the dictionary lockdown so the
  text keeps natural range.

## Self-check before returning text

1. Any sentence over 20 words (procedure) / 25 words (description)? Split it.
2. Any semicolon? Two sentences.
3. Any contraction? Expand it.
4. Any passive voice with a known actor? Make it active.
5. Any perfect/progressive tense or stacked auxiliaries? Simplify the tense.
6. Any "-ing" main verb, nominalization, or phrasal verb? Use a plain verb.
7. Same thing named two ways? Pick one name.
8. Any instruction hidden in a note, or limit separated from its step? Move it.
9. Paragraph over six sentences or with two topics? Split it.
10. Safety text: signal word + command/condition + risk explanation, all three?
