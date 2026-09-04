---
name: skill-creator
description: Creates, scaffolds, evaluates, and validates Agent Skills. Use when creating or updating a skill, packaging a reusable workflow, writing or reviewing a SKILL.md, or validating a skill against the specification.
compatibility: Requires bash. curl is required for update-references.
---

# Skill Creator

Create portable Agent Skills that conform to the agentskills.io specification.
Keep portable guidance in `SKILL.md`. Put client-specific behavior in the
client's supported extension file; do not leak it into the portable core.

`$SKILL_DIR` is the absolute directory containing this skill's `SKILL.md`.
Resolve it before running a bundled script. Run scripts from the directory
where the target skill is created or evaluated.

## Workflow

1. Capture the skill's capability, trigger conditions, and required scripts,
   references, or assets.
2. Identify the gap. Perform the task without a skill and record only context
   that the model could not reliably infer.
3. Scaffold a new skill when needed.
4. Write or update `SKILL.md` and the required supporting files.
5. Validate the skill.
6. Test it in a fresh session. Compare triggering and output quality with the
   skill disabled, then fix the observed gap.

For destructive or batch workflows, use plan-validate-execute: write the plan
to a file, validate it with a script, then execute it.

## Portable structure

```text
skill-name/
├── SKILL.md          # Required
├── scripts/          # Optional executable code
├── references/       # Optional on-demand documentation
├── assets/           # Optional templates, images, or data
└── agents/           # Optional client-specific metadata
```

### Frontmatter

| Field | Requirement |
| --- | --- |
| `name` | Required. 1–64 lowercase letters, digits, and hyphens. |
| `description` | Required. At most 1,024 characters; states what the skill does and when to use it. |
| `license` | Optional license name or bundled license file. |
| `compatibility` | Optional environment requirements; at most 500 characters. |
| `metadata` | Optional string key-value map. |
| `allowed-tools` | Optional experimental space-separated tool hints. Client support varies. |

The name must match the parent directory. It cannot start or end with a
hyphen, contain consecutive hyphens, or contain XML tags. Avoid `claude` and
`anthropic`, which are reserved by the Skills API. Prefer a gerund or noun
phrase, such as `processing-pdfs` or `pdf-processing`; avoid generic names
such as `helper`, `utils`, `tools`, and `data`.

### Description

The description is always in context and controls automatic triggering.

- Write in third person.
- State the main capability first, then concrete triggers such as file types,
  tools, and user phrases.
- Use phrases users would actually say.
- Do not use generic descriptions such as “Helps with documents.”

```yaml
description: Extracts text and tables from PDF files, fills forms, and merges
  documents. Use when working with PDF files or when the user mentions PDFs,
  forms, or document extraction.
```

Read `references/skill-creation-optimizing-descriptions.md` when a skill
triggers too broadly or misses expected prompts.

## Write concise instructions

Include only context the model needs to perform the task safely and
consistently. Do not explain basic language or library concepts.

| Task shape | Guidance to provide |
| --- | --- |
| Several valid approaches | Prose heuristics that let context decide. |
| Preferred pattern with variation | Pseudocode or a parameterized script. |
| Fragile, ordered, or high-stakes task | Exact command and an instruction not to modify it. |

For multi-step work, use ordered steps and a copyable checklist. Close any
quality-critical loop: run the validator, fix failures, and validate again.

Use one term for one concept. Avoid time-sensitive instructions; keep
superseded material under an **Old patterns** heading. Use forward slashes in
paths, fully qualify MCP tools as `ServerName:tool_name`, and prefer concrete
input/output examples when output format matters. Provide one default with an
escape hatch rather than several equal options.

### Progressive disclosure

Metadata is always loaded, the body loads when the skill activates, and
references load on demand. Keep `SKILL.md` below 500 lines and ideally below
5,000 tokens. Put detailed material in direct, one-level-deep references.
Give a reference over 100 lines a table of contents. State when to read each
reference. Do not bury required instructions behind several reference hops.

## Scripts

Scripts must be self-contained or document their dependencies. They must
support `--help`, accept non-interactive input through flags or stdin, and put
data on stdout and diagnostics on stderr. Prefer structured output such as
JSON or CSV. Make scripts idempotent when possible.

Handle known errors in the script rather than leaving the agent to guess. Name
and justify timeout values. State whether an agent should run a script or read
it as reference; running is usually preferable because only its output enters
context.

For Python scripts, use PEP 723 metadata and invoke them with `uv run`:

```python
# /// script
# requires-python = ">=3.11"
# dependencies = ["beautifulsoup4>=4.12", "requests>=2.31"]
# ///
```

```bash
uv run "$SKILL_DIR/scripts/myscript.py"
```

Scripts that serve both humans and agents should support `--porcelain`.

| Feature | Human mode | `--porcelain` |
| --- | --- | --- |
| Paths | Basenames | Full absolute paths |
| Output | Colored and decorated | Plain and structured |
| Interaction | Opens `$EDITOR` | Requires all arguments |
| Errors | Colored stderr | Plain stderr |

See `llm/skills/README.md` for the full porcelain pattern.

## Client extensions

Keep `SKILL.md` portable. Read the extension reference before adding a
client-specific feature.

