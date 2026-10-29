## Commit Style

**Format:**
```text
Short imperative headline (reasonable length; no fixed limit)

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

## Artifacts

Don't rely on provider-specific artifact URLs; for most output I prefer simple
markdown.

<!-- kb:begin -->
The knowledge base holds durable facts from past sessions: systems, domain rules, people, and preferences. Search it before starting a task, and again whenever a task needs a fact it may hold.
Record a durable fact when you learn it, unless the knowledge base already holds it. Subagents do not record.
- `kb recall QUERY...`: find curated sections that answer a query.
- `kb read LOCATOR...`: print the text that each locator names.
- `kb map [PATH]`: list the articles under a path.
- `kb questions [--context PATH]`: list open questions.
- `kb evidence QUERY...`: search observations, transcripts, and questions.
- `kb observe --title TITLE --body TEXT`: record one observation.
- `kb gap --title TITLE --body TEXT --context PATH`: record a question that the knowledge base cannot answer.
`kb --help` and the skills hold the details. Content policy: @/home/agude/Knowledge/AGENTS.md
<!-- kb:end -->
