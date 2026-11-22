"""Shared mutant record and stable survivor keys."""

from __future__ import annotations

from dataclasses import dataclass, field
import hashlib


@dataclass
class Mutant:
    file: str
    function: str
    operator: str
    line: int
    line_text: str
    description: str
    content: bytes = field(repr=False)
    key: str = ""


def make_key(function: str, operator: str, line_text: str, description: str) -> str:
    """Key a mutant by what it changes, not where, so edits elsewhere keep it."""
    digest = hashlib.sha1(line_text.strip().encode("utf-8")).hexdigest()[:10]
    return f"{function}|{operator}|{digest}|{description}"


def disambiguate(mutants: list[Mutant]) -> list[Mutant]:
    """Number repeated keys in source order (two identical edits on one line)."""
    counts: dict[str, int] = {}
    for mutant in mutants:
        counts[mutant.key] = counts.get(mutant.key, 0) + 1
        if counts[mutant.key] > 1:
            mutant.key = f"{mutant.key}#{counts[mutant.key]}"
    return mutants
