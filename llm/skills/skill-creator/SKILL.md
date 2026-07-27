---
name: skill-creator
description: >
  Create, scaffold, evaluate, and validate Agent Skills. Use this skill when
  the user wants to create a skill, package knowledge or a workflow into a
  reusable skill, scaffold a skill directory, write or review a SKILL.md, or
  validate an existing skill against the spec.
compatibility: Requires bash. curl needed for update-references.
allowed-tools: "Bash(bash ${CLAUDE_SKILL_DIR}/scripts/:*) Read Write Edit"
---

# Skill Creator

**Skill base directory:** `${CLAUDE_SKILL_DIR}`

Create Agent Skills that conform to the agentskills.io specification and to
Anthropic's authoring guidance.

## Workflow

1. **Capture intent** — what the skill should do, when it should trigger, and
   whether it needs scripts, references, or assets.
2. **Identify the gap** — run the task without a skill first. What context did
   you have to supply by hand? That, and only that, belongs in the skill.
3. **Scaffold** — run `scaffold.sh` to create the directory structure.
4. **Write SKILL.md** — frontmatter plus instructions.
5. **Validate** — run `validate.sh`.
6. **Test in a fresh session** — leftover context from authoring masks gaps in
   the written instructions. Iterate on what the fresh session gets wrong.

## Spec quick reference

### Directory structure

```
skill-name/
├── SKILL.md          # Required
├── scripts/          # Optional: executable code
├── references/       # Optional: documentation loaded on demand
└── assets/           # Optional: templates, images, data files
```

### Frontmatter (portable fields)

These work in every Agent Skills client.

| Field | Required | Constraints |
|---|---|---|
| `name` | Yes | 1–64 chars, lowercase alphanumeric and hyphens |
| `description` | Yes | 1–1024 chars. What it does **and** when to use it |
| `license` | No | License name or bundled license file |
| `compatibility` | No | ≤500 chars. Environment requirements. Most skills omit it |
| `metadata` | No | Arbitrary string key-value map |
| `allowed-tools` | No | Space-separated pre-approved tools (experimental) |

### Naming rules

- Lowercase letters, numbers, and hyphens only (`a-z`, `0-9`, `-`)
- 1–64 characters, no leading/trailing hyphen, no consecutive hyphens (`--`)
- Must match the parent directory name
- No XML tags
- Avoid `claude` and `anthropic`: the Skills API rejects them as reserved
  words. Claude Code does not enforce this, but portable skills should comply
- Prefer gerunds (`processing-pdfs`) or noun phrases (`pdf-processing`).
  Avoid `helper`, `utils`, `tools`, `data`

### Writing the description

The description is the only part of a skill that is always in context, and it
is what the agent matches a request against. Get it right before anything else.

- **Third person.** "Extracts text from PDFs", not "I can help you with PDFs"
  or "You can use this to…". It is injected into the system prompt, and a
  mixed point of view degrades matching.
- **What plus when.** Name the capability, then the triggers: file types,
  tool names, and the phrases a user would actually type.
- **Key use case first.** Claude Code truncates the combined
  `description` + `when_to_use` text at 1,536 characters in the skill listing,
  and shortens it further when many skills are installed.
- **Be specific.** "Helps with documents" matches nothing reliably.

Good:

```yaml
description: Extracts text and tables from PDF files, fills forms, and merges
  documents. Use when working with PDF files or when the user mentions PDFs,
  forms, or document extraction.
```

See `references/skill-creation-optimizing-descriptions.md` when a skill
triggers too often or not often enough.

## Claude Code extensions

Claude Code implements the spec above and adds the fields below. Use them only
when targeting Claude Code; other clients ignore them. Full details in
`references/claude-code-skills.md`.

| Field | Purpose |
|---|---|
| `when_to_use` | Extra trigger phrases, appended to `description` in the listing |
| `argument-hint` | Autocomplete hint, e.g. `[issue-number]` |
| `arguments` | Named positional arguments for `$name` substitution |
| `disable-model-invocation` | `true` = only the user can invoke it, via `/name` |
| `user-invocable` | `false` = only the model can invoke it; hidden from `/` menu |
| `disallowed-tools` | Tools removed from the pool while the skill is active |
| `model` / `effort` | Override model or effort level for the turn |
| `context: fork` | Run the skill as a subagent prompt |
| `agent` / `background` | Subagent type; whether the fork blocks the turn |
| `hooks` | Hooks scoped to this skill's lifecycle |
| `paths` | Globs limiting automatic activation to matching files |

