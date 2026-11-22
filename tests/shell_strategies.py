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


BASH_ONLY = ["$'", '$"', "&>", "<<<", "<(", ">(", "|&", "function ", "coproc"]
NO_BACKTICK = re.compile(r"^[^`\\]*$")


@st.composite
def nested(draw, children) -> Rendered:
    child = draw(children)
    quoted = shlex.quote(child.text)
    forms = ["echo \"$({x})\"", "echo $({x})", "echo $( {x})", "cat <({x})", "tee >({x}) >/dev/null",
             "bash -c {q}", "sh -c {q}", "bash -lc {q}", "bash -e -c {q}", "eval {q}",
             "bash <<< {q}"]
    if NO_BACKTICK.match(child.text) and "$(" not in child.text and "\n" not in child.text:
        forms.append("echo `{x}`")
    form = draw(st.sampled_from(forms))
    if form.startswith("sh ") and any(token in child.text for token in BASH_ONLY):
        form = "bash" + form[2:]  # sh may be dash, which lacks these
    # "$((" would start arithmetic expansion; a space keeps a subshell a subshell.
    inner = (" " if child.text.startswith("(") else "") + child.text
    text = form.format(x=inner + ("\n" if child.heredoc else ""), q=quoted)
    return _combine([child], text)


HEREDOC_TAILS = ["", " >/dev/null", "; :", ">/dev/null", "|cat", " && :", ";:"]


@st.composite
def _quoted_word(draw, base: str) -> tuple[str, str]:
    """A quoted heredoc word and the delimiter line it stands for."""
    a, b = base[:1], base[1:]
    return draw(st.sampled_from([
        (f"'{base}'", base), (f'"{base}"', base), ("\\" + base, base),
        (f"{a}'{b}'", base), (f'{a}"{b}"', base), (a + "\\" + b, base),
        (f"\"{a}'{b}\"", f"{a}'{b}"), (f"'{a}\"{b}'", f'{a}"{b}'),
        (f"{a}''{b}", base),
    ]))


@st.composite
def heredoc(draw, children) -> Rendered:
    child = draw(children)
    kind = draw(st.sampled_from(["literal", "expanding", "tabs", "shell", "shell-literal"]))
    noise = draw(st.sampled_from(["", "don't stop\n", "say \"hi\n", "a \\\n"]))
    if kind == "literal":
        body = noise + child.text
        word, delimiter = draw(_quoted_word(_delimiter("EOF", body, False)))
        if any(line == delimiter for line in body.split("\n")):
            word, delimiter = "'EOF_Q'", "EOF_Q"
        space = draw(st.sampled_from(["", " ", "\t"]))
        # A command may follow the operator on the same line, before the body.
        tail = draw(st.sampled_from(HEREDOC_TAILS))
        text = f"cat <<{space}{word}{tail}\n{body}\n{delimiter}\n"
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
        tail = draw(st.sampled_from(HEREDOC_TAILS))
        if strips:
            body = "\n".join("\t" + line for line in body.split("\n"))
            text = f"cat <<-{delimiter}{tail}\n{body}\n\t{delimiter}\n"
        else:
            text = f"cat <<{delimiter}{tail}\n{body}\n{delimiter}\n"
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


# --- lexical words ----------------------------------------------------------
#
# Each strategy returns (shell text, value bash produces). The values are
# checked against bash itself, so a wrong expectation fails loudly.

PLAIN_CHARACTERS = "abcXYZ019-_./=:@%+,"
BACKSLASH_TARGETS = "abc-_ ;&|()<>'\"$`\\*?[]{}#~!="
SINGLE_CHARACTERS = "ab -;&|()<>\"$`\\*?#~\t\n"
DOUBLE_CHARACTERS = "ab -;&|()<>'*?#~\t\n{}"
ANSI_PLAIN = "ab -;&|()<>\"$`*?#~0179aEf"
ANSI_SIMPLE = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "e": "\x1b",
               "E": "\x1b", "f": "\f", "v": "\v", "\\": "\\", "'": "'", '"': '"', "?": "?"}
