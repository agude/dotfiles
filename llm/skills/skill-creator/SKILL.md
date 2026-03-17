---
name: skill-creator
description: >
  Create, scaffold, and validate new Agent Skills. Use this skill when the
  user wants to create a skill, package knowledge or a workflow into a
  reusable skill, scaffold a skill directory, write a SKILL.md, or validate
  an existing skill against the spec.
compatibility: Requires bash. curl needed for update-references.
allowed-tools: "Bash(bash {baseDir}/scripts/:*) Read Write Edit"
---

# Skill Creator

**Skill base directory:** `{baseDir}`

Create new Agent Skills that conform to the agentskills.io specification.

## Workflow

1. **Capture intent** — understand what the skill should do, when it should
   trigger, and whether it needs scripts, references, or assets.
2. **Scaffold** — run the scaffold script to create the directory structure.
3. **Write SKILL.md** — fill in the frontmatter and body with instructions.
4. **Validate** — run the validate script to check the result.
5. **Iterate** — fix any validation failures and refine the instructions.

## Quick Reference: Agent Skills Spec

### Directory structure

```
skill-name/
├── SKILL.md          # Required
├── scripts/          # Optional: executable code
├── references/       # Optional: documentation loaded on demand
└── assets/           # Optional: templates, images, data files
```

### SKILL.md format

```yaml
---
name: skill-name           # Required. 1-64 chars, lowercase + hyphens.
description: ...           # Required. 1-1024 chars. What it does + when to use.
license: ...               # Optional.
compatibility: ...         # Optional. Environment requirements.
metadata:                  # Optional. Arbitrary key-value pairs.
  author: example-org
allowed-tools: "Bash(command:*) Read"  # Optional. Pre-approved tools.
---

# Skill Name

Markdown instructions follow the frontmatter.
```

### Naming rules

- Lowercase letters, numbers, and hyphens only (`a-z`, `0-9`, `-`)
- 1–64 characters
- Must not start or end with a hyphen
- Must not contain consecutive hyphens (`--`)
- Must match the parent directory name

### Key constraints

- **SKILL.md body:** keep under 500 lines. Move detailed content to
  `references/` files.
- **Progressive disclosure:** metadata (~100 tokens) is always loaded;
  SKILL.md body loads on activation; scripts/references/assets load on demand.
- **Description field:** describe both what the skill does AND when to use it.
  Include keywords that help agents identify relevant tasks.
- **File references:** use relative paths from the skill root
  (e.g., `scripts/validate.sh`, `references/guide.md`).

### Writing good instructions

- Use imperative form ("Run the script", not "You should run the script").
- Explain the *why* behind instructions, not just the *what*.
- Include step-by-step workflows, input/output examples, and edge cases.
- For skills with scripts, document each script's purpose, usage, and flags.
- Reference files in `references/` with guidance on when to read them.

### Scripts

- Scripts must be self-contained or clearly document dependencies.
- Include `--help` output so agents can discover the interface.
- Use structured output (JSON, CSV) rather than free-form text.
- Send data to stdout, diagnostics to stderr.
- Avoid interactive prompts — accept all input via flags or stdin.
- Design for idempotency where possible.

## Available Scripts

Scripts are in `{baseDir}/scripts/`. Use the full path when invoking.

| Script | Purpose |
|--------|---------|
| `scaffold.sh` | Create a new skill directory with SKILL.md stub |
| `validate.sh` | Validate a skill directory against the spec |
| `update-references.sh` | Fetch latest spec docs from agentskills.io |

### scaffold.sh

```bash
bash {baseDir}/scripts/scaffold.sh <name> [--scripts] [--references] [--assets] [--dir <path>]
```

Creates a skill directory (in `--dir` or the current working directory) with:
- A `SKILL.md` containing valid frontmatter and a body placeholder
- A `**Skill base directory:** \`{baseDir}\`` line in the stub (only when `--scripts` is passed)
- Optional `scripts/`, `references/`, `assets/` subdirectories

The name is validated against the spec's naming rules before creation. Exits
non-zero if the name is invalid or the directory already exists.

### validate.sh

```bash
bash {baseDir}/scripts/validate.sh <skill-directory>
```

Runs these checks:
- SKILL.md exists
- Frontmatter has `name` and `description`
- `name` matches the directory name
- `name` follows naming rules
- `description` is ≤1024 characters
- SKILL.md is ≤500 lines
- Warns on unexpected top-level entries

Prints PASS/FAIL per check. Exits 0 if all pass, 1 if any fail.

### update-references.sh

```bash
bash {baseDir}/scripts/update-references.sh
```

Parses the agentskills.io sitemap, fetches each relevant page as markdown, and
writes them to `{baseDir}/references/`. Records the fetch date in
`{baseDir}/references/.last-updated`.

Run this periodically to keep the vendored spec docs current.

## Creating a Skill: Detailed Steps

### 1. Capture intent

Before scaffolding, clarify with the user:
- What should this skill enable the agent to do?
- When should it trigger? (what user phrases or contexts)
- Does it need scripts, reference docs, or asset files?
- What is the expected output format?

### 2. Scaffold

Run the scaffold script in the target directory (typically the project's skills
directory):

```bash
cd /path/to/skills
bash {baseDir}/scripts/scaffold.sh my-skill --scripts --references
```

### 3. Write the SKILL.md

Replace the stub content with real instructions. Follow this structure:

1. **Frontmatter** with a descriptive `description` field
2. **`{baseDir}` line** — include `**Skill base directory:** \`{baseDir}\`` if the skill has scripts (agents need the resolved path to invoke them)
3. **Overview** — what the skill does in 1-2 sentences
4. **Workflow** — step-by-step instructions for the agent
5. **Script documentation** — if the skill has scripts, document each one
6. **References section** — if the skill has reference docs, list them with
   guidance on when to read each one

### 4. Validate

```bash
bash {baseDir}/scripts/validate.sh /path/to/my-skill
```

Fix any failures and re-validate until all checks pass.

## References

For the full Agent Skills specification and authoring guides, use the Read tool
to load these files. Check `{baseDir}/references/.last-updated` for freshness.

- `{baseDir}/references/specification.md` — complete format specification
- `{baseDir}/references/what-are-skills.md` — overview and concepts
- `{baseDir}/references/skill-creation-using-scripts.md` — script authoring guide
- `{baseDir}/references/skill-creation-evaluating-skills.md` — testing and eval guide
