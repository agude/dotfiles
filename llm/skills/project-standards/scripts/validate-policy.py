#!/usr/bin/env python3
"""Validate the small shared policy used by project-standards helpers."""

from __future__ import annotations

import re
import sys
import tomllib
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"policy: {message}")


def require(mapping: dict[str, object], key: str, context: str) -> object:
    if key not in mapping:
        fail(f"missing {context}.{key}")
    return mapping[key]


if len(sys.argv) != 2:
    raise SystemExit("usage: validate-policy.py POLICY.toml")

policy_path = Path(sys.argv[1])
try:
    with policy_path.open("rb") as opened:
        policy = tomllib.load(opened)
except (OSError, tomllib.TOMLDecodeError) as error:
    fail(str(error))

python = policy.get("python")
if not isinstance(python, dict):
    fail("[python] must be a table")
floor = require(python, "floor", "python")
latest = require(python, "latest", "python")
matrix = require(python, "matrix", "python")
if not all(isinstance(value, str) and re.fullmatch(r"3\.\d+", value) for value in (floor, latest)):
    fail("python floor and latest must be 3.x versions")
if not isinstance(matrix, list) or not all(isinstance(value, str) for value in matrix):
    fail("python matrix must be a list of versions")
if floor not in matrix or latest not in matrix:
    fail("python floor and latest must be in the matrix")
if matrix != sorted(matrix, key=lambda value: tuple(map(int, value.split(".")))):
    fail("python matrix must be in ascending order")
if not isinstance(require(python, "coverage_floor", "python"), int):
    fail("python coverage_floor must be an integer")

actions = policy.get("actions")
if not isinstance(actions, dict):
    fail("[actions] must be a table")
for name, action in actions.items():
    if not isinstance(action, dict) or not isinstance(action.get("ref"), str):
        fail(f"actions.{name}.ref must be a string")
    if not re.fullmatch(r"(v\d+(?:\.\d+)*|release/v\d+|[0-9a-f]{40})", action["ref"]):
        fail(f"actions.{name}.ref is not a supported policy reference")
    if not isinstance(action.get("version"), str) or not re.fullmatch(
        r"(v\d+(?:\.\d+)*|release/v\d+)", action["version"]
    ):
        fail(f"actions.{name}.version must be a readable release reference")

tools = policy.get("tools")
if not isinstance(tools, dict):
    fail("[tools] must be a table")
for name, tool in tools.items():
    if not isinstance(tool, dict) or not re.fullmatch(r"\d+\.\d+\.\d+", str(tool.get("version", ""))):
        fail(f"tools.{name}.version must be a dotted version")

recipes = policy.get("recipes")
if not isinstance(recipes, dict):
    fail("[recipes] must be a table")
python_recipes = recipes.get("python")
if not isinstance(python_recipes, dict):
    fail("[recipes.python] must be a table")
required = python_recipes.get("required")
if not isinstance(required, str) or not {"lint", "type-check", "test", "check"}.issubset(required.split()):
    fail("recipes.python.required must include lint, type-check, test, and check")

print(f"policy: valid ({policy_path})")
