#!/usr/bin/env python3
"""Apply Git and GitHub CLI policy to shell command strings."""

from __future__ import annotations

import json
import os
import re
import shlex
import sys
from dataclasses import dataclass


CONTROL_OPERATORS = {"&", "&&", "(", ")", ";", ";;", ";&", ";;&", "|", "|&", "||"}
PIPE_OPERATORS = {"|", "|&"}
REDIRECT_OPERATORS = {"<", "<<", "<<<", ">", ">>", "<>", ">&", "<&", "&>", "&>>", ">|"}
STDIN_REDIRECTS = {"<", "<&", "<>"}
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(?:\[[^]]*\])?\+?=")
NESTED_SHELLS = {"bash", "dash", "ksh", "sh", "zsh"}
GUARDED_EXECUTABLES = {"gh", "git"}
# Reserved words that may precede a command in the same segment.
RESERVED_PREFIXES = {"!", "{", "}", "do", "done", "elif", "else", "esac", "fi", "if",
                     "then", "until", "while", "[[", "]]"}
# Segments starting with these words are loop or case headers, not commands.
HEADER_WORDS = {"case", "for", "select"}
# Commands that run their arguments as another command, with the options that
# take a separate value.
TRANSPARENT_WRAPPERS = {
    "builtin": set(),
    "command": set(),
    "doas": {"-C", "-u"},
    "exec": {"-a"},
    "ionice": {"-c", "-n", "-p", "-P", "-u", "--class", "--classdata"},
    "nice": {"-n", "--adjustment"},
    "nohup": set(),
    "setsid": set(),
    "stdbuf": {"-e", "-i", "-o", "--error", "--input", "--output"},
    "sudo": {"-C", "-D", "-g", "-h", "-p", "-R", "-r", "-T", "-t", "-U", "-u",
             "--chdir", "--chroot", "--close-from", "--group", "--host", "--other-user",
             "--prompt", "--role", "--type", "--user"},
    "time": {"-f", "-o", "--format", "--output"},
}
# Wrappers whose first operand (a duration) precedes the command.
DURATION_WRAPPERS = {"timeout": {"-k", "-s", "--kill-after", "--signal"}}
# Commands that run other commands in ways this parser does not follow.
OPAQUE_RUNNERS = {"find", "parallel", "watch", "xargs"}
MAX_DEPTH = 50
ANSI_ESCAPES = {"a": "\a", "b": "\b", "e": "\x1b", "E": "\x1b", "f": "\f", "n": "\n",
                "r": "\r", "t": "\t", "v": "\v", "\\": "\\", "'": "'", '"': '"', "?": "?"}


@dataclass(frozen=True)
class ShellCommand:
    executable: str
    arguments: tuple[str, ...]


@dataclass(frozen=True)
class Heredoc:
    delimiter: str
    strips_tabs: bool
    expands: bool


class ShellParseError(ValueError):
    """Raised when a command cannot be analyzed safely."""


OPERATORS = sorted({*CONTROL_OPERATORS, *REDIRECT_OPERATORS}, key=len, reverse=True)
PUNCTUATION = set(";&|()<>")
DOUBLE_QUOTE_ESCAPES = set('$`"\\\n')


class Operator(str):
    """An unquoted shell operator, distinct from a quoted word with the same text."""


def _is_operator(token: str, operators: set[str]) -> bool:
    return isinstance(token, Operator) and token in operators