### Invocation control

Pick deliberately — this is the most common design decision:

| Frontmatter | User invokes | Model invokes | Use for |
|---|---|---|---|
| (default) | Yes | Yes | Most skills |
| `disable-model-invocation: true` | Yes | No | Side effects: deploy, commit, send |
| `user-invocable: false` | No | Yes | Background knowledge, not an action |

### String substitutions

| Variable | Expands to |
|---|---|
| `$ARGUMENTS` | All arguments as typed |
| `$0`, `$1`, … | Positional arguments (shell-style quoting) |
| `$name` | Named argument declared in `arguments` |
| `${CLAUDE_SKILL_DIR}` | Directory containing this `SKILL.md` |
| `${CLAUDE_PROJECT_DIR}` | Project root |
| `${CLAUDE_SESSION_ID}` | Current session ID |
| `${CLAUDE_EFFORT}` | Current effort level |

`${CLAUDE_SKILL_DIR}` and `${CLAUDE_PROJECT_DIR}` expand in both the body and
in `Bash(...)` rules in `allowed-tools`. Use the same path in both so a
bundled script runs without a permission prompt:

```yaml
allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/render.sh *)
```

### Dynamic context injection

`` !`command` `` runs before the agent sees the content and is replaced by the
command's output. Use it to pull live data into the prompt:

```markdown
- PR diff: !`gh pr diff`
```

Use a ` ```! ` fenced block for multi-line commands. This is preprocessing, not
something the agent executes, and output is not rescanned for placeholders.

### Content lifecycle

Invoked skill content enters the conversation once and stays for the session;
Claude Code does not re-read the file on later turns. Write guidance that must
hold throughout a task as standing instructions, not one-time steps. Every line
is a recurring token cost.

## Authoring principles

### Be concise

The model is already capable. Only add context it does not have. Challenge each
paragraph: does this justify its token cost? Do not explain what PDFs are, what
a library is, or how the language works.

### Match freedom to fragility

| Task shape | Give |
|---|---|
| Many valid approaches, context decides | Prose heuristics |
| A preferred pattern with variation | Pseudocode or a parameterised script |
| Fragile, order-dependent, high-stakes | An exact command and "do not modify it" |

### Progressive disclosure

Metadata is always loaded; the body loads on activation; everything else loads
on demand. So:

- Keep SKILL.md under 500 lines (validated) and ideally under 5k tokens
- Move detail into `references/`, and say when to read each file
- Keep references **one level deep** from SKILL.md. Nested reference chains get
  partially read
- Give reference files over 100 lines a table of contents at the top
- Bundled files cost nothing until read, so bundling comprehensive material is
  fine — burying it behind three hops is not

### Workflows and feedback loops

For multi-step procedures, give numbered steps and a copyable checklist. For
anything quality-critical, close the loop: run a validator, fix the errors,
repeat, and only then proceed. The "validator" can be a script or a checklist
in a reference file.

For batch or destructive operations, use plan-validate-execute: write the plan
to a file, validate the file with a script, then execute it.

### Content rules

- No time-sensitive statements ("before August, use…"). Put superseded material
  under an "Old patterns" heading instead
- One term per concept throughout — not "field", "box", and "element"
- Offer one default with an escape hatch, not five options
- Forward slashes in all paths, even for Windows
- Fully qualify MCP tools as `ServerName:tool_name`
- Concrete examples over abstract description; input/output pairs when the
  output format matters

## Scripts

- Self-contained, or dependencies documented explicitly. Do not assume a
  package is installed
- Support `--help` so the interface is discoverable
- Structured output (JSON, CSV) over prose; data to stdout, diagnostics to
  stderr
- No interactive prompts — all input via flags or stdin
- Idempotent where possible
- **Solve, do not defer.** Handle the error in the script instead of failing
  and leaving the agent to guess
- No voodoo constants. If you cannot justify a timeout value, the agent cannot
  either — name it and comment why
- Say whether the agent should **run** the script or **read** it as reference.
  Running is usually right: the code never enters context, only the output

### PEP 723 Python scripts (recommended pattern)

Inline metadata lets `uv run` handle dependencies with no manual install:

```python
# /// script
# requires-python = ">=3.11"
# dependencies = ["beautifulsoup4>=4.12", "requests>=2.31"]
# ///
```

Invoke with `uv run ${CLAUDE_SKILL_DIR}/scripts/myscript.py`.

### Human vs agent mode (`--porcelain`)

Scripts that serve both humans and agents should support a `--porcelain` flag.
See `llm/skills/README.md` for the full pattern. Summary:

| Feature | Human mode | `--porcelain` |
|---------|-----------|---------------|
| Paths | Basenames | Full absolute paths |
| Output | Colored, decorated | Plain, structured |
| Interactive | Opens `$EDITOR` | Requires all args |
| Errors | Colored to stderr | Plain to stderr |

## Available scripts

Scripts are in `${CLAUDE_SKILL_DIR}/scripts/`. Use the full path when invoking.

| Script | Purpose |
|--------|---------|
| `scaffold.sh` | Create a new skill directory with SKILL.md stub |
| `validate.sh` | Validate a skill directory against the spec |
| `update-references.sh` | Refetch the vendored spec and Anthropic docs |

### scaffold.sh

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/scaffold.sh <name> [--scripts] [--references] [--assets] [--dir <path>]
```

