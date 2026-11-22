"""Enumerate source-preserving mutants of Python functions.

Each mutant replaces one byte span of the original file, so formatting and
line numbers outside the span stay intact and a survivor can be keyed by the
text of the line it changes rather than by its position.

Excluded on purpose:
- module-level code, decorators, annotations, and docstrings;
- f-strings, whose parts are not independently addressable;
- string arguments of exceptions raised with ``raise``, whose text is
  never part of a decision.
"""

from __future__ import annotations

import ast
from dataclasses import dataclass
from pathlib import Path

from mutants import Mutant, make_key

COMPARE_SWAPS = {
    ast.Eq: ("==", "!="),
    ast.NotEq: ("!=", "=="),
    ast.Lt: ("<", "<="),
    ast.LtE: ("<=", "<"),
    ast.Gt: (">", ">="),
    ast.GtE: (">=", ">"),
    ast.In: ("in", "not in"),
    ast.NotIn: ("not in", "in"),
    ast.Is: ("is", "is not"),
    ast.IsNot: ("is not", "is"),
}
COMPARE_TEXT = {kind: text for kind, (text, _) in COMPARE_SWAPS.items()}
METHOD_SWAPS = {
    "startswith": "endswith",
    "endswith": "startswith",
    "lstrip": "rstrip",
    "rstrip": "lstrip",
    "upper": "lower",
    "lower": "upper",
    "is_file": "is_dir",
    "is_dir": "is_file",
}
BINARY_SWAPS = {ast.Add: ("+", "-"), ast.Sub: ("-", "+")}


@dataclass
class _Source:
    data: bytes
    line_starts: list[int]

    @classmethod
    def read(cls, path: Path) -> "_Source":
        data = path.read_bytes()
        starts = [0]
        for index, byte in enumerate(data):
            if byte == 0x0A:
                starts.append(index + 1)
        return cls(data, starts)

    def span(self, node: ast.AST) -> tuple[int, int]:
        start = self.line_starts[node.lineno - 1] + node.col_offset
        end = self.line_starts[node.end_lineno - 1] + node.end_col_offset
        return start, end

    def text(self, node: ast.AST) -> str:
        start, end = self.span(node)
        return self.data[start:end].decode("utf-8")

    def line(self, lineno: int) -> str:
        start = self.line_starts[lineno - 1]
        end = self.line_starts[lineno] if lineno < len(self.line_starts) else len(self.data)
        return self.data[start:end].decode("utf-8").rstrip("\n")


def _wrap(text: str) -> str:
    return f"({text})"


