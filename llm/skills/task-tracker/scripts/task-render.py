#!/usr/bin/env python3
"""
Render tasks.json to human-readable markdown.

Reads .claude/tasks.json (walking up directories to find it) and
outputs a formatted markdown representation grouped by status.
"""

import json
import sys
from pathlib import Path

TASKS_FILE = ".claude/tasks.json"


def find_tasks_file() -> Path | None:
    """Walk up directories to find .claude/tasks.json."""
    current = Path.cwd()
    while current != current.parent:
        candidate = current / TASKS_FILE
        if candidate.exists():
            return candidate
        current = current.parent
    candidate = current / TASKS_FILE
    if candidate.exists():
        return candidate
    return None


def load_tasks(path: Path) -> dict:
    """Load tasks from JSON file."""
    with open(path, "r") as f:
        return json.load(f)


def format_deps(task: dict, all_tasks: list) -> str:
    """Format dependency list for display."""
    deps = task.get("dependencies", [])
    if not deps:
        return ""

    dep_nums = []
    for dep_id in deps:
        for t in all_tasks:
            if t["id"] == dep_id:
                dep_nums.append(str(t["number"]))
                break
            for st in t.get("subtasks", []):
                if st["id"] == dep_id:
                    dep_nums.append(f"{t['number']}.{st['number']}")
                    break

    if dep_nums:
        return f" _(depends on: {', '.join(dep_nums)})_"
    return ""


def render_notes(notes: list, prefix: str = "") -> list[str]:
    """Render notes for a task."""
    lines = []
    for note in notes:
        lines.append(f"{prefix}  > {note['text']}")
    return lines


def render_task(task: dict, all_tasks: list, prefix: str = "") -> list[str]:
    """Render a single task to markdown lines."""
    lines = []
    num = task["number"]
    title = task["title"]
    status = task["status"]
    deps = format_deps(task, all_tasks)

    if status == "complete":
        lines.append(f"{prefix}- [x] **{num}** {title}{deps}")
    elif status == "wont_do":
        lines.append(f"{prefix}- [~] **{num}** ~~{title}~~{deps}")
    else:
        lines.append(f"{prefix}- **{num}** {title}{deps}")

    # Render task notes
    if task.get("notes"):
        lines.extend(render_notes(task["notes"], prefix))

    # Render subtasks indented
    for subtask in task.get("subtasks", []):
        sub_num = f"{num}.{subtask['number']}"
        sub_title = subtask["title"]
        sub_deps = format_deps(subtask, all_tasks)

        if subtask["status"] == "complete":
            lines.append(f"{prefix}  - [x] **{sub_num}** {sub_title}{sub_deps}")
        elif subtask["status"] == "wont_do":
            lines.append(f"{prefix}  - [~] **{sub_num}** ~~{sub_title}~~{sub_deps}")
        else:
            lines.append(f"{prefix}  - **{sub_num}** {sub_title}{sub_deps}")

        # Render subtask notes
        if subtask.get("notes"):
            lines.extend(render_notes(subtask["notes"], prefix + "  "))

    return lines


def main():
    path = find_tasks_file()
    if not path:
        print(f"No {TASKS_FILE} found.", file=sys.stderr)
        sys.exit(1)

    data = load_tasks(path)
    tasks = data.get("tasks", [])

    if not tasks:
        print("# Tasks\n\n_No tasks._")
        return

    # Group by status
    in_progress = [t for t in tasks if t["status"] == "in_progress"]
    pending = [t for t in tasks if t["status"] == "pending"]
    complete = [t for t in tasks if t["status"] == "complete"]
    wont_do = [t for t in tasks if t["status"] == "wont_do"]

    lines = ["# Tasks", ""]

    if in_progress:
        lines.append("## In Progress")
        for task in in_progress:
            lines.extend(render_task(task, tasks))
        lines.append("")

    if pending:
        lines.append("## Pending")
        for task in pending:
            lines.extend(render_task(task, tasks))
        lines.append("")

    if complete:
        lines.append("## Completed")
        for task in complete:
            lines.extend(render_task(task, tasks))
        lines.append("")

    if wont_do:
        lines.append("## Won't Do")
        for task in wont_do:
            lines.extend(render_task(task, tasks))
        lines.append("")

    print("\n".join(lines).rstrip())


if __name__ == "__main__":
    main()
