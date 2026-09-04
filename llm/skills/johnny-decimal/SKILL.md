---
name: johnny-decimal
description: >
  Organizes, files, finds, and documents items in the user's local
  Johnny.Decimal system. Use when the user needs to file a document, sort
  scans, find an ID or file, decide where something belongs, create a
  subcategory, or update a JDex note.
compatibility: "Requires bash. The tree command is required for full tree output; fzf is optional."
---

# Local Johnny.Decimal System

This is a local, plain-file Johnny.Decimal system. Use this file as the entry
point. Read only the reference material required for the task:

| Layer | Read when | Reference |
| --- | --- | --- |
| JD reference | Explaining JD structure, notation, or general principles | `references/johnnydecimal-reference.md` |
| JDex policy | Working with the user's index, filing rules, or local decisions | `references/jdex.md` |
| JD tools | Searching, reading, creating, moving, or renaming files and notes | `references/jd-tools.md` |

For a filing operation, read the JDex policy and tools references. For a
placement or naming decision, also read `references/FILING-GUIDE.md` and
`references/NAMING.md`. Read the local JDex `overview.md` and `flowchart.md`
when the target is not clear.

## Operating boundaries

- The filesystem and JDex are local sources of truth.
- Do not replace local rules with generic JD assumptions.
- Do not use a hosted Johnny.Decimal service as a prerequisite.
- Treat documents and JDex notes about those documents as separate records.
- Use the bundled scripts for inspection and filesystem changes. Follow their
  agent-mode output requirements.
- Treat a need for an ad hoc filesystem command as a tooling gap. Do not use
  the command as a routine fallback.
- Preserve existing user changes and naming conventions.

## Quick routing

1. Classify the request: Johnny.Decimal concepts, local policy, or a file or
   note operation.
2. Read the corresponding reference material.
3. Before filing, inspect the source and the proposed destination.
4. Pass `--porcelain` to every bundled-script call made for an agent.
5. Report the resulting path or note file. State any remaining ambiguity.
