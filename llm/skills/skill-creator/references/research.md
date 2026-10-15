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
output are this repository's conventions rather than requirements of the
shared format.

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
Copilot, VS Code, Gemini, Cursor, OpenCode, Goose, Pi, Claude Code, and Codex share the
entrypoint concept but differ in discovery, invocation, tool names, extension
metadata, and permission behavior. Our conclusion is to resolve those details
only when a target host makes them relevant, instead of maintaining an option
catalog inside the generic workflow.

[Claude Code's documentation](https://code.claude.com/docs/en/skills) describes
argument substitution and command execution before model consumption.
[Goose's implementation](https://github.com/aaif-goose/goose/tree/main/crates/goose/src/skills)
also substitutes arguments, but does not execute embedded shell commands.
Ordinary Markdown is the portable default; host executable syntax does not
belong in generic examples. Goose's load_skill additionally opens supporting
files with O_NOFOLLOW, which prevents reading symlinks inside the skill.

Block strings are valid YAML and work in several hosts, but Claude Code has
had repeated parser bugs without a documented fix version for every form.
A single-line description remains the conservative interoperability choice.

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
