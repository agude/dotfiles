# Research behind the portable creator

Reviewed 2026-10-14. Sources are primary specification, implementation, and
product documentation, checked against the existing helpers and host behavior.

## Format requirements and recommendations

The [specification](https://agentskills.io/specification) requires a SKILL.md
entrypoint and defines metadata constraints. Resource directories are
conventions; additional files are allowed. The body has no prescribed section
schema. Size guidance belongs to progressive disclosure, not syntax validity.
The [reference validator implementation](https://github.com/agentskills/agentskills/blob/main/skills-ref/src/skills_ref/validator.py)
accepts Unicode lowercase alphanumerics in names; ASCII remains the safest
shared authoring choice. Its checks are useful format evidence, not proof of
runtime behavior. Both skills-ref (through strictyaml) and our helper reject
duplicate YAML keys. Our helper also rejects unfinished scaffold markers as a
local quality check.

The previous creator incorrectly presented vendor-reserved words, third-person
descriptions, XML restrictions, and a hard 500-line failure as shared rules.
The new creator does not impose those vendor conventions. It warns on size,
nonstandard fields, experimental tool hints, angle brackets in descriptions,
and names reserved by Claude API uploads without treating them as universal
errors. Non-string allowed-tools values also warn: the spec defines a string,
but Claude Code accepts lists and skills-ref does not validate that field's
type. It parses YAML instead of approximating it with line matching.

## Authoring and selection

[Best practices](https://agentskills.io/skill-creation/best-practices) emphasize
actual domain evidence, coherent scope, moderate detail, and refinement from
execution traces. The rewrite uses these principles without requiring a new
baseline run when sufficient evidence already exists.

[Description guidance](https://agentskills.io/skill-creation/optimizing-descriptions)
recommends clear applicability and testing against positive and near-miss
negative prompts. It recommends imperative phrasing; other guides favor third
person. Neither is a format rule. We prioritize a discriminating description
and measured selection over a universal grammatical preference. A trigger
suite needs discovery and load observability in its actual host; explicitly
loading a skill does not test automatic selection.

## Scripts and evaluation

[Script guidance](https://agentskills.io/skill-creation/using-scripts) supports
deterministic reusable helpers, explicit dependencies, noninteractive inputs,
help, actionable failures, and predictable outputs. Runtime and packaging
choices still belong to the target environment. PEP 723, uv, and porcelain
output are conventions of the dotfiles repository (`~/.dotfiles`) rather than
requirements of the shared format.

[Output evaluation guidance](https://agentskills.io/skill-creation/evaluating-skills)
recommends realistic cases, isolated comparisons, observable assertions,
artifact review, and iteration. Its JSON fixtures and workspace layout are
examples. The [Anthropic creator](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md)
adds practical baseline, grading, variance, and qualitative review patterns;
its orchestration tools are product-specific. [OpenAI's skill evaluation
article](https://developers.openai.com/blog/eval-skills) likewise separates
selection, outcomes, deterministic checks, rubric judgments, and efficiency.
The portable creator retains the comparison method without adopting either
vendor's runner, subagent machinery, or evaluation schema as a standard.

The practical evidence limit follows from these methods: record the host,
model, cases, comparison, and checks actually run. Do not turn a successful
metadata check or small sample into a claim of cross-host reliability.

## Host boundaries

Official host documentation is linked in [portability.md](portability.md).
Copilot, VS Code, Gemini CLI, Cursor, OpenCode, Goose, Pi, Claude Code, and
Codex share the entrypoint concept but differ in discovery, invocation, tool
names, extension metadata, and permission behavior. Our conclusion is to
resolve those details only when a target host makes them relevant, instead of
maintaining an option catalog inside the generic workflow. The verification
table below is the evidence for that conclusion and for the validator's
warnings; it is not authoring guidance.

Two policies follow from it. Claude Code and Goose substitute argument
placeholders, and Claude Code also executes embedded shell commands, so
ordinary Markdown is the portable default and host executable syntax does not
belong in generic examples. Claude Code's block-string parsing has broken
across versions without a documented fix for every form, so a single-line
description remains the conservative interoperability choice.

## Host verification (2026-10-14)

Versions: Claude Code 2.1.300 (documentation and changelog); Codex
`openai/codex` main at `bb64b894`; Goose `aaif-goose/goose` main (v1.54.0);
skills-ref `agentskills/agentskills` main. Host behavior changes between
releases; re-verify a row before changing policy because of it.

| Aspect | Claude Code | Codex | Goose | skills-ref |
| --- | --- | --- | --- | --- |
| Project skill directories | `.claude/skills/` in the project, its parents, and nested directories | `.agents/skills/` from the project root to the working directory; undocumented `.codex/skills/` | `.agents/skills/`, `.goose/skills/`, `.claude/skills/` in the working directory only | n/a |
| User skill directories | `~/.claude/skills/`; no `.agents/skills/` | `~/.agents/skills/`; deprecated `$CODEX_HOME/skills/`; `/etc/codex/skills/` | `~/.agents/skills/`, Goose config `skills/`, `~/.claude/skills/`, `~/.config/agents/skills/` | n/a |
| Symlinks | Symlinked skill directories followed | Followed except in system scope; scan depth 6; hidden subdirectories skipped | Skill directories followed; files inside a skill opened with `O_NOFOLLOW` | n/a |
| Duplicate names | Not checked | Both listed; no shadowing | First found wins; project before user | n/a |
| `name` | Rejects `<`, `>`, control, and zero-width characters; `anthropic-skills` reserved | At most 64 characters; no pattern or directory check; missing name falls back to the directory name | Not checked at discovery; missing name skips the skill | NFKC-normalized Unicode lowercase alphanumerics and hyphens; at most 64; must match the directory |
| `description` | Listing caps `description` plus `when_to_use` at 1,536 characters | Nonempty; catalog truncates at 1,024 | Defaults to empty | Nonempty; at most 1,024 |
| Block-string description | Bugs with `\|` and `>-` (#10589, #12971, #14064) closed without a fix version; `>-` works in 2.1.274; `\|` untested | Whitespace collapsed to one line | Parsed by serde_yaml | Parsed by strictyaml |
| Malformed YAML | Skill loads with empty metadata (2.1.186) | Quoting repair attempted; otherwise not loaded | Skill skipped with a warning | Error |
| Unknown fields | Ignored silently | Ignored | Ignored | Error |
| `metadata` | Accepted; not used | Reads `short-description` | Reads `arguments` and `argument-hint` | No type check; values coerced to strings |
| `allowed-tools` | Space- or comma-separated string, or YAML list; pre-approves, does not restrict | Ignored | Ignored | Allowed; no type check |
| Body substitution | `$ARGUMENTS`, `$ARGUMENTS[N]`, `$N`, declared `$name`, `${CLAUDE_*}` variables; shell through `` !`cmd` `` and `` ```! `` fences | None | `$ARGUMENTS`, `$ARGUMENTS[N]`, `$N`, `$name` from `metadata.arguments`, only when arguments are passed; no shell | n/a |
| Skill directory given to the model | Undocumented "Base directory for this skill" header; `${CLAUDE_SKILL_DIR}` substitution | Catalog lists each `SKILL.md` path; explicit use injects `<path>` | Absolute "Skill directory" line only when the skill has supporting files | n/a |
| Disable implicit selection | `disable-model-invocation: true` | `policy.allow_implicit_invocation: false` in `agents/openai.yaml` | None found | n/a |

Other hosts were checked for discovery only. Copilot, VS Code, Cursor,
OpenCode, and Pi document `.agents/skills/`; Gemini CLI documents it as an
alias of `.gemini/skills/`. Pi warns on most invalid fields and does not
compare `name` with the directory. OpenCode interprets the `opencode/slash` and
`opencode/autoinvoke` metadata keys.

Upload and authoring validators add restrictions outside the specification.
Claude API uploads reject `claude` and `anthropic` in names and XML tags in
names and descriptions. Codex's bundled `quick_validate.py` rejects `<` and `>`
in descriptions. These are the basis for the validator's compatibility
warnings.

Sources:

- Claude Code: [skills documentation](https://code.claude.com/docs/en/skills),
  [changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md),
  and `anthropics/claude-code` issues #10589, #12971, #14064, #16345, #31005,
  #80469, and #94301.
- Claude API: [Agent Skills overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview).
- Codex: [Build skills](https://learn.chatgpt.com/docs/build-skills), and the
  loader in [`codex-rs/skills/src`](https://github.com/openai/codex/tree/main/codex-rs/skills/src)
  and [`codex-rs/ext/skills/src`](https://github.com/openai/codex/tree/main/codex-rs/ext/skills/src).
- Goose: [Using skills](https://goose-docs.ai/docs/guides/context-engineering/using-skills),
  and the loader in [`crates/goose/src/skills`](https://github.com/aaif-goose/goose/tree/main/crates/goose/src/skills).
- skills-ref: [`validator.py`](https://github.com/agentskills/agentskills/blob/main/skills-ref/src/skills_ref/validator.py)
  and [`parser.py`](https://github.com/agentskills/agentskills/blob/main/skills-ref/src/skills_ref/parser.py).
- Other hosts: the documentation links in [portability.md](portability.md).

## Snapshot maintenance

The updater previously discovered pages from a sitemap, fetched vendor manuals,
and could remove old snapshots after partial failures. It now refreshes a small
explicit set of agentskills.io authoring pages. It stages all responses,
rejects empty/HTML responses, and preserves the old set on fetch failure.
Source URLs, ownership, and UTC fetch time are recorded in `sources.tsv`,
`vendored.txt`, and `last-updated.txt`; hand-written notes remain outside that set.
A successful fetch dates the snapshot, not an independent verification of every
claim. Review documentation changes before changing the creator's policy.
Snapshots remain verbatim upstream text: local edits would disappear on the
next refresh. Host-specific CLI and subagent examples in those pages are
examples to adapt, not requirements of the portable creator.
