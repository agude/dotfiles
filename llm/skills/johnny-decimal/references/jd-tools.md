# Local JD Tools

Use this file when operating on the local filesystem or JDex. The bundled
scripts are the execution layer; use them instead of constructing ad hoc
filesystem commands.

## Commands

`$SKILL_DIR` is the absolute directory containing this skill's `SKILL.md`.
Resolve it before running a bundled script. Run the script from the target
project directory.

| Command | Purpose |
| --- | --- |
| `jd-search.sh <query>` | Find folders by name or ID fragment |
| `jd-list.sh [area\|category\|ID]` | List a location |
| `jd-tree.sh [-L depth] [ID]` | Display the directory structure |
| `jd-validate.sh <filename>` | Check a filename |
| `jd-mkdir.sh <category\|ID> <name>` | Create a numbered subcategory or subfolder |
| `jd-inbox.sh <source...>` | Move files to the system inbox |
| `jd-move.sh <source...> <ID>` | Move and optionally rename files |
| `jd-read.sh [ID]` | Read a JDex note |
| `jd-note.sh [ID] <text>` | Append a dated JDex note |

Use `references/FILING-GUIDE.md` to choose a destination and
`references/NAMING.md` to choose a final filename.

## Agent mode

Pass `--porcelain` to every script when an agent is consuming the result:

- Paths are absolute and undecorated.
- Output has no colors or interactive prompts.
- Errors go to stderr and set a non-zero exit code.
- Supply every required input as an argument.
- `jd-note.sh` requires note text.
- `jd-read.sh --porcelain` returns the note file path.

Use the output as data. Do not parse human-oriented colored output. If a
bundled script cannot perform an inspection or change, identify the missing
tooling instead of substituting an ad hoc filesystem command.

## Safe filing workflow

1. Inspect the source document or its contents.
2. Read the local JDex flowchart and identify the target ID.
3. Run `jd-list.sh <ID> --porcelain` and inspect the target's naming pattern.
4. Choose a meaningful final filename. A scan-date filename is temporary.
5. Move and rename the file in one operation:
   `jd-move.sh <source> <ID> --name <filename> --porcelain`.
6. Verify the destination with `jd-list.sh <ID> --porcelain` or the relevant
   JDex note with `jd-read.sh <ID> --porcelain`.

Use `--dry-run` where supported before a batch or unfamiliar operation. The
scripts refuse to overwrite existing files and validate paths. Do not call
`mv` directly for JD filing.

## Human mode

Without `--porcelain`, interactive commands may browse the hierarchy, open an
editor, and display colored short paths. This mode is for a human at a TTY.