def _tokens(text: str) -> list[str]:
    """Split shell text into words and operators, removing quotes.

    Unquoted runs of ``;&|()<>`` become ``Operator`` tokens; quoted
    punctuation stays part of a word. ``#`` is not a comment character, so
    text after it is still inspected.
    """
    tokens: list[str] = []
    word: list[str] = []
    in_word = False
    index = 0

    def finish() -> None:
        nonlocal in_word
        if in_word:
            tokens.append("".join(word))
            word.clear()
            in_word = False

    while index < len(text):
        character = text[index]
        if character in " \t\n":
            finish()
            index += 1
        elif character == "\\":
            # A trailing backslash is literal, as in bash.
            word.append(text[index + 1] if index + 1 < len(text) else "\\")
            in_word = True
            index += 2
        elif character == "'":
            end = text.find("'", index + 1)
            if end == -1:
                raise ShellParseError("No closing quotation")
            word.append(text[index + 1:end])
            in_word = True
            index = end + 1
        elif character == '"':
            index += 1
            in_word = True
            while True:
                if index >= len(text):
                    raise ShellParseError("No closing quotation")
                character = text[index]
                if character == '"':
                    index += 1
                    break
                if character == "\\" and index + 1 < len(text) \
                        and text[index + 1] in DOUBLE_QUOTE_ESCAPES:
                    word.append(text[index + 1])
                    index += 2
                    continue
                word.append(character)
                index += 1
        elif character in PUNCTUATION:
            finish()
            operator = next(op for op in [*OPERATORS, character]
                            if text.startswith(op, index))
            tokens.append(Operator(operator))
            index += len(operator)
        else:
            word.append(character)
            in_word = True
            index += 1
    finish()
    return tokens


# --- lexical preparation ------------------------------------------------------


def _decode_ansi_c(text: str, start: int) -> tuple[str, int]:
    """Decode a $'...' word whose opening quote is at ``start``."""
    result: list[str] = []
    index = start + 1
    while index < len(text):
        character = text[index]
        if character == "'":
            return "".join(result), index + 1
        if character != "\\" or index + 1 >= len(text):
            result.append(character)
            index += 1
            continue
        escape = text[index + 1]
        index += 2
        if escape in ANSI_ESCAPES:
            result.append(ANSI_ESCAPES[escape])
        elif escape in "01234567":
            digits = escape
            while len(digits) < 3 and index < len(text) and text[index] in "01234567":
                digits += text[index]
                index += 1
            result.append(chr(int(digits, 8)))
        elif escape in "xuU":
            limit = {"x": 2, "u": 4, "U": 8}[escape]
            digits = ""
            while (len(digits) < limit and index < len(text)
                   and text[index] in "0123456789abcdefABCDEF"):
                digits += text[index]
                index += 1
            result.append(chr(int(digits, 16)) if digits else "\\" + escape)
        elif escape == "c" and index < len(text):
            result.append(chr(ord(text[index]) & 0x1F))
            index += 1
        else:
            result.append("\\" + escape)
    raise ShellParseError("Unclosed ANSI-C quote")


def _keyword_at(text: str, index: int, keyword: str) -> bool:
    """Whether ``keyword`` is a whole word at ``index``; callers check position."""
    end = index + len(keyword)
    return text.startswith(keyword, index) and (end == len(text) or text[end] in " \t\n;&|()")


def _starts_command(text: str, index: int) -> bool:
    """Whether the character at ``index`` ends one command and starts another.

    Operators always do; braces do only as standalone words, so ``${x}`` does
    not.
    """
    character = text[index]
    if character in ";&|()\n":
        return True
    if character not in "{}":
        return False
    before = text[index - 1] if index else " "
    after = text[index + 1] if index + 1 < len(text) else " "
    return before in " \t\n;&|()" and after in " \t\n;&|()"


def _skip_arithmetic(text: str, index: int) -> int:
    """Return the index after a $((...)) or ((...)) starting at ``index``."""
    depth = 0
    while index < len(text):
        if text[index] == "(":
            depth += 1
        elif text[index] == ")":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return index


def _read_heredoc_word(line: str, start_index: int) -> tuple[str, bool, int]:
    delimiter: list[str] = []
    is_quoted = False
    quote = ""
    index = start_index

    while index < len(line) and line[index] in {" ", "\t"}:
        index += 1
    while index < len(line):
        character = line[index]
        if not quote and (character.isspace() or character in ";&|()<>"):
            break
        if character == "\\" and quote != "'":
            is_quoted = True
            index += 1
            if index < len(line):
                delimiter.append(line[index])
                index += 1
            continue
        if character == "'" and quote != '"':
            is_quoted = True
            quote = "" if quote == "'" else "'"
            index += 1
            continue
        if character == '"' and quote != "'":
            is_quoted = True
            quote = "" if quote == '"' else '"'
            index += 1
            continue
        delimiter.append(character)
        index += 1

    if quote:
        raise ShellParseError("Unclosed quote in heredoc delimiter")
    if not delimiter and not is_quoted:
        raise ShellParseError("Missing heredoc delimiter")
    return "".join(delimiter), not is_quoted, index


