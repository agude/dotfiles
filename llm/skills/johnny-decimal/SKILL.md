---
name: johnny-decimal
description: >
  Organizes, files, finds, and documents items in the user's local
  Johnny.Decimal system. Use when the user needs to file a document, sort
  scans, find an ID or file, decide where something belongs, create a
  subcategory, or update a JDex note.
compatibility: "Requires Python 3.10+ or uv. Unix compatibility wrappers also require Bash."
---

# Local Johnny.Decimal System

The filesystem and JDex are the sources of truth. Use the loaded skill's
`scripts/jd.py` for document operations. It uses Python 3.10+ and the standard
library; Windows agents can invoke it directly from PowerShell.

## Start here

Resolve the absolute directory containing this loaded `SKILL.md`. Reuse an
interpreter already verified in the session. On the tested Claude Windows
host, `python` works; Codex has an app-managed Python. See
`references/runtime.md` for those paths and root selection before installing
anything.

On Windows, set `$SkillDir` to the loaded skill directory. With a verified
`python` on PATH (Claude's tested setup):

```powershell
python -B "$SkillDir/scripts/jd.py" list --porcelain
python -B "$SkillDir/scripts/jd.py" search '00.00' --porcelain
```

For Codex's app-managed executable, set `$Python` to its confirmed path and
replace `python` with `& $Python`. These are session variables, not app defaults.

For the first use in a session, confirm the interpreter is Python 3.10+ and
these results identify the opened Documents workspace and its JDex. On Unix,
use `python3 -B` with the same script and arguments. `-B` avoids bytecode caches
on the share. Paths may resolve from a mapped drive to a UNC path on Windows;
use the returned absolute paths.

Use `--porcelain` when consuming paths or checking command results. Plain
`list` or `tree` output is also suitable for a user-facing overview. Avoid
broad recursive Glob/Grep searches from the NAS root: they timed out in Windows
testing. Start with JD `search`, `list`, or `tree -L N`; inspect known files or
specific directories when more detail is needed.

## Read for the task

| Read when | Reference |
| --- | --- |
| Explaining JD structure, notation, or general principles | `references/johnnydecimal-reference.md` |
| Applying the user's index, filing rules, or local decisions | `references/jdex.md` |
| Searching, reading, creating, moving, or renaming files and notes | `references/jd-tools.md` |
| Choosing a destination or filename | `references/FILING-GUIDE.md` and `references/NAMING.md` |
| Selecting an interpreter, resolving roots, or diagnosing execution | `references/runtime.md` |
| Updating the shared copies from dotfiles | `references/publishing.md` |

For filing, read the JDex policy and tools references. Read the local JDex
`overview.md` and `flowchart.md` when the target is unclear.

## Operating boundaries

- Follow local rules and preserve existing user changes and naming conventions.
- Treat documents and JDex notes about those documents as separate records.
- Inspect the source and proposed destination before filing. Use a dry run for
  unfamiliar moves, then verify the result.
- Treat a need for an ad hoc filesystem command as a tooling gap; record it.
- Unnumbered root folders such as `Google AI Studio`, `Maps`, and `scansnap`
  have unconfirmed roles. Do not infer filing rules or move them from their names.
- Confine setup and mutation tests to a disposable fixture.
- Report the resulting file or note path and any unresolved placement decision.
