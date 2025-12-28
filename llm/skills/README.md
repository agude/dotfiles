# Agent Skills

This directory contains [Agent Skills](https://agentskills.io) that work across
multiple LLM CLI tools (Claude Code, Goose, etc.).

## What are Agent Skills?

Agent Skills are folders of instructions, scripts, and resources that LLM agents
can discover and use to perform tasks more accurately and efficiently. Unlike
slash commands (which you invoke explicitly), skills are passive knowledge that
agents draw on automatically when relevant.

## Structure

Each skill is a folder containing a `SKILL.md` file:

```
skill-name/
├── SKILL.md              # Required: frontmatter + instructions
├── scripts/              # Optional: executable code
├── references/           # Optional: supporting docs (loaded on demand)
└── assets/               # Optional: templates, images, data
```

## SKILL.md Format

```yaml
---
name: skill-name          # Required: 1-64 chars, lowercase + hyphens
description: ...          # Required: 1-1024 chars, what/when to use
license: ...              # Optional
compatibility: ...        # Optional: env requirements
metadata: {}              # Optional: key-value pairs
allowed-tools: []         # Optional: pre-approved tools (experimental)
---

# Skill Name

[Markdown instructions - keep under 500 lines]

## Examples

- Example usage 1
- Example usage 2

## Guidelines

- Best practice 1
- Best practice 2
```

## Creating a Skill

1. Create a new directory: `mkdir skill-name/`
2. Create `SKILL.md` with required frontmatter
3. Add optional `scripts/`, `references/`, or `assets/` as needed
4. Validate: `skills-ref validate ./skill-name/`

## Installation

Skills in this directory are automatically available after running:

```bash
./install.sh
```

This symlinks `llm/skills/` to `~/.claude/skills/`, making skills available to:
- **Claude Code**: Reads `~/.claude/skills/` natively
- **Goose**: Also reads `~/.claude/skills/` natively

## Resources

- [Agent Skills Specification](https://agentskills.io/specification)
- [Anthropic Skills Repository](https://github.com/anthropics/skills)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