def _feeds_shell(prefix: str) -> bool:
    """Whether the command text before a heredoc operator is a nested shell.

    A prefix that cannot be read raises ShellParseError, as its segment would.
    """
    words = _command_words(_without_redirects(_tokens(prefix)), [])
    return bool(words) and os.path.basename(words[0]) in NESTED_SHELLS


@dataclass
class _Frame:
    """One quoting context: the top level, a $(...) or a backtick span."""

    kind: str
    quote: str = ""
    depth: int = 0
    command_start: int = 0
    cases: int = 0


@dataclass
class _Prepared:
    text: str
    expanding_bodies: list[str]
    shell_bodies: list[str]


def _prepare(text: str, body: bool = False) -> _Prepared:
    """Join continuations, decode $'...', drop fd numbers, and lift heredocs.

    One pass tracks quoting per substitution context and pending heredocs
    together, so a quote inside a heredoc body or inside a substitution cannot
    change how the surrounding text is read. With ``body``, the text is an
    expanding heredoc body: quotes are literal and only substitutions count.
    """
    output: list[str] = []
    frames = [_Frame("top", quote="H" if body else "")]
    pending: list[tuple[Heredoc, bool]] = []
    expanding: list[str] = []
    shell_bodies: list[str] = []
    index = 0

    def push(kind: str, opener: str) -> None:
        if len(frames) > MAX_DEPTH:
            raise ShellParseError("Command nesting is too deep")
        output.append(opener)
        frames.append(_Frame(kind, command_start=len(output)))

    while index < len(text):
        frame = frames[-1]
        character = text[index]
        next_character = text[index + 1] if index + 1 < len(text) else ""

        if character == "\\" and frame.quote != "'":
            if next_character == "\n":
                index += 2
                continue
            output.extend((character, next_character))
            index += 2
            continue
        if frame.quote == "'":
            if character == "'":
                frame.quote = ""
            output.append(character)
            index += 1
            continue
        if frame.quote in {'"', "H"}:
            if character == '"' and frame.quote == '"':
                frame.quote = ""
            elif character == "$" and next_character == "(" and not text.startswith("$((", index):
                push("paren", "$(")
                index += 2
                continue
            elif character == "`":
                push("tick", "`")
                index += 1
                continue
            output.append(character)
            index += 1
            continue

        word_start = not output or output[-1][-1:] in {" ", "\t", "\n", ";", "&", "|",
                                                       "(", ")", "<", ">"}
        if character == "$" and next_character == "'":
            decoded, index = _decode_ansi_c(text, index + 1)
            output.append(shlex.quote(decoded))
            continue
        if character == "$" and next_character == '"':
            index += 1
            continue
        if character.isdigit() and word_start:
            end = index
            while end < len(text) and text[end].isdigit():
                end += 1
            if end < len(text) and text[end] in "<>":
                # Keep a blank so "&2>" cannot become the "&>" operator.
                output.append(" ")
                index = end
                continue
        if character in {"'", '"'}:
            frame.quote = character
            output.append(character)
            index += 1
            continue
        if text.startswith("$((", index) or (text.startswith("((", index) and word_start):
            end = _skip_arithmetic(text, index + (1 if character == "$" else 0))
            output.append(text[index:end])
            index = end
            continue
        if (character == "$" or character in "<>") and next_character == "(":
            push("paren", character + "(")
            index += 2
            continue
        if character == "`":
            if frame.kind == "tick":
                frames.pop()
                output.append(character)
            else:
                push("tick", character)
            index += 1
            continue
        at_command = not "".join(output[frame.command_start:]).strip()
        if frame.kind == "paren" and at_command and _keyword_at(text, index, "case"):
            frame.cases += 1
        elif frame.kind == "paren" and at_command and _keyword_at(text, index, "esac"):
            frame.cases = max(0, frame.cases - 1)
        if frame.kind == "paren" and character == "(":
            frame.depth += 1
        elif frame.kind == "paren" and character == ")":
            if frame.depth == 0 and frame.cases:
                output.append(character)
                index += 1
                frame.command_start = len(output)
                continue
            if frame.depth == 0:
                frames.pop()
                output.append(character)
                index += 1
                continue
            frame.depth -= 1
        if text.startswith("<<<", index):
            output.append("<<<")
            index += 3
            continue
        if text.startswith("<<", index):
            strips_tabs = text.startswith("<<-", index)
            delimiter, expands, end = _read_heredoc_word(
                text, index + (3 if strips_tabs else 2))
            feeds = _feeds_shell("".join(output[frame.command_start:]))
            pending.append((Heredoc(delimiter, strips_tabs, expands), feeds))
            # The body is lifted here; leave an empty here-string so nested
            # parsing of this text cannot claim the following lines again.
            output.append("<<< ''")
            index = end
            continue
        if _starts_command(text, index):
            frame.command_start = len(output) + 1
        if character == "\n":
            output.append(character)
            index += 1
            frame.command_start = len(output)
            for heredoc, feeds in pending:
                body: list[str] = []
                while index < len(text):
                    end = text.find("\n", index)
                    end = len(text) if end == -1 else end
                    line = text[index:end]
                    index = end + 1
                    if heredoc.strips_tabs:
                        line = line.lstrip("\t")
                    if line == heredoc.delimiter:
                        break
                    body.append(line)
                body_text = "\n".join(body)
                if feeds:
                    shell_bodies.append(body_text)
                if heredoc.expands:
                    expanding.append(body_text)
            pending = []
            continue

        output.append(character)
        index += 1

    return _Prepared("".join(output), expanding, shell_bodies)


