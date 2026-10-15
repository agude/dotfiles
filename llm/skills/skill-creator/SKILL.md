---
name: skill-creator
description: Create, revise, review, and evaluate Agent Skills. Use when turning a reusable workflow into a skill, editing SKILL.md or its bundled resources, checking specification compliance, or improving skill selection and task results.
compatibility: Bundled helpers require Bash; validation requires uv and Python 3.11+ (PyYAML is resolved by uv); reference updates require curl and network access.
---

# Skill Creator

Write Agent Skills that carry useful expertise between agents and projects.
Use the [Agent Skills specification](https://agentskills.io/specification) for
the shared format. Keep host extensions separate from the reusable workflow.

## Establish the task

For a new skill, identify the recurring task, expected inputs and outputs,
activation conditions, and expertise the agent lacks. Use real tasks,
corrections, project artifacts, and known failure cases as evidence. Run a
representative task without the skill when that would expose a useful gap;
do not repeat work whose evidence is already available.

For an update, inspect the existing skill, its resources, callers, and tests.
Preserve useful domain rules and user choices. Fix the demonstrated problem
without accumulating universal rules for every past example.

Use the requested destination. In the dotfiles repository (`~/.dotfiles`),
shared skills belong in `llm/skills/`. Elsewhere, check project instructions
and the intended host's discovery rules. Do not assume one product's
installation path is universal.
Read [portability.md](references/portability.md) when installation, invocation,
tools, permissions, or host extensions affect the task.

## Define the skill boundary

Choose one coherent capability. Querying business data and presenting results
can be coherent; adding database administration usually needs a separate
skill. Include only instructions that change decisions or improve results
beyond what the agent already knows.

Write the description for selection: state the capability, the user's intent,
and concrete contexts where it applies. Add an exclusion when it prevents a
likely collision with another skill. Avoid generic names and keyword lists
that attract unrelated work. Put trigger information in the description;
the body may not be visible until after selection.

```yaml
name: invoice-reconciliation
description: Reconcile supplier invoices against purchase orders and flag mismatched quantities, prices, and missing orders. Use when checking invoice batches against purchasing records.
```

There is no required grammatical style for descriptions. Choose wording that
makes the boundary clear, then test it. Read
[optimizing descriptions](references/skill-creation-optimizing-descriptions.md)
when selection misses relevant tasks or loads the skill for near misses.

## Write the portable core

A skill needs a directory with `SKILL.md`: YAML frontmatter followed by
Markdown instructions. Add resources only when they have a concrete use.

```text
skill-name/
├── SKILL.md
├── scripts/       # Optional deterministic helpers
├── references/    # Optional documentation read when needed
└── assets/        # Optional templates or files used in output
```

| Field | Shared format |
| --- | --- |
| `name` | Required, 1–64 lowercase alphanumeric characters or hyphens; match the directory; no leading, trailing, or consecutive hyphens. Prefer ASCII for interoperability. |
| `description` | Required, nonempty string, at most 1,024 characters. |
| `license` | Optional string identifying a license or bundled license file. |
| `compatibility` | Optional nonempty string, at most 500 characters, for actual environment requirements. |
| `metadata` | Optional map of string keys to string values. Quote versions and values YAML might interpret as numbers or booleans. |
| `allowed-tools` | Optional experimental string; tool names and enforcement depend on the host. Omit by default for portable skills. |

Use valid YAML, including quoting scalars containing YAML punctuation when
needed. Folded and literal block strings are valid YAML, but a single-line
description is the safest choice across hosts because block-string parsing
has varied between implementations and versions. Consult the
[specification](references/specification.md) for exact format rules.

In the body, state the outcome, essential context, decision points, procedure,
and how to check the result. Explain non-obvious constraints. Use exact steps
for fragile operations; give judgment and defaults where several approaches
work. Include input/output examples when they resolve ambiguity.

Keep the user's scope and authorization intact. Describe side effects where
they occur and preserve required approval boundaries. A skill's presence or
invocation does not authorize unrelated actions. For fragile batch operations,
a saved plan, deterministic validation, and execution can prevent partial or
incorrect changes; use that pattern when the task needs it.

Keep `SKILL.md` short enough to use directly. Under 500 lines and roughly
5,000 tokens are authoring recommendations, not hard format limits. Move
conditional detail into focused references, link them from the entrypoint,
and say when each should be read. Keep essential constraints in the body.
Use relative resource paths from the skill root and avoid long reference
chains. Additional directories are permitted by the format. For deeper
instruction design, read [best practices](references/skill-creation-best-practices.md).

## Bundle resources deliberately

Use a script when repeated or complex mechanics benefit from deterministic
execution. Prefer an existing tool or a short command for simple work.
Document prerequisites, inputs, outputs, side effects, failure behavior, and
whether the agent should run the script or inspect it.

In runnable examples, resolve bundled scripts from the loaded skill's absolute
directory. Keep the working directory in the target project; a bare
`scripts/helper.py` path would incorrectly look for the helper in that project.

Agent-facing helpers should accept flags or stdin without interactive prompts,
offer concise help, use meaningful exit codes, and send diagnostics to stderr.
Use structured stdout when another program consumes it. Add dry-run or
idempotent behavior when repeated execution could cause damage. Test actual
behavior, including relevant failures. Read
[using scripts](references/skill-creation-using-scripts.md) when adding helpers.

Follow the destination project's tooling conventions. In the dotfiles
repository (`~/.dotfiles`), standalone Python helpers use PEP 723 dependency
metadata and `uv run`.
Helpers shared with humans use the repository's `--porcelain` pattern when
human output would otherwise add interaction, color, or ambiguous paths.
These are local conventions, not Agent Skills requirements.

Put domain documentation in `references/` and output templates or other
deliverable material in `assets/`. Keep every required resource available
with the skill. Do not depend on an undocumented local file, another skill,
or a tool unique to one host without declaring that requirement.

## Scaffold and validate

In the commands below, set `SKILL_DIR` to the absolute directory containing
this creator's `SKILL.md`. It is a local command variable, not a standard
variable supplied by skill hosts. Keep the working directory in the target
project and use the resolved creator path for its helpers.

```bash
bash "$SKILL_DIR/scripts/scaffold.sh" <name> \
  [--scripts] [--references] [--assets] [--dir <parent-directory>]
bash "$SKILL_DIR/scripts/validate.sh" <skill-directory>
```

Scaffolding refuses existing paths and emits only portable metadata. Replace
its TODOs before use. Validation parses YAML, checks shared fields and naming,
and reports unfinished scaffold markers. It warns about size recommendations,
nonstandard fields, host-specific tool-hint types, angle brackets in
descriptions, and names reserved by Claude API uploads. It does not validate
host extensions, installation,
links, script behavior, or output quality. Inspect those separately. The
upstream `skills-ref validate <skill-directory>` is an additional format check
when available; this helper is not a replacement for host testing.

## Evaluate and revise

Test two separate questions:

1. **Selection:** In a clean session with the skill discoverable, does a
   realistic prompt cause the host to load it? Include relevant requests and
   similar requests that should use something else. Explicit invocation tests
   access, not automatic selection. Check traces or host logs rather than
   trusting the agent's claim that it used the skill.
2. **Task results:** Does the loaded skill improve the work? Start with a few
   representative cases, including a meaningful boundary or failure case.
   Compare with no skill for a new skill, or the previous version for an
   update, using equivalent fresh contexts and inputs.

Define observable success criteria. Check mechanical properties with code;
review judgment and presentation with a clear human or model rubric. Inspect
traces for wasted steps and missed instructions. Keep inputs, outputs,
settings, and results so failures can be reproduced. Keep evaluation artifacts
outside the distributable skill unless they are reusable fixtures.

Repeat variable cases when confidence matters. Hold back some prompts when
tuning descriptions so improvements generalize. Scale evaluation to the
change; a small edit need not trigger a costly benchmark. Do not prescribe a
particular model, subagent system, CLI, or evaluation file schema as universal.
Read [evaluating skills](references/skill-creation-evaluating-skills.md) for
the comparison protocol and optional fixture examples.

Revise from observed failures, then repeat affected checks. Report the exact
checks run and their limits. Structural validation proves format properties;
a small behavioral sample does not prove reliability across hosts or models.
If runtime testing is unavailable, say so and provide concrete test cases.

## Maintain the references

[Research notes](references/research.md) record sources, findings, and the
reasoning behind this portable workflow. Use them when reviewing or updating
the creator itself. The bundled upstream pages are snapshots; check current
official documentation before relying on changing host behavior.

```bash
bash "$SKILL_DIR/scripts/update-references.sh"
```

The updater fetches an explicit set of Agent Skills pages and records source
URLs and fetch time. A failed or empty download leaves existing snapshots
unchanged. It never refreshes hand-written references. It does not certify
that downloaded advice is portable; review changed content before adopting it.