Creates a skill directory (in `--dir`, or the current working directory) with:
- A `SKILL.md` containing valid frontmatter and a body placeholder
- A `**Skill base directory:** \`${CLAUDE_SKILL_DIR}\`` line in the stub (only
  when `--scripts` is passed)
- Optional `scripts/`, `references/`, `assets/` subdirectories

The name is validated against the naming rules first. Exits non-zero if the
name is invalid or the directory already exists.

### validate.sh

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/validate.sh <skill-directory>
```

Fails on: missing SKILL.md; missing `name` or `description`; `name` not
matching the directory; malformed `name`; XML tags in `name` or `description`;
`description` over 1024 chars; `compatibility` over 500 chars; SKILL.md over
500 lines.

Warns on: reserved words in `name`; first- or second-person `description`;
a `description` with no "when to use" signal; `description` plus `when_to_use`
over the 1,536-char listing cap; unrecognized frontmatter keys; unexpected
top-level entries; a `scripts/` directory with no `${CLAUDE_SKILL_DIR}` line.

Prints PASS/FAIL/WARN per check. Exits 0 if all checks pass, 1 if any fail.

### update-references.sh

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/update-references.sh
```

Refetches the agentskills.io spec pages and Anthropic's skill docs into
`${CLAUDE_SKILL_DIR}/references/`, and records the date in `.last-updated`.
Only files it vendored (tracked in `.vendored`) are pruned; hand-written
reference files are left alone. Run it periodically.

## Evaluating a skill

A skill that triggers is not necessarily a skill that works. Measure the two
separately, both against a baseline with the skill disabled:

1. **Triggering** — collect prompts that should and should not activate it, and
   check the hit rate. Fix by editing `description` and `when_to_use`.
2. **Output quality** — run realistic prompts in fresh sessions with and
   without the skill, and compare against written expectations.

Write at least three test cases before writing extensive instructions, so the
skill addresses real gaps rather than imagined ones. Test with every model you
intend to use: what Opus infers, Haiku may need spelled out.

See `references/skill-creation-evaluating-skills.md` for the eval file format
and the full iteration loop.

## References

Read these with the Read tool as needed. Check
`${CLAUDE_SKILL_DIR}/references/.last-updated` for freshness and run
`update-references.sh` to refresh.

Portable specification (agentskills.io):

- `references/specification.md` — complete format specification
- `references/skill-creation-best-practices.md` — scoping and calibration
- `references/skill-creation-optimizing-descriptions.md` — description tuning
- `references/skill-creation-using-scripts.md` — script authoring guide
- `references/skill-creation-evaluating-skills.md` — testing and eval guide
- `references/skill-creation-quickstart.md` — quick start walkthrough
- `references/clients.md` — agents that support the format

Anthropic-specific:

- `references/claude-code-skills.md` — Claude Code frontmatter, substitutions,
  subagent execution, settings, and troubleshooting
- `references/anthropic-best-practices.md` — authoring guidance in depth
- `references/anthropic-overview.md` — architecture, surfaces, and constraints
