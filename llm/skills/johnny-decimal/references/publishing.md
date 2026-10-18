# Publish the skill to Documents

`.dotfiles/llm/skills/johnny-decimal/` is the authoritative source. Edit and
test it there, then publish ordinary files to both NAS copies:

```bash
just publish-jd --dry-run
just publish-jd
just publish-jd --documents /path/to/Documents --dry-run
XDG_DOCUMENTS_DIR="/path/to/shared Documents" just publish-jd --dry-run
```

The destination root must exist. It defaults to `XDG_DOCUMENTS_DIR` or
`~/Documents`. `just` does not preserve quoting in `--documents`, so set
`XDG_DOCUMENTS_DIR` for a path that contains spaces. The publisher copies
runtime resources to `<Documents>/.agents/skills/johnny-decimal/` and
`<Documents>/.claude/skills/johnny-decimal/`, excluding tests. It seeds a
missing root `AGENTS.md` from `llm/johnnydecimal/workspace/`, which Codex and
Claude Code both read. An existing `AGENTS.md` is preserved; reconcile
instruction updates separately. Sibling skills and normal dotfiles
installation are left alone.

## Updates and recovery

A manifest rejects edits, additions, and deletions in either deployed copy.
Reconcile local edits into dotfiles before updating; an unmanaged destination
is also refused. Both destinations are checked before publication starts.
Unchanged copies are left alone.

Updates retain the previous version under each target's `skill-backups/`
directory, outside `skills/`. Remove old backups manually when no longer
needed. Each target is replaced separately; publication is not a transaction
across both apps. A complete copy is staged before replacement, but the rename
sequence briefly leaves the destination absent. Avoid starting skill commands
during publication.

Failed replacement attempts to restore the old copy. A killed process or
disconnected share can require recovery from the reported backup directory.
Inspect the live copy and backups, confirm no publisher is running, then remove
a stale `.publish-jd.lock` under `.agents/` or `.claude/` if necessary. Check the
live state before restoring a backup to the skill path.

## Discovery

Open Documents as the workspace and check the loaded `SKILL.md` path. Codex's
workspace copy is under `.agents/skills`; Claude's is under `.claude/skills`.
Global and workspace copies can coexist, so confirm the selected source.
Restart the client if an update is not visible. Both deployed copies remain
on the NAS. Report the actual app, workspace, and source paths when
diagnosing discovery. See the
[Codex skills guide](https://learn.chatgpt.com/docs/build-skills) and
[Claude Code skills documentation](https://code.claude.com/docs/en/skills).

The agent execution environment and integrated terminal can differ. Confirm
where agent commands run rather than inferring it from the terminal setting.
See the [Codex Windows app guide](https://learn.chatgpt.com/docs/windows/windows-app).

## Validation

In dotfiles, run `just test-publish-jd test-jd-portable test-shell` and the
repository's `just check` gate. Hosted Windows CI exercises the publisher and
portable runtime on a local Windows filesystem. It does not verify NAS access
or GUI discovery. See `runtime.md` for interpreter selection.

On each actual target machine:

1. Confirm the loaded skill path and interpreter version.
2. Run `list` and `search 00.00` against the intended root with `--porcelain`.
3. Create a uniquely named disposable JD fixture on the share, with a JDex,
   category, ID, and ownership marker. Set `JD_ROOT` and `JDEX_PATH` for test
   child processes only; unset `JD_CONFIG` in those processes.
4. Test mkdir, dry-run move, move, collision rejection, and dated note appends.
   Verify file bytes, exact note history, and line endings.
5. Verify ownership before removing only that fixture. Restore environment
   values if the session changed them.
6. Report app, paths, interpreter, package hash, results, and execution
   approvals. Leave unavailable checks explicitly pending.
