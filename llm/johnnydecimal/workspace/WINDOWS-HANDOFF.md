# Johnny.Decimal Windows handoff

## Goal and scope

Open this NAS Documents folder as the workspace in Codex or the Local Code tab
of Claude Desktop. Inspect the existing setup, find an available Python runtime,
and test the shared scripts from Windows. The skills and scripts stay here on
the NAS. A launcher and additional runtime packaging are deferred until the
Windows environment has been examined.

## Files already prepared

```text
Documents/
  AGENTS.md
  CLAUDE.md
  WINDOWS-HANDOFF.md
  .agents/skills/johnny-decimal/
    SKILL.md
    references/
    scripts/jd.py
  .claude/skills/johnny-decimal/
    SKILL.md
    references/
    scripts/jd.py
```

Both skill copies contain the same ordinary files. `jd.py` uses Python 3.10+
and only the standard library; it has no third-party package requirements. Its
location beneath either `.agents/skills` or `.claude/skills` determines the
Documents root. Explicit `JD_ROOT`, `JDEX_PATH`, and `JD_CONFIG` override defaults.
The `jd-*.sh` files are compatibility commands for Unix users; Windows agents
should invoke `jd.py` with an available interpreter directly.

Source lives on branch `feature/johnny-decimal-portability` in the Linux
`.dotfiles` repository. `just publish-jd` copies runtime files to both NAS skill
locations and seeds missing workspace instructions. Existing root instructions
and this handoff are preserved. The publisher refuses to overwrite local skill
changes and retains previous versions under each host's `skill-backups` folder.
To change a deployed file from Windows, record the path and diff so it can be
reconciled into dotfiles before the next publication. Avoid divergent fixes in
the two skill copies.

## Find the runtime before changing the machine

1. Record the application/version, agent execution environment, PowerShell
   version, and actual workspace path. Distinguish native Windows from WSL or
   remote execution. A GUI terminal setting alone does not establish where the
   agent's commands execute.
2. Check for commands already available to the agent:

   ```powershell
   Get-Command python, python3, py, uv -ErrorAction SilentlyContinue
   ```

   Probe a candidate by its full executable path. Do not rely on the Windows
   Store alias being a working interpreter.

3. In Codex, inspect its app-managed Workspace Dependencies and this observed
   runtime location, without assuming it exists or is stable:

   ```powershell
   $Python = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
   Test-Path -LiteralPath $Python
   ```

   Windows users have reported direct execution through this interpreter:
   [runtime contents](https://github.com/openai/codex/issues/51093),
   [execution report](https://github.com/openai/codex/issues/21470).
   These are observed app paths, not a guaranteed public runtime interface.

4. In Claude Code Local, inspect the runtime actually available to its shell.
   A host-callable bundled Python has not been verified. Do not infer one from
   Cowork's separate execution environment or from a package used by a plugin.
5. For the chosen executable, print its version and path and confirm the
   required standard-library imports:

   ```powershell
   & $Python -c 'import sys, pathlib, json, shutil, argparse; print(sys.executable); print(sys.version); assert sys.version_info >= (3, 10)'
   ```

   `$Python` above is the confirmed full executable path, not an automatically
   supplied variable. If only uv is available, use `uv run --no-project` to run
   the script and record whether it needs a Python download. If no runtime is
   usable, report that result before choosing installation or packaging work.

## Test from the opened Documents folder

Use the path of the skill loaded by the app. For example, Codex:

```powershell
$SkillDir = Join-Path (Get-Location) '.agents/skills/johnny-decimal'
& $Python -B "$SkillDir/scripts/jd.py" --help
& $Python -B "$SkillDir/scripts/jd.py" list --porcelain
& $Python -B "$SkillDir/scripts/jd.py" search '00.00' --porcelain
```

For Claude Code, select `.claude/skills/johnny-decimal` instead. Confirm that
results point to this NAS workspace, including its JDex, rather than a local
Documents folder. Inspect any existing JD environment overrides if they differ.

Then create a uniquely named disposable fixture on the share, with an area,
category, ID, inbox, and JDex. For those test commands only, set `JD_ROOT` and
`JDEX_PATH` to the fixture. Exercise `mkdir`, dry-run `move`, actual `move`,
collision rejection, `note`, and `read`. Check bytes and note history. Restore
prior environment values and remove only the fixture created for this test.

## Record results here

The Linux `just check` gate, metadata validation, and disposable SMB fixture
passed before this handoff. Both published copies must still be tested in each
Windows GUI; Linux verification does not establish Windows sandbox behavior.

| Check | Codex Windows GUI | Claude Desktop Code Local |
| --- | --- | --- |
| App/version and workspace path recorded | Pending | Pending |
| Workspace instructions and correct skill loaded | Pending | Pending |
| Interpreter path/version and stdlib imports | Pending | Pending |
| Real NAS search/list returns the intended root | Pending | Pending |
| Disposable filing and note fixture passes | Pending | Pending |

Append the exact commands, paths, results, and any failure messages. Leave
unavailable checks pending. Keep secrets out of this handoff.