### Codex CLI

Codex supports portable frontmatter and optional `agents/openai.yaml`. Use the
extension file only for Codex interface metadata, invocation policy, or MCP
tool dependencies; do not move core workflow guidance there. Claude Code
ignores `agents/openai.yaml`, so both clients can use the same skill. Most
skills do not need this file.

```yaml
# agents/openai.yaml
interface:
  display_name: "User-facing name"
  short_description: "User-facing description"
  brand_color: "#3B82F6"

policy:
  allow_implicit_invocation: false

dependencies:
  tools:
    - type: "mcp"
      value: "server-name"
      transport: "streamable_http"
      url: "https://example.com/mcp"
```

`policy.allow_implicit_invocation` defaults to `true`. Read
`references/codex-build-skills.md` for the complete Codex extension model. It
is the inverse of Claude’s `disable-model-invocation` setting.

### Claude Code

Claude Code supports these additional frontmatter fields:

| Field | Purpose |
| --- | --- |
| `when_to_use` | Additional trigger phrases. |
| `argument-hint` | Autocomplete hint. |
| `arguments` | Named positional arguments for substitutions. |
| `disable-model-invocation` | User-only invocation. |
| `user-invocable` | Hide a model-only skill from the user menu. |
| `disallowed-tools` | Remove tools while the skill is active. |
| `model` / `effort` | Override model or effort. |
| `context: fork` | Run the skill as a subagent prompt. |
| `agent` / `background` | Set subagent type or blocking behavior. |
| `hooks` | Attach lifecycle hooks. |
| `paths` | Limit automatic activation to path globs. |

Use default invocation for most skills. Use
`disable-model-invocation: true` for side effects such as deploy, commit, or
send. Use `user-invocable: false` for model-only background knowledge.

Claude expands `$ARGUMENTS` as typed; `$0`, `$1`, and later positional
arguments with shell-style quoting; named `$name` arguments; and the
`${CLAUDE_SKILL_DIR}`, `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_SESSION_ID}`, and
`${CLAUDE_EFFORT}` variables. Dynamic context uses `` !`command` `` or a
` ```! ` fenced command. It runs before the skill is read, and its output is
not rescanned for substitutions. Invoked skill content persists for the
session, so write standing instructions rather than one-time directions.

`${CLAUDE_SKILL_DIR}` and `${CLAUDE_PROJECT_DIR}` also expand in Claude
`allowed-tools` rules. Reuse the same path in the rule and the skill body so a
bundled script runs without an extra permission prompt.

Read `references/claude-code-skills.md` before using these features.

## Scaffold, validate, and evaluate

Create a skill directory:

```bash
bash "$SKILL_DIR/scripts/scaffold.sh" <name> \
  [--scripts] [--references] [--assets] [--codex] [--dir <path>]
```

The scaffold validates the name, refuses an existing directory, and creates
the skill in `--dir` or the current directory. It creates a `SKILL.md` stub
and optionally creates the requested directories and `agents/openai.yaml`.

Validate a skill:

```bash
bash "$SKILL_DIR/scripts/validate.sh" [--client <name>] <skill-directory>
```

Validation fails for missing or malformed required frontmatter, an invalid or
mismatched name, XML tags in name or description, overlong description or
compatibility fields, or a `SKILL.md` over 500 lines. It warns about reserved
names, first- or second-person descriptions, weak trigger wording,
unrecognized fields, unexpected top-level entries, and unsupported
client-specific frontmatter. Claude validation also checks its listing-length
convention; Codex validation checks optional `agents/openai.yaml` metadata. It
prints PASS, FAIL, or WARN for each check; exits 0 on pass and 1 on failure.

Evaluate two independent outcomes in fresh sessions:

1. **Triggering:** test prompts that should and should not activate the skill.
   Fix misses or false positives in the description and `when_to_use`.
2. **Output quality:** compare realistic prompts with and without the skill.

Write at least three test cases before adding extensive guidance. Test every
target model because their inference differs. See
`references/skill-creation-evaluating-skills.md` for the eval-file format.

## References and updates

Check `references/.last-updated` for freshness. Update vendored specification
and client documentation with:

```bash
bash "$SKILL_DIR/scripts/update-references.sh"
```

The update records the date and removes only vendored files listed in
`.vendored`; hand-written references remain unchanged. Run it periodically.

| Reference | Use when |
| --- | --- |
| `specification.md` | Checking the complete portable specification. |
| `skill-creation-best-practices.md` | Scoping or calibrating a skill. |
| `skill-creation-optimizing-descriptions.md` | Tuning activation. |
| `skill-creation-using-scripts.md` | Writing scripts. |
| `skill-creation-evaluating-skills.md` | Creating or running evaluations. |
| `skill-creation-quickstart.md` | Following a complete starter walkthrough. |
| `clients.md` | Checking supported skill clients. |
| `claude-code-skills.md` | Adding Claude Code extensions. |
| `anthropic-best-practices.md` | Applying detailed Anthropic authoring guidance. |
| `anthropic-overview.md` | Understanding Anthropic skill architecture. |
| `codex-build-skills.md` | Adding Codex extensions. |
