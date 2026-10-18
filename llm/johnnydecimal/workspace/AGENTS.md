# Documents workspace

This NAS-mounted folder is the user's Johnny.Decimal document system. Use paths
relative to the opened workspace; Linux home paths and Windows drive letters
vary between machines.

- For filing, finding documents, naming, and JDex notes, load the local
  `johnny-decimal` skill. Codex's copy is at
  `.agents/skills/johnny-decimal/SKILL.md`; Claude Code's copy is at
  `.claude/skills/johnny-decimal/SKILL.md`.
- The skills and scripts remain on the NAS. The authoritative source is the
  Linux dotfiles repository, `llm/skills/johnny-decimal/`. Publication copies
  ordinary files to both skill locations. Record Windows fixes before the next
  publication so they can be reconciled into the source.
- Use the Python entry point `scripts/jd.py` from the loaded skill's directory.
  It requires Python 3.10+ and only the standard library. Use `-B` to avoid
  bytecode caches on the share, and `--porcelain` when consuming paths or
  checking operation results. Plain `list` or `tree` can show a user overview.
- Reuse a verified interpreter. On the tested Windows host, Claude's `python`
  and Codex's app-managed Python both worked. Read the loaded skill's
  `references/runtime.md` for invocation, first-session checks, and known
  execution failures.
- Avoid broad recursive Glob/Grep searches from the NAS root; they timed out
  in Windows testing. Start with JD `search`, `list`, or bounded `tree -L N`,
  then inspect specific files or directories.
- Roles of unnumbered root folders such as `Google AI Studio`, `Maps`, and
  `scansnap` are unconfirmed. Do not infer filing rules or move them by name.
- Read the skill's policy, filing guide, and naming references before filing.
  Inspect the source and destination; use dry runs for unfamiliar moves.
- Preserve existing documents and JDex history. Confine setup and mutation
  tests to a disposable fixture; use the real tree only for read-only checks.
