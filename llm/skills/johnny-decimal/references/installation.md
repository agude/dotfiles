# Share the skill through Documents

`.dotfiles/llm/skills/johnny-decimal/` is the authoritative source. Publish
ordinary files to the NAS-mounted Documents workspace; edit and test the source
before publishing an update.

## Publish from dotfiles

```bash
just publish-jd --dry-run
just publish-jd
just publish-jd --documents "/path/to/shared Documents" --dry-run
```

The destination root must exist. It defaults to `XDG_DOCUMENTS_DIR` or
`~/Documents`. The publisher copies runtime resources to
both `<Documents>/.agents/skills/johnny-decimal/` and
`<Documents>/.claude/skills/johnny-decimal/`, excluding tests. It seeds missing
`AGENTS.md`, `CLAUDE.md`, and `WINDOWS-HANDOFF.md` from the dotfiles templates in
`llm/johnnydecimal/workspace/`; existing workspace instructions and handoff
results are preserved. It leaves sibling skills and normal dotfiles installation alone. Only explicit publication writes
to the shared workspace.

A manifest rejects edits, additions, and deletions in the deployed copy.
Reconcile edits into dotfiles before updating; an unmanaged destination is also
refused. Unchanged copies are left alone. Updates retain the previous version
under each target's `skill-backups/` directory, outside `skills/`. Remove old
backups manually when they are no longer needed. After an interrupted publication, inspect the live copy
and backups and confirm no publisher is running before removing
the target's `.publish-jd.lock` under `.agents/` or `.claude/`.

Both destinations are checked for local changes before publication starts.
Each target is replaced separately; publication is not a transaction across
both apps.
The publisher stages a complete copy before replacing the deployed directory.
The rename sequence briefly leaves the destination absent; avoid starting a
skill command during an update. Failed replacement attempts to restore the old
copy. A killed process or disconnected share can require recovery from the
reported backup directory. Copy the backup back to the skill path only after
checking the live state.

## Runtime on each machine

Use a Python 3.10+ interpreter available to the agent. The skill needs only the
standard library. Windows does not require Bash or WSL for `scripts/jd.py`.
Before installing tools, read the root `WINDOWS-HANDOFF.md` and inspect the
existing environment, including Codex's app-managed interpreter where present.
A host-callable bundled Python in Claude Code Local remains unverified.
A launcher and additional runtime packaging are deferred.

Once an interpreter path is confirmed, invoke it directly from PowerShell:

```powershell
& $Python -B "$SkillDir/scripts/jd.py" list --porcelain
```

`$Python` and `$SkillDir` are paths established in the current session, not
variables supplied by the app. Existing uv or Python commands can also be used.
Keep agent authentication, sessions, and caches local to the machine.

From PowerShell in the shared Documents workspace:

```powershell
$SkillDir = Join-Path (Get-Location) '.agents/skills/johnny-decimal'
uv run --no-project "$SkillDir/scripts/jd.py" list --porcelain
uv run --no-project "$SkillDir/scripts/jd.py" search bank --porcelain
```

If uv is unavailable and Python 3.10+ is installed, use:

```powershell
py -3 "$SkillDir/scripts/jd.py" list --porcelain
```

Use the path exposed to the agent environment: a mapped drive or UNC path for
native Windows, or the share's Linux mount for a Linux/WSL agent. Confirm that
the agent can read and write that path. A successful local Python test does not
verify access through the Windows app sandbox.

## Root selection

The portable runtime resolves its physical script location. A script deployed
under `<Documents>/.agents/skills/<skill>/scripts/` or
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

## Verify discovery on each client

Open the shared Documents root as the workspace. Check the client's skill list
for Johnny.Decimal and inspect the source path of the loaded `SKILL.md`.
Codex can expose two copies with the same name when global and workspace
installations coexist; verify which copy is selected. Restart the client if an
update is not visible. These behaviors are documented in
[OpenAI's skills guide](https://learn.chatgpt.com/docs/build-skills).

The corresponding Claude Code location is `.claude/skills`; see
[Anthropic's skill documentation](https://code.claude.com/docs/en/skills).
Both copies remain on the NAS. If discovery fails, record the actual app,
workspace, and source paths in `WINDOWS-HANDOFF.md` and diagnose that setup
before selecting another installation layout.

The app's agent environment and integrated terminal are independent settings;
check the agent environment when diagnosing access. See
[OpenAI's Windows app guide](https://learn.chatgpt.com/docs/windows/windows-app).

## Validation

In dotfiles, run `just test-publish-jd test-jd-portable test-shell` and the
repository's `just check` gate. Hosted Windows CI exercises the publisher and
portable runtime on a local Windows filesystem. It does not verify NAS access
or GUI discovery.

On each actual target machine:

1. Confirm the skill's loaded source path and interpreter version.
2. Run `list` and `search` against the intended root with `--porcelain`.
3. Create a disposable JD fixture in a separate folder on the share, with a
   JDex, a category, and an ID. Set `JD_ROOT` and `JDEX_PATH` for those test
   commands only.
4. Test mkdir, dry-run move, move, collision rejection, and dated note appends
   in that fixture. Verify bytes and note history after each operation.
5. Publish an update; verify the client loads the updated package.
6. Record the actual path, runtime, and results. Leave unavailable checks
   explicitly pending.