def _find_closing_backtick(text: str, opening_index: int) -> int:
    index = opening_index + 1
    while index < len(text):
        if text[index] == "\\" and index + 1 < len(text):
            index += 2
            continue
        if text[index] == "`":
            return index
        index += 1
    raise ShellParseError("Unclosed backtick substitution")


def _find_closing_parenthesis(text: str, opening_index: int) -> int:
    depth = 1
    cases = {1: 0}  # open case statements per parenthesis depth
    quote = ""
    index = opening_index + 1
    command_start = index

    while index < len(text):
        character = text[index]
        if character == "\\" and quote != "'" and index + 1 < len(text):
            index += 2
            continue
        if character == "`" and quote != "'":
            index = _find_closing_backtick(text, index) + 1
            continue
        if character == "'" and quote != '"':
            quote = "" if quote == "'" else "'"
        elif character == '"' and quote != "'":
            quote = "" if quote == '"' else '"'
        elif (not quote and not text[command_start:index].strip()
              and _keyword_at(text, index, "case")):
            cases[depth] += 1
        elif (not quote and not text[command_start:index].strip()
              and _keyword_at(text, index, "esac")):
            cases[depth] = max(0, cases[depth] - 1)
        elif not quote and character == "(":
            depth += 1
            cases[depth] = 0
        elif not quote and character == ")":
            if cases[depth]:
                index += 1
                command_start = index
                continue
            depth -= 1
            if depth == 0:
                return index
        if not quote and _starts_command(text, index):
            command_start = index + 1
        index += 1

    raise ShellParseError("Unclosed parenthesized substitution")


def _extract_nested_commands(text: str, body: bool = False) -> tuple[str, list[str]]:
    outer_text: list[str] = []
    nested_commands: list[str] = []
    quote = "H" if body else ""
    index = 0

    while index < len(text):
        character = text[index]
        next_character = text[index + 1] if index + 1 < len(text) else ""
        if character == "\\" and next_character and quote != "'":
            outer_text.extend((character, next_character))
            index += 2
            continue
        if character == "'" and quote not in {'"', "H"}:
            quote = "" if quote == "'" else "'"
            outer_text.append(character)
            index += 1
            continue
        if character == '"' and quote not in {"'", "H"}:
            quote = "" if quote == '"' else '"'
            outer_text.append(character)
            index += 1
            continue
        if character == "`" and quote != "'":
            closing_index = _find_closing_backtick(text, index)
            nested_commands.append(text[index + 1 : closing_index])
            outer_text.append("nested-command")
            index = closing_index + 1
            continue

        if quote != "'" and text.startswith("$((", index):
            # Arithmetic: not a command, but it may contain substitutions.
            end = _skip_arithmetic(text, index + 1)
            nested_commands.extend(_extract_nested_commands(text[index + 3 : end - 2])[1])
            outer_text.append("0")
            index = end
            continue
        opens_command = quote != "'" and character == "$" and next_character == "("
        opens_process = not quote and character in {"<", ">"} and next_character == "("
        if opens_command or opens_process:
            closing_index = _find_closing_parenthesis(text, index + 1)
            nested_commands.append(text[index + 2 : closing_index])
            outer_text.append("nested-command")
            index = closing_index + 1
            continue

        outer_text.append(character)
        index += 1

    return "".join(outer_text), nested_commands


