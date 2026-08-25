# Local JD Tools

Use this file when operating on the local filesystem or JDex. The bundled
scripts are the execution layer; use them instead of constructing ad hoc
filesystem commands.

## Commands

All scripts are in `${CLAUDE_SKILL_DIR}/scripts/`.

| Command | Purpose |
| --- | --- |
| `jd-search.sh <query>` | Find folders by name or ID fragment |
| `jd-list.sh [area\|category\|ID]` | List a location |
| `jd-tree.sh [-L depth] [ID]` | Display the directory structure |
| `jd-validate.sh <filename>` | Check a filename |
| `jd-mkdir.sh <category> <name>` | Create a numbered subcategory or subfolder |
| `jd-inbox.sh <source...>` | Move files to the system inbox |
| `jd-move.sh <source...> <ID>` | Move and optionally rename files |
| `jd-read.sh [ID]` | Read a JDex note |
| `jd-note.sh [ID] <text>` | Append a dated JDex note |

Use `references/FILING-GUIDE.md` for placement decisions and
`references/NAMING.md` for final filenames.

## Agent mode

Pass `--porcelain` to every script when an agent is consuming the result:

- paths are absolute and undecorated;
- output contains no colors or interactive prompts;
- errors go to stderr with a non-zero exit code;
- all required input must be supplied as arguments;
- `jd-note.sh` requires note text;
- `jd-read.sh --porcelain` returns the note file path.

Use the output as data. Do not parse human-oriented colored output.

## Safe filing workflow

1. Read the source document or inspect its contents.
2. Read the local JDex flowchart and identify the target ID.
3. List the target directory and inspect its naming pattern.
4. Choose a meaningful final filename; scan-date filenames are temporary.
5. Use `jd-move.sh` with the final name in the same operation.
6. Verify the destination with `jd-list.sh` or `jd-read.sh`.

Use `--dry-run` where supported before a batch or unfamiliar operation. The
scripts refuse to overwrite existing files and validate paths. Do not call
`mv` directly for JD filing.

## Human mode

Without `--porcelain`, interactive commands may browse the hierarchy, open an
editor, and display colored short paths. This mode is for a human at a TTY.
