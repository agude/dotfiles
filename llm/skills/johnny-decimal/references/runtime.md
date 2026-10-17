# Run the shared skill

Use a Python 3.10+ interpreter available to the agent. The skill needs only the
standard library. Reuse a verified executable; Windows does not require Bash,
WSL, uv, or a launcher for `scripts/jd.py`.

## Windows interpreters

The following worked in native Windows GUI sessions on 2026-10-17. These are
observations from the tested machine, not guaranteed paths on every host.

| App | Verified invocation | Python |
| --- | --- | --- |
| Codex Windows GUI | App-managed executable below | 3.12.14 |
| Claude Desktop, Code tab, Local | `python -B` (Microsoft Store installation) | 3.13.14 |

Claude's plain `python` command worked in Windows PowerShell 5.1. A
host-callable Python bundled with Claude has not been established. `py`, `uv`,
and `bash` were absent in that session. Try the existing `python` before
choosing another runtime.

For Codex, inspect Workspace Dependencies. The tested interpreter was:

```powershell
$Python = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
```

This is an observed internal path. Confirm it exists and runs; use the current
Workspace Dependencies path if it differs. To inspect other candidates:

```powershell
Get-Command python, python3, py, uv -ErrorAction SilentlyContinue
python -c 'import sys; print(sys.executable); print(sys.version); assert sys.version_info >= (3, 10)'
```

A Windows Store alias can exist without a working interpreter. Verify execution
rather than relying on `Get-Command` alone. Set `$Python` to the executable
confirmed by `sys.executable`, then reuse it:

```powershell
& $Python -B "$SkillDir/scripts/jd.py" list --porcelain
& $Python -B "$SkillDir/scripts/jd.py" search '00.00' --porcelain
```

`$Python` and `$SkillDir` are session variables, not app-provided values.
`$SkillDir` must identify the loaded `.agents/skills/johnny-decimal` or
`.claude/skills/johnny-decimal` directory in Documents. Absolute results can be
UNC paths even when the workspace was opened as `Z:\Documents`; the tested
mapping resolved to `\\synology\home\Documents`. Keep returned paths quoted
and use them directly.

Claude's real writes passed under normal execution. Codex's disposable tests
passed with approved escalation; its normal restricted-token launch reported
`UnsupportedOperation("windows unelevated restricted-token sandbox cannot enforce split writable root sets directly; refusing to run unsandboxed")`.
That is a command-launch issue, not a Python import failure. Keep normal Codex
launch validation pending until it passes. The root `WINDOWS-HANDOFF.md` holds
the full commands, versions, hashes, and results; consult it for failures or
historical test evidence.

## Unix and optional uv

```bash
python3 -B "$SKILL_DIR/scripts/jd.py" list --porcelain
```

If only uv is available, use:

```bash
PYTHONDONTWRITEBYTECODE=1 uv run --no-project "$SKILL_DIR/scripts/jd.py" list --porcelain
```

`uv run` may download a runtime when none is installed. Inspect the existing
environment before adding tools. Keep agent authentication, sessions, and
caches local to the machine.

## Root selection

The runtime resolves its physical script location. A script deployed under
`<Documents>/.agents/skills/<skill>/scripts/` or
`<Documents>/.claude/skills/<skill>/scripts/` derives its root from that
Documents directory. A global symlink pointing into dotfiles resolves to the
source checkout and uses host configuration instead.

Precedence:

1. Explicit `JD_ROOT` and `JDEX_PATH` override the corresponding paths.
2. An explicitly selected `JD_CONFIG` supplies configured paths, even for a
   deployed copy. Missing values fall through to the following defaults.
3. A deployed copy uses its containing Documents root and the JDex beneath it;
   it ignores the host's implicit configuration file.
4. A global source installation reads the default
   `$XDG_CONFIG_HOME/johnnydecimal/config.json` (`~/.config/...` by default),
   then falls back to `XDG_DOCUMENTS_DIR` or `~/Documents`.

Config properties `root` and `jdex` are JSON strings. `$HOME`,
`$XDG_DOCUMENTS_DIR`, `$XDG_CONFIG_HOME`, and their `${...}` forms expand without
shell evaluation. On Windows, JSON backslashes must be escaped; forward slashes
are also accepted. The default JDex relative path is
`00-09 System/00 System/00.00 JDex for System`.

The shell navigation helper `bin/jd.sh` retains its existing shell configuration.
Use the portable runtime for the shared skill's operations.

## First-session checks

1. Open the shared Documents root and confirm the loaded `SKILL.md` source path.
2. Confirm the interpreter version once, then reuse that executable.
3. Run `list --porcelain` and `search 00.00 --porcelain` against the intended
   root. Inspect existing JD environment overrides if results point elsewhere.
4. Use bounded JD commands for inspection. Broad recursive Glob/Grep calls
   from the NAS root timed out in Windows testing.

For validation after a publication, use the root `for-claude.md` when present,
or the disposable-fixture procedure in `publishing.md`. Record which package
hash was tested. Earlier Windows passes do not validate a newer script.
