"""Enumerate line-level mutants of Bash functions and marked regions.

Bash has no maintained mutation tool, so this applies a fixed set of textual
operators to one occurrence at a time. Scope is limited to named functions
(``name() {`` through the next column-zero ``}``) and to regions delimited by
start and end regular expressions. Comment lines and ``echo`` lines are not
mutated: their text is never part of a decision. Every mutant must pass
``bash -n``.
"""

from __future__ import annotations

from pathlib import Path
import re
import subprocess

from mutants import Mutant, make_key

FUNCTION_START = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\(\)\s*\{\s*$")

# (operator, pattern, replacement, description). Patterns match one
# occurrence; each occurrence yields its own mutant.
SUBSTITUTIONS: list[tuple[str, str, str, str]] = [
    ("test-flag", r"(?<=\[\[ )-L(?= )", "-e", "'-L' -> '-e'"),
    ("test-flag", r"(?<=\[\[ )-e(?= )", "-L", "'-e' -> '-L'"),
    ("test-flag", r"(?<=\[\[ )-f(?= )", "-e", "'-f' -> '-e'"),
    ("test-flag", r"(?<=\[\[ )-d(?= )", "-e", "'-d' -> '-e'"),
    ("test-flag", r"(?<=\[\[ )-z(?= )", "-n", "'-z' -> '-n'"),
    ("test-flag", r"(?<=\[\[ )-n(?= )", "-z", "'-n' -> '-z'"),
    ("negation", r"(?<=\[\[ )! ", "", "remove '!' in test"),
    ("negation", r"(?<=if )! ", "", "remove '!' after if"),
    ("compare", r"(?<= )==(?= )", "!=", "'==' -> '!='"),
    ("compare", r"(?<= )!=(?= )", "==", "'!=' -> '=='"),
    ("compare", r"(?<= )-eq(?= )", "-ne", "'-eq' -> '-ne'"),
    ("compare", r"(?<= )-ne(?= )", "-eq", "'-ne' -> '-eq'"),
    ("compare", r"(?<= )-gt(?= )", "-ge", "'-gt' -> '-ge'"),
    ("compare", r"(?<= )-ge(?= )", "-gt", "'-ge' -> '-gt'"),
    ("compare", r"(?<= )-lt(?= )", "-le", "'-lt' -> '-le'"),
    ("boolean", r"(?<= )&&(?= )", "||", "'&&' -> '||'"),
    ("boolean", r"(?<= )\|\|(?= )", "&&", "'||' -> '&&'"),
    ("return", r"\breturn 0\b", "return 1", "'return 0' -> 'return 1'"),
    ("return", r"\breturn 1\b", "return 0", "'return 1' -> 'return 0'"),
    ("loop", r"\bcontinue\b", "break", "'continue' -> 'break'"),
    ("loop", r"\bbreak\b", "continue", "'break' -> 'continue'"),
    ("dry-run", r"\brun (?=\S)", "", "drop 'run' wrapper"),
    ("dry-run", r"\$DRY_RUN\b", "true", "'$DRY_RUN' -> 'true'"),
    ("dry-run", r"\$DRY_RUN\b", "false", "'$DRY_RUN' -> 'false'"),
    ("glob", r'/"\*', '"*', "drop '/' before glob"),
    ("glob", r'(?<=")\*(?=\s*\]\])', "", "drop trailing glob '*'"),
    ("quoting", r'"(\$[A-Za-z_][A-Za-z0-9_]*|\$\{[A-Za-z_][A-Za-z0-9_]*\})"', r"\1",
     "unquote variable"),
    ("statement", r"^(\s*)(?:return\b.*)$", r"\1:", "delete return"),
    ("statement", r"^(\s*)(?:run |MANAGED_LINKS\+=|REMOVED_LINKS\+=|_backup_target |"
                  r"ensure_real_dir |mkdir |rm |mv |cp |ln ).*$",
     r"\1:", "delete command"),
]

SKIP_LINE = re.compile(r"^\s*(?:#|echo\b|printf\b)")


def _scopes(lines: list[str], functions: list[str] | None,
            ranges: list[dict] | None) -> list[tuple[str, int, int]]:
    """Return (name, first_body_line, last_body_line) as 0-based indexes."""
    scopes: list[tuple[str, int, int]] = []
    index = 0
    while index < len(lines):
        match = FUNCTION_START.match(lines[index])
        if match:
            name = match.group(1)
            end = index + 1
            while end < len(lines) and lines[end] != "}":
                end += 1
            if functions and name in functions:
                scopes.append((name, index + 1, end - 1))
            index = end
        index += 1
    for region in ranges or []:
        start_pattern = re.compile(region["start"])
        end_pattern = re.compile(region["end"])
        start = next(i for i, line in enumerate(lines) if start_pattern.search(line))
        end = next(i for i, line in enumerate(lines) if i > start and end_pattern.search(line))
        scopes.append((region["name"], start, end - 1))
    return scopes


def _valid(content: bytes) -> bool:
    result = subprocess.run(["bash", "-n"], input=content, capture_output=True)
    return result.returncode == 0


def enumerate_mutants(path: Path, relative: str, functions: list[str] | None = None,
                      ranges: list[dict] | None = None) -> list[Mutant]:
    text = path.read_text(encoding="utf-8")
    lines = text.split("\n")
    mutants: list[Mutant] = []
    seen: set[str] = set()
    for scope, first, last in _scopes(lines, functions, ranges):
        for index in range(first, last + 1):
            line = lines[index]
            if not line.strip() or SKIP_LINE.match(line):
                continue
            for operator, pattern, replacement, description in SUBSTITUTIONS:
                for match in re.finditer(pattern, line, flags=re.MULTILINE):
                    mutated_line = line[:match.start()] + match.expand(replacement) \
                        + line[match.end():]
                    if mutated_line == line:
                        continue
                    mutated = "\n".join([*lines[:index], mutated_line, *lines[index + 1:]])
                    if mutated in seen:
                        continue
                    content = mutated.encode("utf-8")
                    if not _valid(content):
                        continue
                    seen.add(mutated)
                    mutants.append(Mutant(
                        file=relative, function=scope, operator=operator,
                        line=index + 1, line_text=line, description=description,
                        content=content,
                        key=make_key(scope, operator, line, description),
                    ))
    return mutants
