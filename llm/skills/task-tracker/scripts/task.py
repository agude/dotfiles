#!/usr/bin/env python3
"""
Task tracker for LLM context preservation.

Stores tasks in .claude/tasks.json, walking up directories to find it.
All output is JSON for machine consumption.
"""

import argparse
import json
import secrets
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


def short_id() -> str:
    """Generate an 8-character hex ID."""
    return secrets.token_hex(4)


TASKS_FILE = ".claude/tasks.json"
VALID_STATUSES = ("pending", "in_progress", "complete", "wont_do")


def output_success(data: dict) -> None:
    """Print success response and exit 0."""
    print(json.dumps({"ok": True, **data}))
    sys.exit(0)


def output_error(message: str) -> None:
    """Print error response and exit 1."""
    print(json.dumps({"ok": False, "error": message}))
    sys.exit(1)


def now_iso() -> str:
    """Return current time as ISO8601 string."""
    return datetime.now(timezone.utc).isoformat()


def find_tasks_file() -> Optional[Path]:
    """Walk up directories to find .claude/tasks.json."""
    current = Path.cwd()
    while current != current.parent:
        candidate = current / TASKS_FILE
        if candidate.exists():
            return candidate
        current = current.parent
    # Check root
    candidate = current / TASKS_FILE
    if candidate.exists():
        return candidate
    return None


def load_tasks(path: Path) -> dict:
    """Load tasks from JSON file."""
    try:
        with open(path, "r") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        output_error(f"Invalid JSON in {path}: {e}")
    except Exception as e:
        output_error(f"Error reading {path}: {e}")


def save_tasks(path: Path, data: dict) -> None:
    """Save tasks to JSON file."""
    data["updated_at"] = now_iso()
    try:
        with open(path, "w") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        output_error(f"Error writing {path}: {e}")


def require_tasks_file() -> tuple[Path, dict]:
    """Find and load tasks file, or error."""
    path = find_tasks_file()
    if not path:
        output_error(f"No {TASKS_FILE} found. Run 'task.py init' first.")
    return path, load_tasks(path)


def resolve_id(data: dict, id_str: str) -> Optional[dict]:
    """
    Resolve ID to a task dict.
    Accepts: short hash, partial hash, number (1), subtask number (1.2)
    Returns the task/subtask dict or None.
    """
    # Try number format (1 or 1.2)
    if "." in id_str:
        parts = id_str.split(".")
        if len(parts) == 2:
            try:
                task_num = int(parts[0])
                subtask_num = int(parts[1])
                for task in data["tasks"]:
                    if task["number"] == task_num:
                        for subtask in task.get("subtasks", []):
                            if subtask["number"] == subtask_num:
                                return subtask
            except ValueError:
                pass
    else:
        try:
            num = int(id_str)
            for task in data["tasks"]:
                if task["number"] == num:
                    return task
        except ValueError:
            pass

    # Try hash or partial hash
    matches = []
    for task in data["tasks"]:
        if task["id"] == id_str or task["id"].startswith(id_str):
            matches.append(task)
        for subtask in task.get("subtasks", []):
            if subtask["id"] == id_str or subtask["id"].startswith(id_str):
                matches.append(subtask)

    if len(matches) == 1:
        return matches[0]
    elif len(matches) > 1:
        output_error(f"Ambiguous ID '{id_str}' matches {len(matches)} tasks")

    return None


def find_parent_task(data: dict, subtask_id: str) -> Optional[dict]:
    """Find the parent task of a subtask."""
    for task in data["tasks"]:
        for subtask in task.get("subtasks", []):
            if subtask["id"] == subtask_id:
                return task
    return None


def get_task_display_id(data: dict, task: dict) -> str:
    """Get the human-readable ID (1 or 1.2) for a task."""
    if "subtasks" in task or task in data["tasks"]:
        # It's a top-level task
        return str(task["number"])
    # It's a subtask - find parent
    parent = find_parent_task(data, task["id"])
    if parent:
        return f"{parent['number']}.{task['number']}"
    return str(task["number"])


def deps_satisfied(data: dict, task: dict) -> tuple[bool, list[str]]:
    """Check if all dependencies are complete. Returns (satisfied, incomplete_ids)."""
    incomplete = []
    for dep_id in task.get("dependencies", []):
        dep_task = None
        for t in data["tasks"]:
            if t["id"] == dep_id:
                dep_task = t
                break
            for st in t.get("subtasks", []):
                if st["id"] == dep_id:
                    dep_task = st
                    break
            if dep_task:
                break
        if dep_task and dep_task["status"] != "complete":
            incomplete.append(get_task_display_id(data, dep_task))
    return len(incomplete) == 0, incomplete


def next_task_number(data: dict) -> int:
    """Get the next available task number."""
    if not data["tasks"]:
        return 1
    return max(t["number"] for t in data["tasks"]) + 1