class _Collector(ast.NodeVisitor):
    def __init__(self, source: _Source, path: str) -> None:
        self.source = source
        self.path = path
        self.scope: list[str] = []
        self.found: list[tuple[str, str, ast.AST, str, str]] = []
        self.skip: set[int] = set()

    # --- scope handling -------------------------------------------------

    def _visit_function(self, node: ast.FunctionDef | ast.AsyncFunctionDef) -> None:
        self.scope.append(node.name)
        for default in [*node.args.defaults, *node.args.kw_defaults]:
            if default is not None:
                self.visit(default)
        body = node.body
        if body and isinstance(body[0], ast.Expr) and isinstance(body[0].value, ast.Constant):
            if isinstance(body[0].value.value, str):
                body = body[1:]
        for statement in body:
            self.visit(statement)
        self.scope.pop()

    visit_FunctionDef = _visit_function
    visit_AsyncFunctionDef = _visit_function

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        self.scope.append(node.name)
        for statement in node.body:
            if isinstance(statement, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                self.visit(statement)
        self.scope.pop()

    def visit_Module(self, node: ast.Module) -> None:
        for statement in node.body:
            if isinstance(statement, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                self.visit(statement)

    def visit_AnnAssign(self, node: ast.AnnAssign) -> None:
        if node.value is not None:
            self.visit(node.value)

    def visit_JoinedStr(self, node: ast.JoinedStr) -> None:
        return

    def visit_Raise(self, node: ast.Raise) -> None:
        if isinstance(node.exc, ast.Call):
            for argument in node.exc.args:
                if isinstance(argument, ast.Constant) and isinstance(argument.value, str):
                    self.skip.add(id(argument))
        self.generic_visit(node)

    def visit_Lambda(self, node: ast.Lambda) -> None:
        self.visit(node.body)

    # --- helpers --------------------------------------------------------

    def _add(self, operator: str, node: ast.AST, replacement: str, description: str) -> None:
        if not self.scope:
            return
        self.found.append((".".join(self.scope), operator, node, replacement, description))

    # --- operators ------------------------------------------------------

    def visit_Compare(self, node: ast.Compare) -> None:
        parts = [node.left, *node.comparators]
        texts = [_wrap(self.source.text(part)) for part in parts]
        for index, operator in enumerate(node.ops):
            original, swapped = COMPARE_SWAPS[type(operator)]
            pieces = [texts[0]]
            for position, other in enumerate(node.ops):
                text = swapped if position == index else COMPARE_TEXT[type(other)]
                pieces.extend((text, texts[position + 1]))
            self._add("compare", node, " ".join(pieces), f"{original!r} -> {swapped!r}")
        self.generic_visit(node)

    def visit_BoolOp(self, node: ast.BoolOp) -> None:
        current, other = ("and", "or") if isinstance(node.op, ast.And) else ("or", "and")
        joined = f" {other} ".join(_wrap(self.source.text(value)) for value in node.values)
        self._add("boolean", node, _wrap(joined), f"{current!r} -> {other!r}")
        self.generic_visit(node)

    def visit_UnaryOp(self, node: ast.UnaryOp) -> None:
        if isinstance(node.op, ast.Not):
            self._add("not", node, _wrap(self.source.text(node.operand)), "remove 'not'")
        self.generic_visit(node)

    def visit_BinOp(self, node: ast.BinOp) -> None:
        swap = BINARY_SWAPS.get(type(node.op))
        if swap is not None:
            left = _wrap(self.source.text(node.left))
            right = _wrap(self.source.text(node.right))
            self._add("arithmetic", node, f"({left} {swap[1]} {right})",
                      f"{swap[0]!r} -> {swap[1]!r}")
        self.generic_visit(node)

    def visit_AugAssign(self, node: ast.AugAssign) -> None:
        swap = BINARY_SWAPS.get(type(node.op))
        if swap is not None:
            target = self.source.text(node.target)
            value = self.source.text(node.value)
            self._add("arithmetic", node, f"{target} {swap[1]}= {value}",
                      f"'{swap[0]}=' -> '{swap[1]}='")
        self.generic_visit(node)

    def visit_Constant(self, node: ast.Constant) -> None:
        if id(node) in self.skip:
            return
        value = node.value
        if isinstance(value, bool):
            self._add("constant", node, repr(not value), f"{value!r} -> {not value!r}")
        elif isinstance(value, int):
            self._add("constant", node, repr(value + 1), f"{value!r} -> {value + 1!r}")
            if value != 0:
                self._add("constant", node, repr(value - 1), f"{value!r} -> {value - 1!r}")
        elif isinstance(value, str):
            replacement = "XX" + value + "XX"
            self._add("string", node, repr(replacement), f"{value!r} -> {replacement!r}")

    def _collection(self, node: ast.Set | ast.List | ast.Tuple, kind: str) -> None:
        if isinstance(getattr(node, "ctx", ast.Load()), ast.Store):
            self.generic_visit(node)
            return
        elements = node.elts
        if any(isinstance(element, ast.Starred) for element in elements) or not elements:
            self.generic_visit(node)
            return
        for index, element in enumerate(elements):
            kept = [self.source.text(other) for position, other in enumerate(elements)
                    if position != index]
            if kind == "set":
                replacement = "{" + ", ".join(kept) + "}" if kept else "set()"
            elif kind == "list":
                replacement = "[" + ", ".join(kept) + "]"
            else:
                replacement = "(" + ", ".join(kept) + ("," if len(kept) == 1 else "") + ")"
            self._add("element", node, replacement,
                      f"drop element {self.source.text(element)!r}")
        self.generic_visit(node)

    def visit_Set(self, node: ast.Set) -> None:
        self._collection(node, "set")

    def visit_List(self, node: ast.List) -> None:
        self._collection(node, "list")

    def visit_Tuple(self, node: ast.Tuple) -> None:
        self._collection(node, "tuple")

    def visit_Return(self, node: ast.Return) -> None:
        value = node.value
        if value is not None and not (isinstance(value, ast.Constant) and value.value is None):
            self._add("return", node, "return None", "return None")
        self.generic_visit(node)

    def visit_Continue(self, node: ast.Continue) -> None:
        self._add("loop", node, "break", "'continue' -> 'break'")

    def visit_Break(self, node: ast.Break) -> None:
        self._add("loop", node, "continue", "'break' -> 'continue'")

    def visit_Attribute(self, node: ast.Attribute) -> None:
        swapped = METHOD_SWAPS.get(node.attr)
        if swapped is not None and isinstance(node.ctx, ast.Load):
            value = _wrap(self.source.text(node.value))
            self._add("method", node, f"{value}.{swapped}", f"'.{node.attr}' -> '.{swapped}'")
        self.generic_visit(node)

    def visit_Expr(self, node: ast.Expr) -> None:
        if isinstance(node.value, ast.Call):
            self._add("statement", node, "pass", "delete call statement")
        self.generic_visit(node)


def enumerate_mutants(path: Path, relative: str, functions: list[str] | None = None,
                      exclude: list[str] | None = None) -> list[Mutant]:
    source = _Source.read(path)
    tree = ast.parse(source.data, filename=relative)
    collector = _Collector(source, relative)
    collector.visit(tree)

    mutants: list[Mutant] = []
    seen: set[bytes] = set()
    for function, operator, node, replacement, description in collector.found:
        if functions and function.split(".")[0] not in functions:
            continue
        if exclude and function.split(".")[0] in exclude:
            continue
        start, end = source.span(node)
        mutated = source.data[:start] + replacement.encode("utf-8") + source.data[end:]
        if mutated in seen or mutated == source.data:
            continue
        try:
            compile(mutated, relative, "exec")
        except SyntaxError:
            continue
        seen.add(mutated)
        line = source.line(node.lineno)
        mutants.append(Mutant(
            file=relative,
            function=function,
            operator=operator,
            line=node.lineno,
            line_text=line,
            description=description,
            content=mutated,
            key=make_key(function, operator, line, description),
        ))
    return mutants