def _delimit_unquoted_newlines(text: str) -> str:
    result: list[str] = []
    quote = ""
    escaped = False

    for character in text:
        if escaped:
            result.append(character)
            escaped = False
            continue
        if character == "\\" and quote != "'":
            result.append(character)
            escaped = True
            continue
        if character in {"'", '"'}:
            if not quote:
                quote = character
            elif quote == character:
                quote = ""
            result.append(character)
            continue
        result.append(";" if character == "\n" and not quote else character)

    return "".join(result)


# --- command words --------------------------------------------------------------


def _without_redirects(tokens: list[str]) -> list[str]:
    result: list[str] = []
    skip_target = False
    for token in tokens:
        if skip_target:
            skip_target = False
            continue
        if _is_operator(token, REDIRECT_OPERATORS):
            skip_target = True
            continue
        result.append(token)
    return result


def _skip_options(tokens: list[str], value_options: set[str]) -> list[str]:
    """Drop leading options of a wrapper, including ones that take a value."""
    while tokens and tokens[0].startswith("-") and tokens[0] != "-":
        option = tokens.pop(0)
        if option == "--":
            break
        if option in value_options and tokens:
            tokens.pop(0)
    return tokens


def _command_words(tokens: list[str], nested_texts: list[str]) -> list[str]:
    """Strip keywords, assignments and wrappers to reach the executed words.

    ``env -S`` text is appended to ``nested_texts`` for separate parsing.
    """
    tokens = list(tokens)
    while tokens:
        first = tokens[0]
        name = os.path.basename(first)
        if first in RESERVED_PREFIXES:
            tokens.pop(0)
        elif first in HEADER_WORDS:
            return []
        elif first == "function":
            del tokens[:2]
            while tokens and _is_operator(tokens[0], {"(", ")"}):
                tokens.pop(0)
        elif first == "coproc":
            tokens.pop(0)
            if len(tokens) > 1 and tokens[1] == "{":
                tokens.pop(0)
        elif ASSIGNMENT.match(first):
            tokens.pop(0)
        elif name == "env":
            tokens.pop(0)
            while tokens:
                token = tokens[0]
                if ASSIGNMENT.match(token):
                    tokens.pop(0)
                elif token in {"-S", "--split-string"}:
                    if len(tokens) > 1:
                        nested_texts.append(tokens[1])
                    return []
                elif token.startswith("--split-string="):
                    nested_texts.append(token.split("=", 1)[1])
                    return []
                elif token.startswith("-S") and len(token) > 2:
                    nested_texts.append(token[2:])
                    return []
                elif token in {"-u", "--unset", "-C", "--chdir"}:
                    del tokens[:2]
                elif token == "--":
                    tokens.pop(0)
                    break
                elif token.startswith("-"):
                    tokens.pop(0)
                else:
                    break
        elif name in TRANSPARENT_WRAPPERS:
            tokens.pop(0)
            if name == "nice" and tokens and re.fullmatch(r"-[0-9]+", tokens[0]):
                tokens.pop(0)
            tokens = _skip_options(tokens, TRANSPARENT_WRAPPERS[name])
        elif name in DURATION_WRAPPERS:
            tokens.pop(0)
            tokens = _skip_options(tokens, DURATION_WRAPPERS[name])
            if tokens:
                tokens.pop(0)
        elif name in OPAQUE_RUNNERS:
            invoked = {os.path.basename(token) for token in tokens[1:]}
            if invoked & (GUARDED_EXECUTABLES | NESTED_SHELLS | {"eval"}):
                raise ShellParseError(f"Cannot follow commands run by {name}")
            return tokens
        else:
            return tokens
    return tokens


