---
name: technical-writing
description: Writes, rewrites, and reviews technical documentation in precise, usable English. Use when drafting or revising procedures, runbooks, READMEs, reference material, troubleshooting guides, release notes, incident reports, API documentation, code comments, docstrings, error messages, or vague and LLM-like technical prose.
---

# Technical Writing

Make the intended reader able to understand the system or take the required
action on the first read. Favor accuracy, explicit conditions, consistent
terms, and direct language over elegance or variety.

## Establish the Source of Truth

Treat supplied text, repository documentation, code, and verified evidence as
the source of truth. Preserve facts, quantities, requirements, safety
information, defaults, limits, and uncertainty. Do not invent details to make
the prose more specific.

Preserve commands, code, identifiers, paths, configuration, quoted errors, UI
labels, and established project terminology exactly unless the user asks to
change them. Do not apply this skill to marketing or narrative prose unless a
technical passage is in scope.

## Choose the Document Form

- **Procedure:** State the result or prerequisite first. Use ordered,
  imperative steps for actions that must occur in sequence. Put a condition or
  warning before the action it controls. Use one action per step where that
  makes execution safer.
- **Description:** Lead with the main fact. Group supporting facts by topic or
  dependency, and keep each paragraph to one subject.
- **Reference:** Define inputs, outputs, defaults, limits, and failures. Use a
  table, list, or example when it makes an exact mapping easier to scan.
- **Troubleshooting:** State the symptom, cause only when supported,
  corrective action, and expected result. Keep diagnosis separate from
  remediation.

Do not combine an instruction and its explanation in the same sentence. Put a
short explanation immediately before or after the relevant instruction.

## Draft and Rewrite

1. State the purpose, result, or required action before background detail.
2. Use concrete nouns and direct verbs. Name the responsible actor when it
affects ownership or execution.
3. Use one term for one concept. Do not substitute synonyms merely to avoid
repetition.
4. Split sentences that contain several actions, conditions, exceptions, or
independent facts. Keep a required exception with the statement it limits.
5. Preserve modality. `Must`, `should`, `can`, `may`, and `might` carry
different requirements or degrees of certainty.
6. Replace vague claims with observable behavior, stated limits, or explicit
consequences. Remove filler, hype, ceremonial transitions, and unsupported
importance claims.
7. Define an unfamiliar term at first use only when the audience needs it.
8. Retain a structure that already serves the reader. Reorganize only to make
purpose, sequence, ownership, or dependencies clear.

Use active voice when it identifies a useful actor. Use passive voice when the
actor is unknown, irrelevant, or deliberately not the subject.

## Deliver the Requested Work

- For a draft or rewrite, return the revised text. Preserve the source's level
  of detail unless it contains repetition, filler, or ambiguity. Do not add a
  change log unless requested.
- For a review, report only material issues in the supplied scope. For each,
  state the problem, reader impact, and the smallest proposed rewrite. Do not
  report personal style preferences as defects.
- For a factual gap or unsupported claim, identify the gap instead of
  guessing.

Before delivering, verify that the reader can identify the action, conditions,
and expected result; that terms and literal technical text remain correct; and
that requirements, exceptions, risks, limits, and uncertainty are intact.
