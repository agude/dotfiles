# Local JD Tools

The bundled `scripts/jd.py` implements filesystem and JDex operations with
Python 3.10+ and the standard library. See `runtime.md` for interpreter
selection and root precedence. Use the absolute path of the loaded skill.

```powershell
# Windows: $Python and $SkillDir are paths established in this session.
& $Python -B "$SkillDir/scripts/jd.py" search bank --porcelain
```

```bash
# Unix: set SKILL_DIR to the loaded skill's absolute directory.
python3 -B "$SKILL_DIR/scripts/jd.py" search bank --porcelain
```

The `jd-*.sh` compatibility entry points call the same Python runtime.

## Target syntax

| Target | Meaning | Example |
| --- | --- | --- |
| `XX-YY` or `XX-` | Area | `20-29` or `20-` |
| `XX` | Category, including categories ending in zero | `00`, `10`, `21`, `90` |
| `XX.YY` | Full ID, including an existing legacy suffix | `21.10` |

A bare `20` means category 20. Use `20-29` to select the finance area.
`search` additionally accepts name fragments and ID prefixes. `list` and
`tree` resolve a single target; `move`, `read`, and `note` require full IDs.

## Commands

Append a command and its arguments after the `jd.py` path:

| Command | Purpose |
| --- | --- |
| `search QUERY` | Find JD folders by name fragment or ID prefix |
| `list [TARGET]` | List areas, categories, or IDs; `list ID --porcelain` returns the ID directory |
| `list ID --files` | List the immediate contents of an ID, including files |
| `tree [TARGET] [-L DEPTH]` | Display directories, bounded to DEPTH levels (default 2) |
| `validate FILENAME...` | Check filenames; return OK/WARN/ERROR records |
| `mkdir CATEGORY NAME [--id NUMBER]` | Create a numbered ID in a category |
| `mkdir ID NAME` | Create a folder inside an existing ID |
| `inbox SOURCE...` | Move items to the system inbox, 00.01 |
| `move SOURCE... ID [--name FILENAME] [--subdir PATH]` | Move items to the final positional ID; optionally rename one item |
| `read [ID]` | Read a JDex note; return its path in agent mode |
| `note [ID] TEXT` | Append a dated note or create one |

Use `jd.py COMMAND --help` for options and accepted arguments. `--name`
requires one source; `--subdir` is relative to the target ID. New numeric ID
suffixes have at least two digits: `--id 5` creates `XX.05`. Existing names are
preserved and numeric duplicates such as `.5` and `.05` are refused. Automatic
allocation starts at `.10`, or one above the highest existing suffix.
Filename warnings for undated transient documents match words such as
`statement`, `receipt`, and `invoice` regardless of case.

## Agent output

Use `--porcelain` when consuming paths or checking operation results:

- Paths are absolute and undecorated. `tree` emits one absolute directory per line.
- Windows paths can resolve from a mapped drive to UNC form; use the returned
  path directly. Both forms can identify the same share.
- Filename validation returns `OK:filename`, `WARN:filename:reason`, or
  `ERROR:filename:reason`. Warnings succeed; errors return nonzero.
- Diagnostics go to stderr and failures return nonzero.
- No command prompts. Supply an ID and note text for note operations.
- `read` returns the note path. A missing note reports a diagnostic and succeeds.
- `list ID` returns the ID directory; add `--files` to inspect its contents.

Plain `list` or `tree` output can show a readable overview to the user. For
agent inspection, prefer JD `search`, `list`, and bounded `tree` calls over
recursive searches from the NAS root. Narrow any further inspection to known
files or directories.

Without `--porcelain`, `list`, `read`, and `note` can browse through numbered
menus when stdin and stdout are terminals. `read --edit` opens the configured
editor; `note` with no text opens a temporary draft. `EDITOR` or `VISUAL` selects
the editor, defaulting to `vi` on Unix or Notepad on Windows. Set either to an
executable path, including a Windows path containing spaces; Unix command strings
may also include arguments.

## Safe filing workflow

1. Inspect the source document or its contents.
2. Read the JDex flowchart and identify the target ID.
3. Run `list ID --files --porcelain` and inspect the naming pattern.
4. Choose a meaningful final filename using `NAMING.md`; inbox scan dates are temporary.
5. Preview an unfamiliar move with
   `move SOURCE ID --name FILENAME --dry-run --porcelain`.
6. Apply the same move without `--dry-run`.
7. Verify with `list ID --files --porcelain` or `read ID --porcelain`.

`mkdir`, `move`, and `inbox` accept `--dry-run`; a dry run creates no destination
folders. Moves validate every source and destination before starting. Files are
copied before their sources are removed, so interruption can leave a partial
batch or duplicate; verify before retrying. Existing targets are refused unless
`--force` explicitly replaces a regular file. Directory merging and symlink
targets are refused. Name and collision checks apply Windows restrictions on
every host. Relative `--subdir` paths may use either slash style but cannot
escape the target ID.

## Note bytes and spacing

New notes use UTF-8 without a BOM and LF line endings on every host. Appending
preserves every existing byte and uses the first existing line ending (LF or
CRLF) for additions. If there is no line ending yet, additions use LF. Note text
is converted to that style. Existing extra blank lines are preserved; appends
add only enough line endings to leave one blank line before the next block.
A second entry on the same day reuses the existing date heading.

Note appends use a per-ID lock under the JDex. If a process is interrupted and
leaves `.XX.YY.lock`, confirm no writer is running before removing the stale
lock. Existing note history is appended to, not rewritten.
