"""Hypothesis strategies that render small shell programs with known leaves.

Each strategy produces a ``Rendered`` value: shell text plus, computed from
the generated structure rather than by parsing the text, the leaf commands
the text can run. The guard properties compare the guard's decision with a
decision computed from those labeled leaves, so the oracle never depends on
the parser under test.
"""

from __future__ import annotations

from dataclasses import dataclass
import re
import shlex

from hypothesis import strategies as st


@dataclass(frozen=True)
class Leaf:
    argv: tuple[str, ...]
    git: str = ""          # "block" or "safe" for git leaves
    gh: str = ""           # "deny", "ask" or "allow" for gh leaves
    checked: bool = False  # label confirmed by the real-Git table test


@dataclass(frozen=True)
class Rendered:
    text: str
    reachable: tuple[Leaf, ...]
    opaque: bool = False         # runs commands the guard cannot see
    heredoc: bool = False        # ends with a heredoc body; join with newlines
    executable: bool = True      # safe to run with stub git and gh


M = "msg"

GIT_BLOCK_CHECKED = [
    ("git", "commit", "--no-verify", "-m", M),
    ("git", "commit", "-m", M, "--no-verify"),
    ("git", "commit", "--message=msg", "--no-verify"),
    ("git", "commit", "--no-verif", "-m", M),
    ("git", "commit", "--no-veri", "-m", M),
    ("git", "commit", "-n", "-m", M),
    ("git", "commit", "-m", M, "-n"),
    ("git", "commit", "-nm", M),
    ("git", "commit", "-an", "-m", M),
    ("git", "commit", "-anm", M),
    ("git", "commit", "--no-gpg-sign", "-m", M),
    ("git", "-c", "commit.gpgsign=false", "commit", "-m", M),
    ("git", "-c", "commit.gpgSign=false", "commit", "-m", M),
    ("git", "-c", "commit.gpgsign=no", "commit", "-m", M),
    ("git", "-c", "commit.gpgsign=off", "commit", "-m", M),
    ("git", "-c", "commit.gpgsign=0", "commit", "-m", M),
    ("git", "-c", "commit.gpgsign=FALSE", "commit", "-m", M),
    ("git", "-c", "commit.gpgsign=", "commit", "-m", M),
    ("git", "-c", "core.hooksPath=/dev/null", "commit", "-m", M),
    ("git", "-c", "core.hookspath=nowhere", "commit", "-m", M),
    ("git", "-C", ".", "commit", "--no-verify", "-m", M),
    ("/usr/bin/git", "commit", "--no-verify", "-m", M),
]
GIT_BLOCK_UNCHECKED = [
    ("git", "merge", "--no-verify", "feature"),
    ("git", "merge", "-n", "feature"),
    ("git", "cherry-pick", "-n", "abc123"),
    ("git", "revert", "-n", "HEAD"),
    ("git", "am", "-n", "patch"),
    ("git", "push", "--no-verify"),
    ("git", "rebase", "--no-gpg-sign", "main"),
    ("git", "--namespace", "x", "commit", "-n", "-m", M),
]
GIT_SAFE_CHECKED = [
    ("git", "commit", "-m", M),
    ("git", "commit", "-m", "--no-verify"),
    ("git", "commit", "--message=--no-verify"),
    ("git", "commit", "-mn"),
    ("git", "commit", "--verify", "-m", M),
    ("git", "commit", "--no-verbose", "-m", M),
    ("git", "-c", "commit.gpgsign=true", "commit", "-m", M),
    ("git", "-c", "commit.gpgsign", "commit", "-m", M),
    ("git", "-c", "core.editor=true", "commit", "-m", M),
]
GIT_SAFE_UNCHECKED = [
    ("git", "status"),
    ("git", "log", "-n", "5"),
    ("git", "clean", "-n"),
    ("git", "push"),
    ("git", "log", "--no-merges"),
]
OTHER = [
    ("echo", "--no-verify"),
    ("printf", "%s\n", "git commit --no-verify"),
    ("printf", "%s", "$(git commit --no-verify)"),
    ("echo", "gh repo delete o/r"),
    ("true",),
]
GH = [
    (("gh", "repo", "delete", "o/r"), "deny"),
    (("gh", "-R", "o/r", "repo", "delete"), "deny"),
    (("gh", "auth", "logout"), "deny"),
    (("gh", "issue", "delete", "1"), "deny"),
    (("gh", "pr", "merge", "1"), "ask"),
    (("gh", "api", "-X", "POST", "x"), "ask"),
    (("gh", "api", "--method=delete", "x"), "ask"),
    (("gh", "secret", "set", "X"), "ask"),
    (("gh", "ruleset", "delete", "1"), "ask"),
    (("gh", "pr", "view", "1"), "allow"),
    (("gh", "issue", "list"), "allow"),
    (("gh", "api", "repos/o/r"), "allow"),
]

