# tasks.json Schema

Complete schema for `.claude/tasks.json`.

## Root Object

```json
{
  "version": "1",
  "created_at": "2026-01-06T10:30:00+00:00",
  "updated_at": "2026-01-06T11:45:00+00:00",
  "tasks": [ ... ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| version | string | yes | Schema version ("1") |
| created_at | ISO8601 | yes | File creation timestamp |
| updated_at | ISO8601 | yes | Last modification timestamp |
| tasks | array | yes | List of top-level tasks |

## Task Object

```json
{
  "id": "a3f2b1c9",
  "number": 1,
  "title": "Implement feature X",
  "description": "Optional longer description",
  "status": "in_progress",
  "dependencies": ["b4e3c2d8"],
  "created_at": "2026-01-06T10:30:00+00:00",
  "updated_at": "2026-01-06T11:45:00+00:00",
  "subtasks": [ ... ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | yes | 8-character hex identifier |
| number | integer | yes | Human-readable task number (1, 2, 3...) |
| title | string | yes | Short task description |
| description | string | no | Longer context or details |
| status | enum | yes | One of: pending, in_progress, complete, wont_do |
| dependencies | array | no | IDs of tasks that must complete first |
| notes | array | no | List of note objects (learnings, context) |
| created_at | ISO8601 | yes | Task creation timestamp |
| updated_at | ISO8601 | yes | Last modification timestamp |
| subtasks | array | no | List of subtask objects (top-level tasks only) |

## Note Object

```json
{
  "text": "Discovered we need to handle edge case X",
  "created_at": "2026-01-07T10:30:00+00:00"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| text | string | yes | The note content |
| created_at | ISO8601 | yes | When the note was added |

## Subtask Object

Same as Task, except:
- `number` is the subtask number within parent (1, 2, 3...)
- Display ID is `parent.subtask` (e.g., "1.2")
- No `subtasks` field (two-level max)

## Status Values

| Status | Description |
|--------|-------------|
| `pending` | Task not yet started |
| `in_progress` | Currently being worked on |
| `complete` | Successfully finished |
| `wont_do` | Cancelled or skipped |

## ID Resolution

Commands accept multiple ID formats:

| Format | Example | Description |
|--------|---------|-------------|
| Number | `1` | Top-level task number |
| Subtask | `1.2` | Parent.subtask number |
| Hash | `a3f2b1c9` | Full 8-char hash |
| Partial | `a3f2` | Prefix match (must be unambiguous) |

## Example File

```json
{
  "version": "1",
  "created_at": "2026-01-06T10:00:00+00:00",
  "updated_at": "2026-01-06T12:30:00+00:00",
  "tasks": [
    {
      "id": "a3f2b1c9",
      "number": 1,
      "title": "Implement user authentication",
      "description": "Add login/logout functionality",
      "status": "in_progress",
      "dependencies": [],
      "notes": [
        {"text": "Need to support OAuth in addition to password", "created_at": "2026-01-06T10:30:00+00:00"}
      ],
      "created_at": "2026-01-06T10:00:00+00:00",
      "updated_at": "2026-01-06T11:00:00+00:00",
      "subtasks": [
        {
          "id": "b4e3c2d8",
          "number": 1,
          "title": "Create login form",
          "status": "complete",
          "created_at": "2026-01-06T10:05:00+00:00",
          "updated_at": "2026-01-06T10:30:00+00:00"
        },
        {
          "id": "c5f4d3e9",
          "number": 2,
          "title": "Add session management",
          "status": "pending",
          "created_at": "2026-01-06T10:05:00+00:00",
          "updated_at": "2026-01-06T10:05:00+00:00"
        }
      ]
    },
    {
      "id": "d6e5f4a0",
      "number": 2,
      "title": "Deploy to staging",
      "status": "pending",
      "dependencies": ["a3f2b1c9"],
      "created_at": "2026-01-06T10:10:00+00:00",
      "updated_at": "2026-01-06T10:10:00+00:00",
      "subtasks": []
    }
  ]
}
```
