---
name: technical-writing
description: Write, rewrite, and review technical documentation in clear, precise English. Use for procedures, runbooks, READMEs, reference material, troubleshooting guides, release notes, incident reports, error messages, API documentation, code comments, and docstrings. Also use when a user asks to remove vague or LLM-like language from technical prose.
---

# Technical Writing

Write prose that lets the intended reader understand the facts and take the
correct action on the first read. Apply the useful disciplines of Simplified
Technical English: direct instructions, consistent terminology, explicit
conditions, and complete grammar.

## Scope and Boundaries

Use this skill for prose that explains a technical system or directs a
technical action, including prose in code comments and docstrings.

Do not apply it to executable code, identifiers, commands, configuration,
quoted errors, UI labels, or marketing and narrative writing. Preserve these
literal elements exactly unless the user explicitly asks to change them.

Preserve facts, quantities, conditions, safety information, requirements, and
established technical terms. Do not invent a cause, outcome, value, example,
or implementation detail to make the text sound more concrete.

## Identify the Document Form

Classify the passage before drafting or revising it.

- **Procedural text** tells the reader what to do. Use ordered steps when the
  actions have a sequence. Use the imperative. Put each required condition
  before the action it controls. Give one action per sentence where practical.
- **Descriptive text** explains what a system is, does, or did. Lead with the
  main fact, then state supporting facts in a logical order. Keep one topic in
  each paragraph.
- **Reference text** defines interfaces, inputs, outputs, limits, defaults,
  and failure cases. Use tables, lists, or examples when they show an exact
  mapping more clearly than prose.

Do not combine an instruction and its explanation in the same sentence. Put a
short explanation immediately before or after the relevant instruction.

## Draft or Rewrite

1. State the result, purpose, or required action first.
2. Use concrete nouns and direct verbs. Name the actor when responsibility
   matters.
3. Use one term for one concept throughout the document. Preserve project
   terminology; do not substitute synonyms only to avoid repetition.
4. Prefer short sentences. Split sentences that combine actions, conditions,
   exceptions, or independent facts.
5. Use active voice when it makes the responsible actor clear. Use passive
   voice when the actor is unknown, irrelevant, or not the topic.
6. Preserve the meaning of modal language. `Must`, `should`, `can`, `may`, and
   `might` express different requirements or degrees of certainty.
7. Replace vague claims with observable facts. State the condition, limit,
   behavior, or consequence instead of calling something simple, robust,
   seamless, powerful, or important.
8. Define an unfamiliar term at first use only when the intended audience
   needs the definition.
9. Keep the original structure when it already serves the reader. Reorganize
   only when the current order obscures purpose, sequence, or ownership.

For a rewrite request, return the revised text without a change log unless the
user asks for one. Preserve the source's level of detail unless it contains
repetition, filler, or ambiguity.

## Review Requests

Review only the text in scope. Do not rewrite unrelated passages.

For each material issue, report:

1. **Problem:** what is unclear, inaccurate, inconsistent, or hard to use.
2. **Reader impact:** why it affects correct understanding or action.
3. **Proposed rewrite:** the smallest revision that resolves the issue.

Do not report stylistic preferences as defects. Prioritize ambiguity, missing
conditions, unsafe instructions, contradictions, terminology drift, and lost
limits or exceptions.

## Final Check

Before delivering, confirm that:

- The reader can identify what to do, when to do it, and the expected result.
- Every condition appears before the action it changes.
- Terminology is consistent and does not hide distinct system objects.
- No sentence contains multiple independent instructions without a reason.
- Requirements, qualifiers, exceptions, risks, limits, and uncertainties remain
  intact.
- Filler, hype, ceremonial transitions, and unsupported importance claims are
  removed.
- Literal technical text has not changed unintentionally.