LEAVES = (
    [Leaf(argv, git="block", checked=True) for argv in GIT_BLOCK_CHECKED]
    + [Leaf(argv, git="block") for argv in GIT_BLOCK_UNCHECKED]
    + [Leaf(argv, git="safe", checked=True) for argv in GIT_SAFE_CHECKED]
    + [Leaf(argv, git="safe") for argv in GIT_SAFE_UNCHECKED]
    + [Leaf(argv) for argv in OTHER]
    + [Leaf(argv, gh=label) for argv, label in GH]
)

PLAIN = re.compile(r"^[A-Za-z0-9_./=:@%+-]+$")
DOUBLE_SAFE = re.compile(r'^[^"$`\\!]*$')

# --- words --------------------------------------------------------------


@st.composite
def word(draw, value: str) -> str:
    """Render one argument in a quoting style bash reads back as ``value``."""
    styles = ["single"]
    if PLAIN.match(value):
        styles += ["plain", "backslash", "split"]
    if DOUBLE_SAFE.match(value):
        styles.append("double")
    if value and "'" not in value:
        styles.append("ansi")
    style = draw(st.sampled_from(styles))
    if style == "plain":
        return value
    if style == "double":
        return f'"{value}"'
    if style == "backslash":
        return "".join("\\" + character if not character.isalnum() else character
                       for character in value)
    if style == "split" and len(value) > 1:
        cut = draw(st.integers(1, len(value) - 1))
        return value[:cut] + shlex.quote(value[cut:])
    if style == "ansi":
        escaped = "".join(f"\\x{ord(c):02x}" if c == "-" else
                          ("\\n" if c == "\n" else c) for c in value)
        return f"$'{escaped}'"
    return shlex.quote(value)


REDIRECTS = [">out", ">>out", "2>err", "2>&1", "</dev/null", ">/dev/null", "&>out", "2>>err"]


@st.composite
def leaf_text(draw, leaf: Leaf) -> str:
    words = [draw(word(argument)) for argument in leaf.argv]
    if draw(st.booleans()):
        position = draw(st.integers(0, len(words)))
        words.insert(position, draw(st.sampled_from(REDIRECTS)))
    separators = [draw(st.sampled_from([" ", " ", " ", " \\\n"])) for _ in words[1:]]
    text = words[0]
    for separator, item in zip(separators, words[1:]):
        text += separator + item
    return text


WRAPPERS = [
    ("A=1 ", True), ("A=1 B=2 ", True), ("env ", True), ("env -i PATH=$PATH ", True),
    ("env -u HOME ", True), ("env A=1 ", True), ("command ", True), ("command -p ", False),
    ("exec ", True), ("nice ", True), ("nice -n 5 ", True), ("nohup ", True),
    ("time ", True), ("time -p ", True), ("timeout 5 ", True), ("sudo ", False),
    ("sudo -u root ", False), ("doas ", False), ("setsid ", False),
]
PIPELINE_START_ONLY = {"! ", "time ", "time -p "}


@st.composite
def simple(draw) -> Rendered:
    leaf = draw(st.sampled_from(LEAVES))
    text = draw(leaf_text(leaf))
    executable = True
    for _ in range(draw(st.integers(0, 2))):
        prefix, safe = draw(st.sampled_from(WRAPPERS))
        text = prefix + text
        executable = executable and safe
    if draw(st.integers(0, 9)) == 0 and all(PLAIN.match(a) for a in leaf.argv):
        text = "env -S " + shlex.quote(" ".join(leaf.argv))
    if draw(st.integers(0, 5)) == 0:
        text = draw(st.sampled_from(sorted(PIPELINE_START_ONLY))) + text
    if leaf.argv[0].startswith("/"):
        executable = False
    return Rendered(text, (leaf,), executable=executable)


# --- composition ----------------------------------------------------------


def _delimiter(base: str, body: str, strips_tabs: bool) -> str:
    lines = {line.lstrip("\t") if strips_tabs else line for line in body.split("\n")}
    while base in lines or any(base in line for line in lines):
        base += "_"
    return base


def _combine(texts: list[Rendered], text: str, *, opaque=None, reachable=None,
             heredoc=False) -> Rendered:
    return Rendered(
        text,
        tuple(leaf for part in texts for leaf in part.reachable) if reachable is None
        else reachable,
        opaque=any(part.opaque for part in texts) if opaque is None else opaque,
        heredoc=heredoc,
        executable=all(part.executable for part in texts),
    )


def _end(part: Rendered) -> str:
    """Terminate a command so that a keyword can follow it."""
    return part.text + ("" if part.heredoc else ";")