def _here_string(tokens: list[str]) -> str | None:
    for index, token in enumerate(tokens[:-1]):
        if _is_operator(token, {"<<<"}):
            return tokens[index + 1]
    return None


def _nested_shell_text(command: ShellCommand) -> str | None:
    if command.executable == "eval":
        return " ".join(command.arguments) or None
    if command.executable not in NESTED_SHELLS:
        return None

    for index, argument in enumerate(command.arguments[:-1]):
        is_command_option = argument == "-c" or (
            argument.startswith("-") and not argument.startswith("--") and "c" in argument[1:]
        )
        if is_command_option:
            return command.arguments[index + 1]
    return None


def _reads_script_from_stdin(command: ShellCommand) -> bool:
    """A nested shell without -c or a script operand runs whatever stdin holds."""
    if command.executable not in NESTED_SHELLS:
        return False
    for argument in command.arguments:
        if argument == "-s":
            return True
        if argument == "-c" or (argument.startswith("-") and not argument.startswith("--")
                                and "c" in argument[1:]):
            return False
        if not argument.startswith(("-", "+")):
            return False
    return True


def _body_substitutions(body: str) -> list[str]:
    """Return the command substitutions an expanding heredoc body runs."""
    prepared = _prepare(body, body=True)
    nested = _extract_nested_commands(prepared.text, body=True)[1]
    for inner in prepared.expanding_bodies:
        nested.extend(_body_substitutions(inner))
    return [*nested, *prepared.shell_bodies]


def shell_commands(text: str, _depth: int = 0) -> list[ShellCommand]:
    if _depth > MAX_DEPTH:
        raise ShellParseError("Command nesting is too deep")
    prepared = _prepare(text)
    outer_text, nested_texts = _extract_nested_commands(prepared.text)
    for body in prepared.expanding_bodies:
        nested_texts.extend(_body_substitutions(body))
    nested_texts.extend(prepared.shell_bodies)
    tokens = _tokens(_delimit_unquoted_newlines(outer_text))

    commands: list[ShellCommand] = []
    segment: list[str] = []
    previous_operator = ""
    for token in [*tokens, Operator(";")]:
        if not _is_operator(token, CONTROL_OPERATORS):
            segment.append(token)
            continue
        words = _command_words(_without_redirects(segment), nested_texts)
        if words:
            command = ShellCommand(os.path.basename(words[0]), tuple(words[1:]))
            commands.append(command)
            here_string = _here_string(segment)
            if command.executable in NESTED_SHELLS and here_string is not None:
                nested_texts.append(here_string)
            elif _reads_script_from_stdin(command) and not any(
                    _is_operator(item, {"<<", "<<<"}) for item in segment) and (
                    previous_operator in PIPE_OPERATORS
                    or any(_is_operator(item, STDIN_REDIRECTS) for item in segment)):
                raise ShellParseError("Cannot inspect a script piped into a shell")
        segment = []
        previous_operator = token

    nested_texts.extend(
        nested_text for command in commands if (nested_text := _nested_shell_text(command))
    )
    for nested_text in nested_texts:
        commands.extend(shell_commands(nested_text, _depth + 1))
    return commands


# --- git policy -----------------------------------------------------------------

GIT_GLOBAL_VALUE_OPTIONS = {"-c", "-C", "--attr-source", "--config-env", "--git-dir",
                            "--namespace", "--super-prefix", "--work-tree"}
SHORT_NO_VERIFY = {"am", "cherry-pick", "commit", "merge", "revert"}
# Short options that take the rest of a combined cluster (or the next word) as
# their value, so letters after them are not options.
SHORT_VALUE_OPTIONS = {
    "am": set("CSp"),
    "cherry-pick": set("SXm"),
    "commit": set("CFSXcmtu"),
    "merge": set("FSXms"),
    "revert": set("SXm"),
}
GIT_TRUE = {"true", "yes", "on"}


def _git_invocation(command: ShellCommand) -> tuple[str, list[str], list[str]] | None:
    """Return the subcommand, its arguments and the -c/--config-env entries."""
    if command.executable != "git":
        return None

    arguments = list(command.arguments)
    configs: list[str] = []
    while arguments and arguments[0].startswith("-"):
        option = arguments.pop(0)
        if option.startswith("--config-env="):
            configs.append("env:" + option.split("=", 1)[1])
        elif option in GIT_GLOBAL_VALUE_OPTIONS and arguments:
            value = arguments.pop(0)
            if option == "-c":
                configs.append(value)
            elif option == "--config-env":
                configs.append("env:" + value)
    if not arguments:
        return None
    return arguments.pop(0), arguments, configs


