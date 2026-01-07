---
name: task-tracker
description: Track tasks and subtasks in .claude/tasks.json for context preservation. Use when planning multi-step work, tracking progress, or resuming interrupted sessions.
---

# Task Tracker

Persist task state across LLM sessions using `.claude/tasks.json`. Helps your
agents plan and remember what they're working on, and track progress through
multi-step work.

## Quick Start

```bash
# Initialize in current project
./scripts/task.py init

# Add tasks
./scripts/task.py add "Implement user authentication"
./scripts/task.py add "Write login tests" --parent 1

# Work through tasks
./scripts/task.py start 1
./scripts/task.py done
./scripts/task.py next
```

## Task Structure

Two-level hierarchy: tasks and subtasks.

```
Task 1: Implement feature
  └─ Subtask 1.1: Write tests
  └─ Subtask 1.2: Update docs
Task 2: Deploy
```

### Statuses

| Status | Meaning |
|--------|---------|
| `pending` | Not started |
| `in_progress` | Currently working on |
| `complete` | Done |
| `wont_do` | Cancelled/skipped |

## Commands

All output is JSON. Scripts are in `scripts/` directory.

### Initialize

```bash
task.py init
```

Creates `.claude/tasks.json` in current directory.

### Add Task

```bash
task.py add "Task title"
task.py add "Subtask title" --parent 1
task.py add "Task with deps" --deps 1 2
task.py add "With description" --description "Detailed info"
```

### Remove Task

```bash
task.py remove 1      # By number
task.py remove 1.2    # Subtask
task.py remove a3f2   # Partial UUID
```

### Update Task

```bash
task.py update 1 --title "New title"
task.py update 1 --status complete
task.py update 1 --deps 2 3
task.py update 1 --description "New description"
```

### List Tasks

```bash
task.py list
task.py list --status pending
task.py list --status in_progress
```

### Show Task

```bash
task.py show 1
task.py show 1.2
```

Returns task details including dependency status.

### Get Next Task

```bash
task.py next
```

Returns the next task to work on using depth-first logic:
1. If in_progress task has pending subtasks → first pending subtask
2. Otherwise → first pending task with satisfied dependencies

### Start Task

```bash
task.py start 1
task.py start 1.2
```

Sets status to `in_progress`. Warns (but allows) if dependencies incomplete.

### Complete Task

```bash
task.py done      # Current in_progress task
task.py done 1    # Specific task
```

## Dependencies

Tasks can depend on other tasks. Dependencies are soft-blocking:

- `next` skips tasks with incomplete dependencies
- `start` warns but allows starting with incomplete deps

```bash
# Task 2 depends on Task 1
task.py add "Deploy" --deps 1
```

## File Location

The script walks up directories to find `.claude/tasks.json` (like git finds
`.git`). This makes it work from any subdirectory of your project.

## Rendering for Humans

Use `task-render.py` to generate readable markdown:

```bash
./scripts/task-render.py
```

Output:
```markdown
# Tasks

## In Progress
- **1** Implement feature
  - **1.1** Write tests

## Pending
- **2** Deploy _(depends on: 1)_

## Completed
- [x] **1.2** Update docs
```

## JSON Output Format

### Success

```json
{
  "ok": true,
  "task": { ... }
}
```

### Error (exit code 1)

```json
{
  "ok": false,
  "error": "Task not found: 1.3"
}
```

### List

```json
{
  "ok": true,
  "tasks": [ ... ],
  "count": 5
}
```

## Typical Workflow

1. **Starting a session**: Run `task.py next` to see what to work on
2. **Beginning work**: Run `task.py start <id>` on the task
3. **Breaking down work**: Add subtasks with `--parent`
4. **Completing**: Run `task.py done` when finished
5. **Repeat**: Run `task.py next` for the next task

## Schema Reference

See `references/json-schema.md` for the complete tasks.json schema.