@st.composite
def sequence(draw, children) -> Rendered:
    left, right = draw(children), draw(children)
    operator = draw(st.sampled_from(["&&", "||", ";", "|", "\n"]))
    if left.heredoc or operator == "\n":
        separator = "\n" if left.heredoc else "\n"
    else:
        separator = f" {operator} "
    if (operator == "|" and not left.heredoc
            and right.text.startswith(tuple(PIPELINE_START_ONLY))):
        separator = " ; "
    return _combine([left, right], left.text + separator + right.text, heredoc=right.heredoc)


GROUPS = [
    "( {x} )", "{{ {end} }}", "if {end} then :; fi", "if true; then {end} fi",
    "if false; then :; else {end} fi", "while false; do {end} done",
    "until true; do {end} done", "for i in 1; do {end} done",
    "case a in a) {end}\n;; esac", "f() {{ {end} }}; f",
]


@st.composite
def group(draw, children) -> Rendered:
    child = draw(children)
    template = draw(st.sampled_from(GROUPS))
    end = child.text + "\n" if child.heredoc else child.text + ";"
    if child.heredoc and template == "( {x} )":
        template = "( {end}\n)"
    text = template.format(x=child.text, end=end)
    return _combine([child], text)


NO_BACKTICK = re.compile(r"^[^`\\]*$")


@st.composite
def nested(draw, children) -> Rendered:
    child = draw(children)
    quoted = shlex.quote(child.text)
    forms = ["echo \"$({x})\"", "echo $({x})", "cat <({x})", "tee >({x}) >/dev/null",
             "bash -c {q}", "sh -c {q}", "bash -lc {q}", "bash -e -c {q}", "eval {q}",
             "bash <<< {q}"]
    if NO_BACKTICK.match(child.text) and "$(" not in child.text and "\n" not in child.text:
        forms.append("echo `{x}`")
    form = draw(st.sampled_from(forms))
    # "$((" would start arithmetic expansion; a space keeps a subshell a subshell.
    inner = (" " if child.text.startswith("(") else "") + child.text
    text = form.format(x=inner + ("\n" if child.heredoc else ""), q=quoted)
    return _combine([child], text)


@st.composite
def heredoc(draw, children) -> Rendered:
    child = draw(children)
    kind = draw(st.sampled_from(["literal", "expanding", "tabs", "shell", "shell-literal"]))
    noise = draw(st.sampled_from(["", "don't stop\n", "say \"hi\n", "a \\\n"]))
    if kind == "literal":
        body = noise + child.text
        quote = draw(st.sampled_from(["'{d}'", '"{d}"', "\\{d}"]))
        delimiter = _delimiter("EOF", body, False)
        text = f"cat <<{quote.format(d=delimiter)}\n{body}\n{delimiter}\n"
        return _combine([child], text, reachable=(), opaque=False, heredoc=True)
    if kind in ("expanding", "tabs"):
        if "`" in child.text or "\\" in child.text or "$" in child.text.replace("$(", ""):
            body = noise.replace("\\", "") + "plain text"
            reachable: tuple[Leaf, ...] = ()
            opaque = False
        else:
            spacer = " " if child.text.startswith("(") else ""
            body = noise.replace("\\", "") + f"$({spacer}{child.text})"
            reachable = child.reachable
            opaque = child.opaque
        strips = kind == "tabs"
        delimiter = _delimiter("END", body, strips)
        if strips:
            body = "\n".join("\t" + line for line in body.split("\n"))
            text = f"cat <<-{delimiter}\n{body}\n\t{delimiter}\n"
        else:
            text = f"cat <<{delimiter}\n{body}\n{delimiter}\n"
        result = _combine([child], text, reachable=reachable, opaque=opaque, heredoc=True)
        return result
    body = child.text
    delimiter = _delimiter("SCRIPT", body, False)
    quote = "'{d}'" if kind == "shell-literal" else "{d}"
    if kind == "shell" and ("$" in body or "`" in body or "\\" in body):
        quote = "'{d}'"
    text = f"bash <<{quote.format(d=delimiter)}\n{body}\n{delimiter}\n"
    return _combine([child], text, heredoc=True)


@st.composite
def piped_shell(draw, children) -> Rendered:
    child = draw(children)
    text = f"printf '%s\\n' {shlex.quote(child.text)} | bash"
    return _combine([child], text, reachable=(), opaque=True)


def programs(max_leaves: int = 5):
    return st.recursive(
        simple(),
        lambda children: st.one_of(
            sequence(children), group(children), nested(children), heredoc(children),
            piped_shell(children)),
        max_leaves=max_leaves,
    )


RANK = {None: 0, "allow": 1, "ask": 2, "deny": 3}


def expected_git_block(program: Rendered) -> bool:
    return program.opaque or any(leaf.git == "block" for leaf in program.reachable)


def expected_gh_rank(program: Rendered) -> int:
    if program.opaque:
        return RANK["ask"]
    return max([RANK[leaf.gh or None] for leaf in program.reachable] + [0])
