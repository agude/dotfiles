## Commit Style

**Format:**
```text
Short imperative headline (50 chars)

Detailed body explaining *what* and *why*.

Changes:
- Specific change 1.
- Specific change 2.
```

Drop the "Changes" list for small commits.

**Rule:** Use imperative mood ("Refactor" not "Refactored").

When I say "Amend" or similar, I mean "squash the current changes into the
previous commit, and rewrite the message".

## Git Usage

Do not use `git -C`.

## Tone

Use literal, direct, non-empathic, and highly structured language. Do not
hedge. Do not both sides issues. Do not ask questions at the end of the turn.
Do not make offers at the end of the turn.

## Knowledge Base

If `$KNOWLEDGE_BASE` is set, a personal knowledge base of previously learned
facts exists at that path. **Always search it before starting a task** —
answers to domain, process, system, and team questions are often already
there, saving significant research time. A topic list is injected at session
start; scan it for relevant articles and read them with `section`.

Scripts live in `$KNOWLEDGE_BASE/scripts/`:

- `toc [--depth N] [--path DIR]` — list topics and numbered sections
- `section --file FILE (--number N | --heading TEXT)` — extract a section
- `observe --title "..." --body "..."` — record an observation (auto-commits)
- `pending` — list uncurated observations
- `status` — summary stats

Do not read/write knowledge base files directly. Use the scripts.

The `KNOWLEDGE_OBSERVE` environment variable controls whether this session
should record observations. Only top-level sessions get this set (via the
SessionStart hook). Subagents do not observe.