def _option_tokens(arguments: list[str]) -> list[str]:
    value_options = {"-F", "--file", "-m", "--message"}
    options: list[str] = []
    index = 0
    while index < len(arguments):
        token = arguments[index]
        if token == "--":
            break
        if token in value_options:
            index += 2
            continue
        if token.startswith(("--file=", "--message=")) or (
            token.startswith(("-F", "-m")) and len(token) > 2
        ):
            index += 1
            continue
        options.append(token)
        index += 1
    return options


def _git_bool_is_false(value: str) -> bool:
    """Treat every value Git does not certainly read as true as false."""
    normalized = value.strip().lower()
    if normalized in GIT_TRUE:
        return False
    match = re.fullmatch(r"([-+]?(?:0x[0-9a-f]+|[0-9]+))([kmg]?)", normalized)
    if match:
        try:
            return int(match.group(1), 0) == 0
        except ValueError:
            return True
    return True


def _config_blocked(entry: str) -> bool:
    from_environment = entry.startswith("env:")
    entry = entry.removeprefix("env:")
    key, has_value, value = entry.partition("=")
    key = key.lower()
    if key == "core.hookspath":
        return True
    if key == "commit.gpgsign":
        return from_environment or (bool(has_value) and _git_bool_is_false(value))
    return False


def _is_long_prefix(token: str, option: str, minimum: str) -> bool:
    name = token.split("=", 1)[0]
    return name.startswith(minimum) and option.startswith(name)


def _short_cluster_has(token: str, letter: str, value_letters: set[str]) -> bool:
    for character in token[1:]:
        if character == letter:
            return True
        if character in value_letters:
            return False
    return False


def git_bypass_blocked(commands: list[ShellCommand]) -> bool:
    for command in commands:
        invocation = _git_invocation(command)
        if invocation is None:
            continue
        subcommand, arguments, configs = invocation
        if any(_config_blocked(entry) for entry in configs):
            return True
        for token in _option_tokens(arguments):
            if token.startswith("--"):
                if (_is_long_prefix(token, "--no-verify", "--no-v")
                        or _is_long_prefix(token, "--no-gpg-sign", "--no-g")):
                    return True
            elif token.startswith("-") and subcommand in SHORT_NO_VERIFY:
                if _short_cluster_has(token, "n", SHORT_VALUE_OPTIONS[subcommand]):
                    return True
    return False


# --- gh policy ------------------------------------------------------------------


def _gh_invocation(command: ShellCommand) -> tuple[str, str, list[str]] | None:
    if command.executable != "gh":
        return None

    arguments = list(command.arguments)
    global_value_options = {"--hostname", "--repo", "-R"}
    while arguments and arguments[0].startswith("-"):
        option = arguments.pop(0)
        if option in global_value_options and arguments:
            arguments.pop(0)
    if not arguments:
        return None

    group = arguments.pop(0)
    action = ""
    action_value_options = {"--hostname", "--repo", "-R"}
    index = 0
    while index < len(arguments):
        token = arguments[index]
        if token in action_value_options:
            index += 2
            continue
        if token.startswith("-"):
            index += 1
            continue
        action = token
        break
    return group, action, arguments


def _mutating_api(arguments: list[str]) -> bool:
    mutating_methods = {"DELETE", "PATCH", "POST", "PUT"}
    mutation_flags = {"--field", "--input", "--raw-field", "-F", "-f"}
    for index, token in enumerate(arguments):
        if token in mutation_flags or token.startswith(
            ("--field=", "--input=", "--raw-field=", "-F=", "-f=")
        ):
            return True
        if token in {"--method", "-X"} and index + 1 < len(arguments):
            if arguments[index + 1].upper() in mutating_methods:
                return True
        if token.startswith("--method=") and token.split("=", 1)[1].upper() in mutating_methods:
            return True
        if token.startswith("-X") and token[2:].upper() in mutating_methods:
            return True
    return False


