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

## Script Design Pattern: Human vs Agent Mode

When writing scripts that both humans and agents will use, follow this pattern:

### Detection

```bash
# In your shared library (e.g., lib.sh):
PORCELAIN="false"

parse_common_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --porcelain) PORCELAIN="true"; shift ;;
            *) REMAINING_ARGS+=("$1"); shift ;;
        esac
    done
    init_colors  # Only set colors if not porcelain
}

is_interactive() {
    [[ -t 1 ]] && [[ -t 0 ]] && [[ "$PORCELAIN" != "true" ]]
}

init_colors() {
    if [[ -t 1 ]] && [[ "$PORCELAIN" != "true" ]]; then
        COLOR_SUCCESS=$'\033[0;32m'
        COLOR_ERROR=$'\033[0;31m'
        COLOR_RESET=$'\033[0m'
    fi
}
```

### Behavior Differences

| Feature | Human Mode | Agent Mode (--porcelain) |
|---------|------------|--------------------------|
| **Output format** | Short, colored | Full paths, plain |
| **Paths** | Basenames | Absolute paths |
| **Interactive** | Opens $EDITOR | Requires all args |
| **Errors** | Colored to stderr | Plain to stderr |

### Example Script

```bash
#!/usr/bin/env bash
source "${SCRIPT_DIR}/lib.sh"
parse_common_args "$@"
set -- "${REMAINING_ARGS[@]}"

# Interactive feature (human only)
if [[ -z "$text" ]] && is_interactive; then
    text=$(get_from_editor)
elif [[ -z "$text" ]]; then
    error "Text required in non-interactive mode"
    exit 1
fi

# Output (format depends on mode)
if [[ "$PORCELAIN" == "true" ]]; then
    echo "$full_path"
else
    success "Created: $(basename "$full_path")"
fi
```

### Document in SKILL.md

Add an "Agent Usage" section explaining `--porcelain` behavior:

```markdown
## Agent Usage (--porcelain)

All scripts support `--porcelain` for machine-readable output:
- Full paths instead of basenames
- No colors or decorations
- Errors to stderr with exit code 1
- No interactive features (editor, prompts)
```

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