def next_subtask_number(task: dict) -> int:
    """Get the next available subtask number."""
    subtasks = task.get("subtasks", [])
    if not subtasks:
        return 1
    return max(st["number"] for st in subtasks) + 1


# ============ Commands ============


def cmd_init(args: argparse.Namespace) -> None:
    """Initialize a new tasks.json file."""
    path = Path.cwd() / TASKS_FILE
    if path.exists():
        output_error(f"{path} already exists")

    # Create .claude directory if needed
    path.parent.mkdir(parents=True, exist_ok=True)

    data = {
        "version": "1",
        "created_at": now_iso(),
        "updated_at": now_iso(),
        "tasks": [],
    }
    save_tasks(path, data)
    output_success({"message": f"Created {path}", "path": str(path)})


def cmd_add(args: argparse.Namespace) -> None:
    """Add a new task or subtask."""
    path, data = require_tasks_file()

    task = {
        "id": short_id(),
        "title": args.title,
        "status": "pending",
        "created_at": now_iso(),
        "updated_at": now_iso(),
    }

    if args.description:
        task["description"] = args.description
    if args.deps:
        # Resolve dependency IDs
        dep_ids = []
        for dep_id in args.deps:
            dep_task = resolve_id(data, dep_id)
            if not dep_task:
                output_error(f"Dependency not found: {dep_id}")
            dep_ids.append(dep_task["id"])
        task["dependencies"] = dep_ids

    if args.parent:
        # Add as subtask
        parent = resolve_id(data, args.parent)
        if not parent:
            output_error(f"Parent task not found: {args.parent}")
        if "subtasks" not in parent:
            parent["subtasks"] = []
        task["number"] = next_subtask_number(parent)
        parent["subtasks"].append(task)
        parent["updated_at"] = now_iso()
        display_id = f"{parent['number']}.{task['number']}"
    else:
        # Add as top-level task
        task["number"] = next_task_number(data)
        task["subtasks"] = []
        data["tasks"].append(task)
        display_id = str(task["number"])

    save_tasks(path, data)
    output_success({"task": task, "id": display_id})


def cmd_remove(args: argparse.Namespace) -> None:
    """Remove a task or subtask."""
    path, data = require_tasks_file()

    task = resolve_id(data, args.id)
    if not task:
        output_error(f"Task not found: {args.id}")

    display_id = get_task_display_id(data, task)

    # Check if it's a subtask
    parent = find_parent_task(data, task["id"])
    if parent:
        parent["subtasks"] = [st for st in parent["subtasks"] if st["id"] != task["id"]]
        parent["updated_at"] = now_iso()
    else:
        data["tasks"] = [t for t in data["tasks"] if t["id"] != task["id"]]

    save_tasks(path, data)
    output_success({"removed": display_id, "task": task})


def cmd_update(args: argparse.Namespace) -> None:
    """Update a task's fields."""
    path, data = require_tasks_file()

    task = resolve_id(data, args.id)
    if not task:
        output_error(f"Task not found: {args.id}")

    if args.title:
        task["title"] = args.title
    if args.description:
        task["description"] = args.description
    if args.status:
        if args.status not in VALID_STATUSES:
            output_error(
                f"Invalid status: {args.status}. Valid: {', '.join(VALID_STATUSES)}"
            )
        task["status"] = args.status
    if args.deps is not None:
        dep_ids = []
        for dep_id in args.deps:
            dep_task = resolve_id(data, dep_id)
            if not dep_task:
                output_error(f"Dependency not found: {dep_id}")
            dep_ids.append(dep_task["id"])
        task["dependencies"] = dep_ids

    task["updated_at"] = now_iso()
    save_tasks(path, data)
    output_success({"task": task, "id": get_task_display_id(data, task)})


def cmd_list(args: argparse.Namespace) -> None:
    """List all tasks."""
    path, data = require_tasks_file()

    tasks = []
    for task in data["tasks"]:
        if args.status and task["status"] != args.status:
            continue
        task_copy = {**task, "id": str(task["number"])}
        # Add subtask IDs
        if task.get("subtasks"):
            task_copy["subtasks"] = [
                {**st, "id": f"{task['number']}.{st['number']}"}
                for st in task["subtasks"]
                if not args.status or st["status"] == args.status
            ]
        tasks.append(task_copy)

    output_success({"tasks": tasks, "count": len(tasks)})


def cmd_show(args: argparse.Namespace) -> None:
    """Show a single task."""
    path, data = require_tasks_file()

    task = resolve_id(data, args.id)
    if not task:
        output_error(f"Task not found: {args.id}")

    display_id = get_task_display_id(data, task)
    satisfied, incomplete = deps_satisfied(data, task)

    result = {
        "task": task,
        "id": display_id,
        "deps_satisfied": satisfied,
    }
    if not satisfied:
        result["incomplete_deps"] = incomplete

    output_success(result)


