# Claude Code Custom Commands

This directory contains custom slash commands for Claude Code. Commands are
Markdown files that can be invoked using `/command-name` in Claude Code sessions.

## Creating a Command

Create a new `.md` file in this directory with the following structure:

```markdown
---
description: "Brief description of what this command does"
allowed-tools: ["bash", "read", "write"]  # Optional: restrict tools
model: "claude-sonnet-4-5-20250929"       # Optional: specify model
argument-hint: "[arg1] [arg2]"            # Optional: show usage hint
---

Your command prompt goes here. You can use $1, $2, etc. for arguments.

! bash echo "Example: run bash commands with ! prefix"
```

## Examples

See the [Claude Code documentation](https://claude.com/claude-code) for more
examples and details on command syntax.

## Usage

Commands in this directory are automatically available in any Claude Code session
once symlinked via the install script.
