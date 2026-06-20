---
name: summarize-book
description: >-
  Summarize an ebook (EPUB/AZW3/MOBI) chapter by chapter for book club prep
  or personal reference. Handles extraction, chunking, parallel summarization
  via sub-agents, and filing the result into Johnny Decimal. Use when the user
  wants to summarize a book, prep for book club, or create chapter notes from
  an ebook file.
compatibility: >-
  Requires uv and Python 3.11+. AZW3/MOBI conversion requires calibre
  (ebook-convert). EPUB extraction uses Python only (no extra deps).
allowed-tools: "Bash(${CLAUDE_SKILL_DIR}/scripts/:*) Read Write Agent"
---

# Summarize Book

## Quick Start

```bash
# 1. Extract ebook to chapter markdown files
uv run ${CLAUDE_SKILL_DIR}/scripts/extract_ebook.py book.epub -d chapters/

# 2. Summarize (the agent orchestrates this — see Workflow below)
```

## Workflow

### Step 1: Extract

Run the extraction script on the ebook file:

```bash
uv run ${CLAUDE_SKILL_DIR}/scripts/extract_ebook.py book.epub -d chapters/
```

This produces one markdown file per chapter in the output directory, named
`01-chapter-title.md`, `02-chapter-title.md`, etc. A `metadata.json` file is
also written with title, author, and chapter list.

Supported formats:
- **EPUB** — extracted directly (unzip + HTML-to-markdown)
- **AZW3/MOBI** — converted to EPUB first via `ebook-convert`, then extracted

### Step 2: Review chapter list

Read `metadata.json` and list the chapters for the user. Confirm the
extraction looks correct (right number of chapters, no garbled text). If
chapters are mis-split or combined, the user may want to manually adjust
before proceeding.

### Step 3: Summarize chapter by chapter

For each chapter file, produce a summary. Two approaches depending on book
length:

**Short books (under ~15 chapters):** Summarize sequentially. Read each
chapter file and write a summary.

**Long books (15+ chapters):** Fan out to parallel sub-agents, one per
chapter (or one per batch of 2-3 short chapters). Each agent:

1. Reads the chapter markdown
2. Writes a summary covering: key plot events, character introductions/deaths,
   important reveals, unresolved threads
3. Returns the summary text

Prompt template for sub-agents:

```
Read the chapter file at {path} and write a detailed summary. Include:
- Key plot events in chronological order
- Character introductions, deaths, or status changes (note alive/deceased)
- Important world-building reveals
- Unresolved plot threads set up in this chapter

Write factually from the source text. Do not embellish or infer events that
are not on the page. Write in present tense. Keep to 200-400 words depending
on chapter density. Output only the summary text, no headers or metadata.
```

### Step 4: Verify against source

This is critical. LLM summaries frequently get plot specifics wrong —
character names, who did what, cause of death, sequence of events. After
drafting each summary:

- Compare against the actual chapter text
- Fix any fabricated or transposed details
- Confirm character status (alive/deceased) matches the text

### Step 5: Assemble the output

Combine all chapter summaries into a single markdown file. Use the format
from existing summaries in the media notes folder:

```markdown
# {Title} - Summary

**Author:** {Author}
**Structure:** {N} chapters

---

## Chapter-by-Chapter Summary

### Chapter 1: {Title}
{summary}

### Chapter 2: {Title}
{summary}

...

---

### Character List & Status

{For fiction: list major characters with (Alive)/(Deceased) and a one-line
description of their role}

---

### Unresolved Plots

{Bullet list of threads left open at the end}
```

Not every book needs all sections. Non-fiction books skip the character list
and unresolved plots. Series books should emphasize unresolved threads since
those are the main value for book club prep.

### Step 6: File the result

File the summary into Johnny Decimal:

```
~/Documents/60-69 Hobbies and Recreation/63 Creative Works/63.14 Media Notes and Reviews/
```

Naming convention: `{title_slug}_summary.md` (lowercase, underscores). For
series with multiple books, create a subdirectory named after the series and
use `{series_slug}_{NN}-{title_slug}-summary.md`.

Examples from existing files:
- `antimemetics_division_summary.md`
- `war_horses/war_horses_01-chevalier-summary.md`

## Guidelines

- Always extract from the source file. Never summarize from memory.
- Present tense for summaries.
- Include character status (Alive/Deceased) for fiction — this is the main
  reference value for series.
- Verify every proper noun, death, and plot point against the source chapter.
- For book club prep, emphasize discussion-worthy themes and ambiguities.
- Do not editorialize or review. Summarize what happens, not whether it's good.