def _classify_gh(group: str, action: str, arguments: list[str]) -> tuple[str, str]:
    if group == "repo" and action in {"archive", "change-visibility", "delete", "rename"}:
        return "deny", "Destructive repo operation blocked."
    if group in {"auth", "gpg-key", "ssh-key"}:
        return "deny", "Credential operation blocked."
    if group == "config" and action == "set":
        return "deny", "Config change blocked."
    if group == "extension" and action in {"install", "remove"}:
        return "deny", "Extension management blocked."
    if group == "codespace":
        return "deny", "Codespace operation blocked."
    if group == "issue" and action == "delete":
        return "deny", "Issue deletion blocked."

    if group == "pr" and action == "merge":
        return "ask", "PR merge — confirm."
    if group == "pr" and action in {"close", "comment", "create", "edit", "ready", "review"}:
        return "allow", "PR workflow."
    if group == "issue" and action in {"close", "comment", "create", "edit"}:
        return "allow", "Issue workflow."
    if group == "gist" and action == "create":
        return "allow", "Gist creation."

    if group == "api":
        if _mutating_api(arguments):
            return "ask", "Mutating API call — confirm."
        return "allow", "Read-only API call."
    if group in {"cache", "secret"} and action in {"delete", "set"}:
        return "ask", "Sensitive operation — confirm."
    if group == "release" and action == "delete":
        return "ask", "Release deletion — confirm."
    if group == "gist" and action == "delete":
        return "ask", "Gist deletion — confirm."

    read_only = {
        "alias": {"list"},
        "attestation": {"verify"},
        "cache": {"list"},
        "config": {"get", "list"},
        "extension": {"browse", "list", "search"},
        "gist": {"clone", "list", "view"},
        "issue": {"list", "status", "view"},
        "label": {"list"},
        "pr": {"checks", "diff", "list", "status", "view"},
        "release": {"download", "list", "verify", "verify-asset", "view"},
        "repo": {"list", "view"},
        "run": {"download", "list", "view", "watch"},
        "secret": {"list"},
        "variable": {"list"},
        "workflow": {"list", "view"},
    }
    if group in {"browse", "completion", "search", "status", "version"}:
        return "allow", "Read-only gh command."
    if action in read_only.get(group, set()):
        return "allow", "Read-only gh command."
    return "ask", "Unmatched gh command — confirm."


def gh_decision(commands: list[ShellCommand]) -> tuple[str, str] | None:
    result: tuple[str, str] | None = None
    for command in commands:
        invocation = _gh_invocation(command)
        if invocation is None:
            continue
        decision = _classify_gh(*invocation)
        if decision[0] == "deny":
            return decision
        if result is None or decision[0] == "ask":
            result = decision
    return result


# --- hook entry point -------------------------------------------------------------


def _emit_decision(decision: str, reason: str) -> None:
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": decision,
                    "permissionDecisionReason": reason,
                }
            },
            separators=(",", ":"),
        )
    )


def _input_commands() -> list[ShellCommand]:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError, UnicodeDecodeError) as error:
        raise ShellParseError("Invalid hook input") from error
    if not isinstance(payload, dict):
        raise ShellParseError("Hook input must be an object")
    tool_input = payload.get("tool_input")
    if not isinstance(tool_input, dict):
        raise ShellParseError("Hook input must contain tool_input")
    command = tool_input.get("command")
    if not isinstance(command, str):
        raise ShellParseError("Hook input must contain a command string")
    return shell_commands(command)


def _handle_parse_failure(mode: str) -> int:
    reason = "Unable to parse shell command safely — confirm manually."
    if mode == "git-bypass":
        print(reason, file=sys.stderr)
        return 2
    _emit_decision("ask", reason)
    return 0


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode not in {"gh", "git-bypass"}:
        raise SystemExit(f"Unknown guard mode: {mode}")
    try:
        commands = _input_commands()
    except (ShellParseError, RecursionError):
        return _handle_parse_failure(mode)
    if mode == "git-bypass":
        if git_bypass_blocked(commands):
            print("Don't bypass git hooks.", file=sys.stderr)
            return 2
        return 0
    decision = gh_decision(commands)
    if decision is not None:
        _emit_decision(*decision)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