def cmd_next(args: argparse.Namespace) -> None:
    """Get the next task to work on (depth-first, deps satisfied)."""
    path, data = require_tasks_file()

    # First, check if there's an in_progress task with pending subtasks
    for task in data["tasks"]:
        if task["status"] == "in_progress":
            for subtask in task.get("subtasks", []):
                if subtask["status"] == "pending":
                    satisfied, _ = deps_satisfied(data, subtask)
                    if satisfied:
                        output_success(
                            {
                                "task": subtask,
                                "id": f"{task['number']}.{subtask['number']}",
                                "reason": "pending subtask of in_progress task",
                            }
                        )

    # No in_progress with pending subtasks, find first pending with satisfied deps
    for task in data["tasks"]:
        if task["status"] == "pending":
            satisfied, _ = deps_satisfied(data, task)
            if satisfied:
                output_success(
                    {
                        "task": task,
                        "id": str(task["number"]),
                        "reason": "first pending task with satisfied dependencies",
                    }
                )

    output_success({"task": None, "reason": "no available tasks"})


def cmd_start(args: argparse.Namespace) -> None:
    """Start working on a task (set to in_progress)."""
    path, data = require_tasks_file()

    task = resolve_id(data, args.id)
    if not task:
        output_error(f"Task not found: {args.id}")

    display_id = get_task_display_id(data, task)

    # Check dependencies (soft blocking - warn but allow)
    satisfied, incomplete = deps_satisfied(data, task)
    warnings = []
    if not satisfied:
        warnings.append(
            f"Starting with incomplete dependencies: {', '.join(incomplete)}"
        )

    task["status"] = "in_progress"
    task["updated_at"] = now_iso()
    save_tasks(path, data)

    result = {"task": task, "id": display_id}
    if warnings:
        result["warnings"] = warnings
    output_success(result)


def cmd_done(args: argparse.Namespace) -> None:
    """Mark a task complete."""
    path, data = require_tasks_file()

    if args.id:
        task = resolve_id(data, args.id)
        if not task:
            output_error(f"Task not found: {args.id}")
    else:
        # Find current in_progress task
        task = None
        for t in data["tasks"]:
            if t["status"] == "in_progress":
                # Check for in_progress subtasks first
                for st in t.get("subtasks", []):
                    if st["status"] == "in_progress":
                        task = st
                        break
                if not task:
                    task = t
                break
        if not task:
            output_error("No in_progress task found. Specify an ID.")

    display_id = get_task_display_id(data, task)
    task["status"] = "complete"
    task["updated_at"] = now_iso()
    save_tasks(path, data)
    output_success({"task": task, "id": display_id})


def main():
    parser = argparse.ArgumentParser(
        description="Task tracker for LLM context preservation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # init
    subparsers.add_parser("init", help="Create .claude/tasks.json")

    # add
    add_parser = subparsers.add_parser("add", help="Add a task")
    add_parser.add_argument("title", help="Task title")
    add_parser.add_argument("--parent", "-p", help="Parent task ID (for subtasks)")
    add_parser.add_argument("--description", "-d", help="Task description")
    add_parser.add_argument("--deps", nargs="*", help="Dependency task IDs")

    # remove
    remove_parser = subparsers.add_parser("remove", help="Remove a task")
    remove_parser.add_argument("id", help="Task ID (number, UUID, or partial UUID)")

    # update
    update_parser = subparsers.add_parser("update", help="Update a task")
    update_parser.add_argument("id", help="Task ID")
    update_parser.add_argument("--title", "-t", help="New title")
    update_parser.add_argument("--description", "-d", help="New description")
    update_parser.add_argument(
        "--status", "-s", choices=VALID_STATUSES, help="New status"
    )
    update_parser.add_argument(
        "--deps", nargs="*", help="New dependency IDs (replaces existing)"
    )

    # list
    list_parser = subparsers.add_parser("list", help="List tasks")
    list_parser.add_argument(
        "--status", "-s", choices=VALID_STATUSES, help="Filter by status"
    )

    # show
    show_parser = subparsers.add_parser("show", help="Show a task")
    show_parser.add_argument("id", help="Task ID")

    # next
    subparsers.add_parser("next", help="Get next available task")

    # start
    start_parser = subparsers.add_parser("start", help="Start a task (set in_progress)")
    start_parser.add_argument("id", help="Task ID")

    # done
    done_parser = subparsers.add_parser("done", help="Mark task complete")
    done_parser.add_argument(
        "id", nargs="?", help="Task ID (default: current in_progress)"
    )

    args = parser.parse_args()

    commands = {
        "init": cmd_init,
        "add": cmd_add,
        "remove": cmd_remove,
        "update": cmd_update,
        "list": cmd_list,
        "show": cmd_show,
        "next": cmd_next,
        "start": cmd_start,
        "done": cmd_done,
    }

    commands[args.command](args)


if __name__ == "__main__":
    main()
