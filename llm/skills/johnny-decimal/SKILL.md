---
name: johnny-decimal
description: >
  Organizes, files, finds, and documents items in the user's local
  Johnny.Decimal system. Use when the user needs to file a document, sort
  scans, find an ID or file, decide where something belongs, create a
  subcategory, or update a JDex note.
compatibility: "Requires bash. The tree command is required for full tree output; fzf is optional."
allowed-tools: "Bash(${CLAUDE_SKILL_DIR}/scripts/:*) Bash(ls:*) Bash(jd:*) Read"
---

# Local Johnny.Decimal System

This is a local, plain-file Johnny.Decimal system. This `SKILL.md` is the
entry point; load only the layer needed for the task:

| Layer | Read when | Reference |
| --- | --- | --- |
| JD reference | Explaining JD structure, notation, or general principles | `references/johnnydecimal-reference.md` |
| JDex policy | Working with the user's index, filing rules, or local decisions | `references/jdex.md` |
| JD tools | Searching, reading, creating, moving, or renaming files and notes | `references/jd-tools.md` |

For a filing operation, read the JDex and tools layers. For naming or a
specific placement decision, also read `references/FILING-GUIDE.md` and
`references/NAMING.md`. Read the local JDex `overview.md` and `flowchart.md`
when the current structure or filing decision is unclear.

## Operating boundaries

- The filesystem and JDex are local sources of truth.
- Do not replace local rules with generic JD assumptions.
- Do not use a hosted Johnny.Decimal service as a prerequisite.
- Treat actual documents and notes about those documents as different things.
- Use the bundled scripts for filesystem changes and follow their agent-mode
  output requirements.
- Preserve existing user changes and naming conventions.

## Quick routing

1. Identify whether the request is about JD concepts, the local JDex, or an
   operation on files and notes.
2. Read the corresponding layer reference.
3. For filing, inspect the source and target before changing anything.
4. Use `--porcelain` for agent-mode script calls.
5. Report the resulting path or note file and any unresolved ambiguity.