ANSI_CODEPOINTS = [0x20, 0x2D, 0x41, 0x7E, 0xE9, 0x2014, 0x1F600]


@st.composite
def _ansi_part(draw) -> tuple[str, str]:
    kind = draw(st.sampled_from(["plain", "simple", "hex", "octal", "u", "U", "control",
                                 "unknown", "empty-hex"]))
    if kind == "empty-hex":
        letter = draw(st.sampled_from("xuU"))
        return "\\" + letter + "g", "\\" + letter + "g"
    if kind == "plain":
        character = draw(st.sampled_from(ANSI_PLAIN))
        return character, character
    if kind == "simple":
        key = draw(st.sampled_from(sorted(ANSI_SIMPLE)))
        return "\\" + key, ANSI_SIMPLE[key]
    if kind == "hex":
        value = draw(st.integers(0x01, 0x7F))
        if draw(st.booleans()) and value < 0x10:
            return f"\\x{value:x}g", chr(value) + "g"
        return f"\\x{value:02x}", chr(value)
    if kind == "octal":
        value = draw(st.integers(0o001, 0o177))
        if draw(st.booleans()) and value < 0o10:
            return f"\\{value:o}g", chr(value) + "g"
        return f"\\{value:03o}", chr(value)
    if kind == "u":
        value = draw(st.sampled_from([c for c in ANSI_CODEPOINTS if c <= 0xFFFF]))
        return f"\\u{value:04x}", chr(value)
    if kind == "U":
        value = draw(st.sampled_from(ANSI_CODEPOINTS))
        return f"\\U{value:08x}", chr(value)
    if kind == "control":
        letter = draw(st.sampled_from("abcz"))
        return "\\c" + letter, chr(ord(letter) & 0x1F)
    unknown = draw(st.sampled_from("qXz89"))
    return "\\" + unknown, "\\" + unknown


@st.composite
def _segment(draw) -> tuple[str, str]:
    kind = draw(st.sampled_from(["plain", "backslash", "continuation", "single", "double",
                                 "ansi", "locale"]))
    if kind == "plain":
        text = draw(st.text(PLAIN_CHARACTERS, min_size=1, max_size=4))
        return text, text
    if kind == "backslash":
        character = draw(st.sampled_from(BACKSLASH_TARGETS))
        return "\\" + character, character
    if kind == "continuation":
        return "\\\n", ""
    if kind == "single":
        text = draw(st.text(SINGLE_CHARACTERS, max_size=4))
        return f"'{text}'", text
    if kind in ("double", "locale"):
        parts = draw(st.lists(st.one_of(
            st.sampled_from(DOUBLE_CHARACTERS).map(lambda c: (c, c)),
            st.sampled_from(['"', "\\", "$", "`"]).map(lambda c: ("\\" + c, c)),
            st.just(("\\a", "\\a")),
            st.just(("\\\n", "")),
        ), max_size=4))
        prefix = "$" if kind == "locale" else ""
        return prefix + '"' + "".join(t for t, _ in parts) + '"', "".join(v for _, v in parts)
    parts = draw(st.lists(_ansi_part(), max_size=4))
    return "$'" + "".join(t for t, _ in parts) + "'", "".join(v for _, v in parts)


@st.composite
def shell_words(draw) -> tuple[str, list[str]]:
    """Words joined by blanks; the first segment of a word is never a '#'."""
    texts, values = [], []
    for _ in range(draw(st.integers(1, 5))):
        segments = draw(st.lists(_segment(), min_size=1, max_size=4))
        text = "".join(t for t, _ in segments)
        if text.replace("\\\n", "") == "":
            text, segments = "''", [("''", "")]
        texts.append(text)
        values.append("".join(v for _, v in segments))
    separators = [draw(st.sampled_from([" ", "\t", "  "])) for _ in texts]
    return "".join(s + t for s, t in zip(separators, texts)), values
