---
name: task-tracker
description: Track tasks and subtasks in .claude/tasks/ for context preservation. Use when planning multi-step work, tracking progress, or resuming interrupted sessions.
---

# Task Tracker

Persist task state across LLM sessions using markdown files in `.claude/tasks/`.
Helps agents plan and remember what they're working on, and track progress through
multi-step work.

## Quick Start

```bash
# Initialize in current project
task.py init

# Add tasks
task.py add "Implement user authentication"
task.py add "Write login tests" --parent 01-implement-user-authentication

# Work through tasks
task.py start 01-implement-user-authentication
task.py done
task.py next
```

## Directory Structure

Tasks are stored as markdown files. The filesystem hierarchy represents task hierarchy:

```
.claude/tasks/
  01-auth-login/
    00-index.md                    # Parent task metadata
    01-create-login-form.md        # Subtask (leaf)
    02-session-management/
      00-index.md                  # Nested parent
      01-implement-jwt.md          # Leaf
      02-add-refresh-tokens.md     # Leaf
  02-deploy-staging.md             # Top-level leaf task
```

**Key rules:**
- Leaf tasks (no children) → `.md` files
- Parent tasks (have children) → directories with `00-index.md`
- Adding a subtask to a leaf automatically promotes it to a directory
- Removing the last child automatically demotes back to a file

## Task File Format

Each task is a markdown file with YAML frontmatter:

```markdown
---
status: pending
created: 2026-01-06T10:30:00+00:00
updated: 2026-01-06T11:45:00+00:00
deps:
  - 01-auth-login
approach: Use bcrypt for passwords, JWT for sessions
criteria:
  - Login endpoint returns JWT
  - Invalid creds return 401
files:
  - src/routes/auth.ts
  - src/middleware/jwt.ts
---

# Implement session management

Optional longer description here.

## Notes

### 2026-01-06T10:30:00+00:00

Discovered we need to handle token refresh.

### 2026-01-07T14:00:00+00:00

Redis cluster mode requires different client config.
```

### Statuses

| Status | Meaning |
|--------|---------|
| `pending` | Not started |
| `in_progress` | Currently working on |
| `blocked` | Waiting on external factor |
| `complete` | Done |
| `wont_do` | Cancelled/skipped |

### Planning Fields

Optional fields for AI agent context preservation:

| Field | Purpose |
|-------|---------|
| `approach` | How to implement (the plan) |
| `criteria` | What "done" means (list) |
| `files` | Where to look (list of paths) |

These help an agent resume work across sessions without re-discovering context.

## Commands

All output is JSON. Scripts are in `scripts/` directory.

### Initialize

```bash
task.py init
```

Creates `.claude/tasks/` directory.

### Add Task

```bash
task.py add "Task title"
task.py add "Subtask title" --parent 01-parent-task
task.py add "Task with deps" --deps 01-auth-login 02-database
task.py add "With description" --description "Detailed info"
task.py add "With approach" --approach "Use existing auth middleware"
task.py add "With criteria" --criteria "Tests pass" "Docs updated"
task.py add "With files" --files src/auth.ts src/middleware.ts
```

Adding a subtask to a leaf task automatically promotes it to a directory.

### Remove Task

```bash
task.py remove 01-auth-login              # Remove task
task.py remove 01-auth-login/02-session   # Remove subtask
```

Removing the last child of a parent automatically demotes it back to a file.

### Update Task

```bash
task.py update 01-auth-login --title "New title"
task.py update 01-auth-login --status complete
task.py update 01-auth-login --deps 02-database
task.py update 01-auth-login --approach "Changed to use Redis"
task.py update 01-auth-login --criteria "Cache hits > 90%"
task.py update 01-auth-login --files src/cache.ts
```

### List Tasks

```bash
task.py list
task.py list --status pending
task.py list --status in_progress
```

### Show Task

```bash
task.py show 01-auth-login
task.py show 01-auth-login/02-session
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
task.py start 01-auth-login
```

Sets status to `in_progress` and records start time. Warns (but allows) if
dependencies incomplete.

### Complete Task

```bash
task.py done                  # Current in_progress task
task.py done 01-auth-login    # Specific task
```

### Block/Unblock Task

```bash
task.py block 01-auth-login --reason "Waiting on API spec"
task.py unblock 01-auth-login
```

### Add Note

```bash
task.py note 01-auth-login "Discovered edge case X"
task.py note 01-auth-login/02-session "Harder than expected"
```

Attach learnings, context, or decisions to a task. Notes are timestamped and
preserved for future sessions.

### View All Notes

```bash
task.py notes
```

Returns all notes chronologically across all tasks - a project journal showing
what you learned over time.

### Move Task

```bash
task.py move 01-auth-login/03-feature --parent 02-backend
task.py move 02-backend/01-api                             # Move to top level
```

Moves a task to a new location and updates any dependency references.

## Dependencies

Tasks can depend on other tasks by path:

```bash
task.py add "Deploy" --deps 01-auth-login 02-database-setup
```

Dependencies are soft-blocking:
- `next` skips tasks with incomplete dependencies
- `start` warns but allows starting with incomplete deps

## Rendering for Humans

Use `task-render.py` to generate readable markdown:

```bash
task-render.py
```

Output:
```markdown
# Tasks

## In Progress
- **01-auth-login** Implement feature
  _Approach: Use JWT tokens_
  > Discovered we need auth middleware first
  - **01-auth-login/01-create-form** Create login form

## Pending
- **02-deploy-staging** Deploy _(depends on: 01-auth-login)_

## Completed
- [x] **01-auth-login/02-session** Add session management
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
  "error": "Task not found: 01-missing"
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
2. **Resuming after time away**: Run `task.py notes` to review learnings
3. **Beginning work**: Run `task.py start <id>` on the task
4. **Breaking down work**: Add subtasks with `--parent`
5. **Capturing learnings**: Run `task.py note <id> "text"` when you discover something
6. **Completing**: Run `task.py done` when finished
7. **Repeat**: Run `task.py next` for the next task

## References

- `references/markdown-format.md` - The task file format specification
- `references/project-breakdown.md` - How to decompose projects into atomic tasks
