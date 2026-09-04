# Local JDex Policy

Use this reference for the user's index, local filing decisions, and JDex
notes.

## Local locations

The default filesystem root is `~/Documents`, or `$XDG_DOCUMENTS_DIR` when it
is set. The local JDex is:

```text
00-09 System/00 System/00.00 JDex for System/
```

The JDex contains:

- `overview.md`: the current area and category structure.
- `flowchart.md`: the filing decision tree.
- `XX.YY.md`: notes and decisions about a specific ID.

## Configuration

The runtime configuration is `${XDG_CONFIG_HOME}/johnnydecimal/config.json`,
defaulting to `~/.config/johnnydecimal/config.json`. Set `JD_CONFIG` to use a
different file for testing or a separate local system.

The configuration supplies the filesystem root and JDex path as top-level
properties. Explicit `JD_ROOT` and `JDEX_PATH` environment variables take
precedence over the configuration file. The current local configuration
supports one system.

Read `overview.md` and `flowchart.md` when the current structure or a filing
decision is not obvious. The local structure takes precedence over generic
Johnny.Decimal examples.

## Local filing rules

1. **Person first.** File a record belonging to one person in that person's
   area.
2. **Purpose over provider.** File a bill by its purpose, not by the company
   that sent it.
3. **Separate notes from documents.** Store an ID note in the JDex and the
   associated document in the ID's filesystem folder.
4. **Maintain one source of truth.** Do not create duplicate files solely to
   expose an item in multiple locations. Use a JDex note or link instead.
5. **Stop when placement remains unclear.** Inspect the flowchart and target
   directory before moving a file. Request clarification if ambiguity remains.

## JDex notes

Name a JDex note with its ID. Its heading contains the ID and name.
`jd-note.sh` appends a dated entry to an existing note or creates the note.
Preserve existing history and formatting.

The current local convention is dated Markdown prose. Metadata and related-ID
links may be added when useful, but do not rewrite existing notes in bulk.

When documenting an item, record information that will help find or use it
later, including:

- where the associated data lives;
- important decisions and exceptions;
- related IDs or project folders;
- external URLs, account references, or physical locations.

## Local system boundaries

- The Knowledge Base is for durable context needed by future agents.
- The Wiki is for human-readable infrastructure documentation.
- Johnny.Decimal is for the user's artifacts and notes about those artifacts.

Do not put agent-memory observations into the JDex. Use the Knowledge Base
scripts for those observations.
