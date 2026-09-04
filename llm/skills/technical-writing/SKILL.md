---
name: technical-writing
description: Writes, rewrites, and reviews technical documentation in clear, precise English. Use for procedures, runbooks, READMEs, reference material, troubleshooting guides, release notes, incident reports, error messages, API documentation, code comments, and docstrings; also use when a user asks to remove vague or LLM-like language from technical prose.
---

# Technical Writing

Write technical prose that lets the intended reader understand the facts and
take the correct action on the first read. Use the structural discipline of
Simplified Technical English. Do not claim that the output complies with
ASD-STE100.

## Scope

Use this skill only for prose that explains a technical system or directs a
technical action. This includes prose in code comments and docstrings. Do not
apply it to executable code, identifiers, commands, configuration files, quoted
errors, UI labels, or marketing and narrative writing.

Preserve all facts, numbers, conditions, safety information, and established
technical terms. Do not invent a cause, result, value, or example to make text
appear more concrete.

## Choose the Form

Classify each passage before writing:

- **Procedural text** tells the reader what to do. Use numbered steps when the
  actions have an order. Use the imperative. Give one action per sentence.
  Put a required condition before its action.
- **Descriptive text** explains what a system is, does, or did. State facts in
  a logical order. Group one topic per paragraph.
- **Reference text** defines interfaces, inputs, outputs, limits, and failure
  cases. Prefer tables, lists, and examples when they make an exact mapping
  clearer than prose.

Do not mix instructions and explanation in the same sentence. Put a short
explanation before or after the relevant procedure.

## Write the Draft

1. State the result, purpose, or required action first.
2. Use concrete nouns and direct verbs. Name the actor when it matters.
3. Use one term for one concept throughout the document. Preserve project
   terminology. Do not replace distinct terms merely to avoid repetition.
4. Prefer short sentences. Split a sentence that contains multiple actions,
   conditions, exceptions, or independent facts.
5. Use active voice when it identifies the responsible actor. Use passive voice
   when the actor is unknown, irrelevant, or the affected object is the topic.
6. State uncertainty accurately. Keep distinctions such as must, should, can,
   may, and might when they carry different requirements or confidence.
7. Replace vague claims with observable facts. Give the condition, limit,
   behavior, or consequence instead of calling something simple, robust,
   seamless, powerful, or important.
8. Define an unfamiliar term at first use when the intended reader needs the
   definition. Do not define terms the document's audience already knows.

## Review Before Delivering

Check the draft for these failures:

- A reader cannot identify what to do, when to do it, or what result to expect.
- A condition appears after the action it changes.
- Synonyms hide that the same system object or action is meant.
- A sentence contains more than one independent instruction.
- A qualifier, exception, risk, limit, or known uncertainty was lost.
- Filler, hype, ceremonial transitions, or unsupported significance claims add
  no information.
- Code and other literal technical text changed.

For a review request, report each issue as: **problem**, **why it affects the
reader**, and **a proposed rewrite**. Do not rewrite unrelated text.

## ASD-STE100 Boundary

This skill takes inspiration from ASD-STE100: consistent terminology, complete
grammar, direct instructions, short sentences, and explicit conditions. It
does not include the ASD-STE100 controlled dictionary or its full rules. Do not
describe its output as ASD-STE100 compliant. A compliance assessment requires
the official standard and qualified review.
