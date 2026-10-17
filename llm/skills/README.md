# Agent Skills

This directory contains [Agent Skills](https://agentskills.io) that work across
multiple LLM CLI tools (Claude Code, Goose, etc.).

## What are Agent Skills?

Agent Skills are folders of instructions, scripts, and resources that LLM agents
can discover and use to perform tasks more accurately and efficiently. The
[Agent Skills spec](https://agentskills.io) is an open standard supported by
Claude Code, Codex CLI, and others. Hosts can select skills automatically or
expose explicit invocation. Discovery, invocation, and permissions vary by host.

## Structure

Each skill is a folder containing a `SKILL.md` file:

```
skill-name/
├── SKILL.md              # Required: frontmatter + instructions
├── scripts/              # Optional: executable code
├── references/           # Optional: supporting docs (loaded on demand)
├── assets/               # Optional: templates, images, data
└── agents/               # Optional: client-specific metadata
```

## SKILL.md Format

```yaml
---
name: skill-name          # Required: 1-64 chars, lowercase + hyphens
description: ...          # Required: 1-1024 chars, what/when to use
license: ...              # Optional
compatibility: ...        # Optional: env requirements
metadata: {}              # Optional: key-value pairs
allowed-tools: "tool names" # Optional, experimental; support varies by client
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

Keep shared workflows independent of host extensions. Unsupported fields are
not guaranteed to be ignored. See
[portability checks](skill-creator/references/portability.md) before adding
host-specific invocation, tool, or permission settings.

## Creating a Skill

Use the `skill-creator` skill; it scaffolds, validates, and carries the current
authoring guidance. Manually:

1. Create a new directory: `mkdir skill-name/`
2. Create `SKILL.md` with required frontmatter
3. Add optional `scripts/`, `references/`, or `assets/` as needed
4. Validate: `bash skill-creator/scripts/validate.sh ./skill-name/`

The validator requires uv and Python 3.11+; uv resolves its pinned PyYAML
dependency. It checks shared metadata, not host behavior or task quality.

## Bundled Resource Paths

`$SKILL_DIR` means the absolute directory containing the active skill's
`SKILL.md`. Replace it in command examples with the resolved path from the
skill's source; do not assume the variable is pre-set. Keep the current
directory in the target project, then invoke
scripts as `"$SKILL_DIR/scripts/<name>"` and read references from
`$SKILL_DIR/references/`. Do not assume the target project has a `scripts/`
directory.

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

This creates skill symlinks from `llm/skills/` to the native global skill
directories, making skills available to:
- **Claude Code**: Reads `~/.claude/skills/` natively
- **Codex CLI**: Reads `~/.agents/skills/` natively
- **OpenCode**: Reads `~/.agents/skills/` natively
- **Pi**: Reads `~/.agents/skills/` natively

## Publish Johnny.Decimal to Documents

From the dotfiles repository, preview and deploy the shared copy:

```bash
just publish-jd --dry-run
just publish-jd
```

The publisher requires Python 3.10+ (or uv) and copies `SKILL.md`, `references/`,
`scripts/`, and optional `assets/` and `agents/` from
`llm/skills/johnny-decimal/` into
`Documents/.agents/skills/johnny-decimal/` and
`Documents/.claude/skills/johnny-decimal/`. Tests are not deployed. Missing
workspace `AGENTS.md`, `CLAUDE.md`, and `WINDOWS-HANDOFF.md` files are seeded from
`llm/johnnydecimal/workspace/`; existing copies are preserved.
The Documents root defaults to `$XDG_DOCUMENTS_DIR` or `~/Documents` and must
already exist. For another mount, run:

```bash
uv run --no-project bin/publish-jd.py --documents "/path/to/shared Documents" --dry-run
uv run --no-project bin/publish-jd.py --documents "/path/to/shared Documents"
```

Edit the source in dotfiles, then publish again. A content manifest detects
local edits, additions, and deletions in the deployed copy; publication stops
until those changes are reconciled. Existing directories without a manifest
and symlink destinations are also rejected. An unchanged deployment is a no-op.

Updates replace the deployed skill and retain the previous version under
each target's `skill-backups/` directory. Backups are retained until manually removed.
A failed replacement attempts to restore the previous version. Publication
uses a lock directory at a `.publish-jd.lock` in each target's `.agents/` or `.claude/` directory; after an
interrupted process, inspect the destination and backups and confirm no
publisher is running before removing a stale lock.

The deployed tools use Python 3.10+ without Bash or Unix utilities and derive
the document root from their deployed location. Explicit path overrides remain
available. The root `WINDOWS-HANDOFF.md` guides the Windows agent through
examining available runtimes and validating execution. A launcher is deferred. See the [installation and validation guide](johnny-decimal/references/installation.md)
for Windows commands, root precedence, backups, and discovery fallback.

## Resources

- [Agent Skills Specification](https://agentskills.io/specification)
- [Anthropic Skills Repository](https://github.com/anthropics/skills)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
