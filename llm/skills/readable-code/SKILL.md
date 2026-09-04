---
name: readable-code
description: Standards for writing, editing, reviewing, and discussing readable, maintainable source code. Use when working with source code or code design.
---

# Readable Code

Write code that a maintainer can understand and safely change without needing
unwritten context. Favor clear names, direct control flow, local reasoning,
and established project conventions over brevity or novelty.

## Before editing

Inspect the code in context before changing it.

| Check | Reason |
| --- | --- |
| Callers and imports | A signature or behavior change can affect dependent code. |
| Tests | Existing tests define supported behavior and expose regressions. |
| Shared interfaces | A change can affect several modules or consumers. |
| Local conventions | The surrounding code may establish names, patterns, or boundaries. |

Update dependent code in the same task. Do not leave broken imports, stale
callers, or orphaned references.

## Names

Names are the primary explanation of code. Name values for their role and
meaning, not for their type or a shortened implementation detail.

- Use specific, pronounceable names: `customerAddress`, not `custAddr`.
- Avoid unexplained abbreviations and non-idiomatic single-letter names. Do
  not use shortcuts such as `curr`, `prev`, `res`, `ans`, or `gen_ts`.
- Use nouns for values and collections: `activeUserCount`, `pendingOrders`.
- Use verbs for functions: `findUserByEmail`, `calculateTotalPrice`.
- Use question forms for booleans: `isActive`, `hasPermission`, `canEdit`.
- Use plural nouns for collections: `users`, `matchedRecords`.
- Name predicate or filtered collections with a past participle or adjective,
  such as `enabledFeatures` or `matchedRecords`.
- Follow the language and project convention for constants. For example,
  `MAX_RETRY_COUNT` is appropriate in languages that use screaming snake case.

Idiomatic short names remain appropriate when their scope makes the meaning
unambiguous, such as `i` in a short C-style loop, `e` for a Go error, or `T`
for a generic type parameter. Otherwise, spell the name out.

Rename a value when a comment is needed only to explain what the name means.

## Functions and control flow

Give each function one clear responsibility at one abstraction level.

- Keep functions short enough to understand as a unit. About 40 lines is a
  signal to review the structure, not a required limit.
- Prefer zero to two parameters. Three parameters are acceptable when their
  relationship remains clear. When a function needs four or more related
  values, use a named parameter object or struct.
- Make side effects explicit in the function name or split them from queries.
  A function named `checkUserStatus` must not update a database.
- Use guard clauses and early returns for invalid input, errors, and edge
  cases.
- Prefer shallow control flow. Restructure deeply nested conditions when a
  guard clause or helper makes the path clearer. Keep visual nesting to two
  levels where practical.
- Prefer explicit, multi-step logic to dense expressions or clever one-liners.
- Extract a repeated or independently meaningful block. Do not extract a
  trivial one-line expression used once.

Place high-level operations before their supporting helpers when the language
and project style permit it. Keep related code together rather than scattering
one concept across files. Use blank lines as paragraph breaks between distinct
steps in a function.

## Constants and configuration

Name a non-obvious literal when the name communicates a domain rule, unit, or
shared behavior. Do not introduce a constant for a value whose meaning is
already obvious from a standard API or immediate expression.

Move values that vary by deployment, environment, or product policy into the
project's established configuration mechanism. Do not add configuration for a
hypothetical future use case.

## Comments

Use code to explain normal behavior. Use comments to preserve information that
the code cannot express clearly.

- Explain why a surprising decision, constraint, or workaround exists.
- State external behavior, compatibility requirements, or non-obvious failure
  modes when they affect maintenance.
- Do not narrate syntax, restate a well-named expression, or provide a
  language tutorial.
- Delete commented-out code. Version control preserves it.
- Keep comments brief and direct. Write `Retry on timeout`, not `This will
  retry the operation if a timeout occurs`.

## Design boundaries

Solve the requested problem without speculative abstraction. Preserve a path
to future change at boundaries that are already likely to vary, such as
external services, storage, configuration, or failure handling.

- Keep modules loosely coupled. A local change should not require unrelated
  modules to change.
- Encapsulate third-party integrations when the project benefits from a stable
  seam for replacement or testing.
- Make failures visible and handle recovery deliberately. Do not silently
  discard errors.
- Add logging, metrics, or tracing when the existing observability pattern
  calls for them.
- Optimize only with evidence of a bottleneck. Preserve readability unless a
  measured requirement requires a trade-off.

Do not refactor unrelated code without authorization. When touching existing
code, make small local improvements only when they do not broaden the task or
obscure the requested change.

When a missing requirement would materially change the implementation, obtain
direction rather than inventing a product rule.

For a feature, implement the requested behavior directly within the existing
architecture. For a reported bug, fix the cause and check related code for the
same failure mode. For architecture discussions, recommend the readable option
that minimizes maintenance burden. Apply small local cleanup only when it does
not broaden the task.

## Review and completion

Before completing work, verify that:

- the implementation meets the requested behavior;
- callers, imports, and tests remain consistent with the change;
- names, function boundaries, and control flow make the code understandable;
- comments explain only non-obvious context;
- error paths and relevant edge cases are handled; and
- the relevant build, test, lint, or type-check command has run when available.

Resolve a failed relevant check before reporting completion. Confirm that
cleanup is complete and that the change will remain understandable at a
substantially larger usage volume.
