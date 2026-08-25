# Local JDex Policy

Use this file for the user's index, local filing decisions, and notes about
Johnny.Decimal items.

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

## Local configuration

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

1. **Person first.** If a record belongs to one person, file it in that
   person's area.
2. **Purpose over provider.** File a bill by its purpose, not by the company
   that sent it.
3. **Notes versus documents.** Notes about an ID belong in the JDex. Actual
   documents belong in the ID's filesystem folder.
4. **One source of truth.** Do not create competing copies merely to make an
   item visible from multiple places. Use a JDex note or link instead.
5. **When uncertain, stop before moving.** Inspect the flowchart and target
   directory; ask for clarification if the location remains ambiguous.

## JDex notes

JDex notes use the ID as the filename and a heading containing the ID and
name. `jd-note.sh` appends a dated entry to the existing note or creates it
when needed. Preserve existing note history and formatting.

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
