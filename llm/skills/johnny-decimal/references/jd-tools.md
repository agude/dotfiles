# Local JD Tools

The bundled `scripts/jd.py` implements the filesystem and JDex operations.
It requires Python 3.10 or newer and only the standard library. No Bash,
`tree`, or other Unix utilities are required for this entry point.

## Invocation

Resolve `SKILL_DIR` to the absolute directory containing the loaded `SKILL.md`.
Keep the working directory in the target project. The variable below is a local
example; agent hosts do not set it automatically.

Unix shells, using uv:

```bash
uv run --no-project "$SKILL_DIR/scripts/jd.py" search bank --porcelain
```

Windows PowerShell, using uv:

```powershell
uv run --no-project "$SKILL_DIR/scripts/jd.py" search bank --porcelain
```

With an existing Python 3.10+ installation, replace `uv run --no-project` with
`python3` on Unix or `py -3` on Windows. Both execute the same script.
Confirm the interpreter version before use. The `jd-*.sh` entry points retain
existing Unix command names and arguments; they call the same Python runtime.

## Commands

Append a command and its arguments after the absolute `jd.py` path:

| Command | Purpose |
| --- | --- |
| `search <query>` | Find folders by name or ID fragment |
| `list [area|category|ID]` | List areas, categories, or IDs; return the ID directory in agent mode |
| `list <ID> --files` | List the immediate contents of an ID, including files |
| `tree [-L depth] [area|category|ID]` | Display directories to the requested depth |
| `validate <filename...>` | Check filenames; return OK/WARN/ERROR records |
| `mkdir <category|ID> <name> [--id N]` | Create a numbered ID or a folder inside an ID |
| `inbox <source...>` | Move items to the system inbox, 00.01 |
| `move <source...> <ID> [--name filename] [--subdir path]` | Move items to an ID, optionally renaming one item |
| `read [ID]` | Read a JDex note; return its path in agent mode |
| `note [ID] <text>` | Append a dated note or create one |

Use `references/FILING-GUIDE.md` to choose a destination and `references/NAMING.md`
to choose a final name. `--help` lists command options.

## Agent mode

Pass `--porcelain` to every operation consumed by an agent:

- Paths are absolute and undecorated. `tree` emits one absolute directory per line.
- Filename validation returns `OK:filename`, `WARN:filename:reason`, or
  `ERROR:filename:reason`. Warnings succeed; errors return nonzero.
- Diagnostics go to stderr and failures return nonzero.
- No command prompts. Supply an ID and note text for note operations.
- `read` returns the note path. A missing note reports a diagnostic and succeeds.
- `list ID` returns the ID directory; add `--files` to inspect its contents.

Without `--porcelain`, `list`, `read`, and `note` can browse through numbered
menus when stdin and stdout are terminals. `read --edit` opens the configured
editor; `note` with no text opens a temporary draft. `EDITOR` or `VISUAL` selects
the editor, defaulting to `vi` on Unix or Notepad on Windows. Set either to an
executable path, including a Windows path containing spaces; Unix command strings
may also include arguments.

## Safe filing workflow

1. Inspect the source document or its contents.
2. Read the JDex flowchart and identify the target ID.
3. Run `list <ID> --files --porcelain` and inspect the naming pattern.
4. Choose a meaningful final filename; inbox scan dates are temporary names.
5. Preview an unfamiliar move with
   `move <source> <ID> --name <filename> --dry-run --porcelain`.
6. Apply the same move without `--dry-run`.
7. Verify with `list <ID> --files --porcelain` or `read <ID> --porcelain`.

`mkdir`, `move`, and `inbox` accept `--dry-run`; a dry run creates no destination
folders. Moves validate every source and destination before starting. Files are
copied before their sources are removed, so interruption can leave a partial
batch or duplicate; batch moves are not transactions. Verify before retrying.
Existing targets are refused unless `--force` explicitly replaces a regular
file. Directory merging and symlink targets are refused. Name and collision
checks apply Windows restrictions on every host. Relative `--subdir` paths may
use either slash style but cannot escape the target ID.

Note appends use a per-ID lock under the JDex. If a process is interrupted and
leaves `.XX.YY.lock`, confirm no writer is running before removing the stale
lock. Existing note history is appended to, not rewritten.
