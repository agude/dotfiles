#!/usr/bin/env python3
"""Apply Git and GitHub CLI policy to shell command strings."""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass


CONTROL_OPERATORS = {"&", "&&", "(", ")", ";", "|", "||"}
REDIRECT_OPERATORS = {"<", "<<", "<<-", ">", ">>", "<>"}
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
PROTECTED_BRANCHES = {"main", "master", "refs/heads/main", "refs/heads/master"}
NESTED_SHELLS = {"bash", "dash", "ksh", "sh", "zsh"}


@dataclass(frozen=True)
class ShellCommand:
    executable: str
    arguments: tuple[str, ...]


class ShellParseError(ValueError):
    """Raised when a command cannot be analyzed safely."""


def _tokens(text: str) -> list[str]:
    lexer = shlex.shlex(text, posix=True, punctuation_chars=";&|()<>")
    lexer.commenters = ""
    lexer.whitespace_split = True
    return list(lexer)


def _join_continued_lines(text: str) -> str:
    result: list[str] = []
    quote = ""
    index = 0

    while index < len(text):
        character = text[index]
        next_character = text[index + 1] if index + 1 < len(text) else ""
        if character == "\\" and next_character == "\n" and quote != "'":
            index += 2
            continue
        if character == "\\" and next_character and quote != "'":
            result.extend((character, next_character))
            index += 2
            continue
        if character == "'" and quote != '"':
            quote = "" if quote == "'" else "'"
        elif character == '"' and quote != "'":
            quote = "" if quote == '"' else '"'
        result.append(character)
        index += 1

    return "".join(result)


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
    quote = ""
    index = opening_index + 1

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
        elif not quote and character == "(":
            depth += 1
        elif not quote and character == ")":
            depth -= 1
            if depth == 0:
                return index
        index += 1

    raise ShellParseError("Unclosed parenthesized substitution")


def _extract_nested_commands(text: str) -> tuple[str, list[str]]:
    outer_text: list[str] = []
    nested_commands: list[str] = []
    quote = ""
    index = 0

    while index < len(text):
        character = text[index]
        next_character = text[index + 1] if index + 1 < len(text) else ""
        if character == "\\" and next_character and quote != "'":
            outer_text.extend((character, next_character))
            index += 2
            continue
        if character == "'" and quote != '"':
            quote = "" if quote == "'" else "'"
            outer_text.append(character)
            index += 1
            continue
        if character == '"' and quote != "'":
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

        opens_command = character == "$" and next_character == "("
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


def _heredoc_delimiters(line: str) -> list[tuple[str, bool]]:
    try:
        tokens = _tokens(line)
    except ValueError:
        return []

    delimiters: list[tuple[str, bool]] = []
    for index, token in enumerate(tokens[:-1]):
        if token in {"<<", "<<-"}:
            delimiters.append((tokens[index + 1], token == "<<-"))
    return delimiters


def _strip_heredoc_bodies(text: str) -> str:
    kept_lines: list[str] = []
    pending: list[tuple[str, bool]] = []

    for line in text.splitlines():
        if pending:
            delimiter, strip_tabs = pending[0]
            candidate = line.lstrip("\t") if strip_tabs else line
            if candidate == delimiter:
                pending.pop(0)
            continue

        kept_lines.append(line)
        pending.extend(_heredoc_delimiters(line))

    return "\n".join(kept_lines)


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


def _without_redirects(tokens: list[str]) -> list[str]:
    result: list[str] = []
    skip_target = False
    for token in tokens:
        if skip_target:
            skip_target = False
            continue
        if token in REDIRECT_OPERATORS:
            skip_target = True
            continue
        result.append(token)
    return result


def _unwrap_environment(tokens: list[str]) -> list[str]:
    while tokens and ASSIGNMENT.match(tokens[0]):
        tokens.pop(0)

    if not tokens or os.path.basename(tokens[0]) != "env":
        return tokens

    tokens.pop(0)
    while tokens:
        token = tokens[0]
        if ASSIGNMENT.match(token):
            tokens.pop(0)
        elif token in {"-u", "--unset", "-C", "--chdir", "-S", "--split-string"}:
            del tokens[:2]
        elif token.startswith("-"):
            tokens.pop(0)
        else:
            break
    return tokens


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


def shell_commands(text: str) -> list[ShellCommand]:
    continued = _join_continued_lines(text)
    without_heredocs = _strip_heredoc_bodies(continued)
    outer_text, nested_texts = _extract_nested_commands(without_heredocs)
    prepared = _delimit_unquoted_newlines(outer_text)
    try:
        tokens = _tokens(prepared)
    except ValueError as error:
        raise ShellParseError(str(error)) from error

    commands: list[ShellCommand] = []
    segment: list[str] = []
    for token in [*tokens, ";"]:
        if token not in CONTROL_OPERATORS:
            segment.append(token)
            continue
        words = _unwrap_environment(_without_redirects(segment))
        if words:
            commands.append(ShellCommand(os.path.basename(words[0]), tuple(words[1:])))
        segment = []

    nested_texts.extend(
        nested_text for command in commands if (nested_text := _nested_shell_text(command))
    )
    for nested_text in nested_texts:
        commands.extend(shell_commands(nested_text))
    return commands


def _git_invocation(command: ShellCommand) -> tuple[str, list[str], list[str]] | None:
    if command.executable != "git":
        return None

    arguments = list(command.arguments)
    original = list(arguments)
    options_with_values = {"-c", "-C", "--config-env", "--exec-path", "--git-dir", "--work-tree"}
    while arguments and arguments[0].startswith("-"):
        option = arguments.pop(0)
        if option in options_with_values and arguments:
            arguments.pop(0)
    if not arguments:
        return None
    return arguments.pop(0), arguments, original


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


def git_bypass_blocked(commands: list[ShellCommand]) -> bool:
    short_no_verify = {"am", "cherry-pick", "commit", "merge", "revert"}
    for command in commands:
        invocation = _git_invocation(command)
        if invocation is None:
            continue
        subcommand, arguments, original = invocation
        options = _option_tokens(arguments)
        if "--no-verify" in options or "--no-gpg-sign" in options:
            return True
        if subcommand in short_no_verify and "-n" in options:
            return True
        for index, token in enumerate(original[:-1]):
            if token == "-c" and original[index + 1].lower() == "commit.gpgsign=false":
                return True
    return False


def _current_branch() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        check=False,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def _push_refspecs(arguments: list[str]) -> tuple[bool, list[str]]:
    force = False
    positional: list[str] = []
    value_options = {"--exec", "--push-option", "--receive-pack", "--repo", "-o"}
    index = 0
    while index < len(arguments):
        token = arguments[index]
        if token == "--":
            positional.extend(arguments[index + 1 :])
            break
        if token in {"--force", "--force-with-lease", "--mirror"} or token.startswith(
            "--force-with-lease="
        ):
            force = True
        elif token.startswith("-"):
            if not token.startswith("--") and "f" in token[1:]:
                force = True
            if token in value_options:
                index += 1
        else:
            positional.append(token)
        index += 1

    refspecs = positional[1:] if positional else []
    return force or any(refspec.startswith("+") for refspec in refspecs), refspecs


def _protected_destination(refspec: str) -> bool:
    normalized = refspec.lstrip("+")
    destination = normalized.rsplit(":", 1)[-1]
    return destination in PROTECTED_BRANCHES


def git_push_decision(commands: list[ShellCommand]) -> str:
    saw_push = False
    for command in commands:
        invocation = _git_invocation(command)
        if invocation is None or invocation[0] != "push":
            continue
        saw_push = True
        force, refspecs = _push_refspecs(invocation[1])
        if force:
            return "deny-force"
        if any(_protected_destination(refspec) for refspec in refspecs):
            return "deny-protected"
        if not refspecs or any(refspec in {"@", "HEAD"} for refspec in refspecs):
            if _current_branch() in {"main", "master"}:
                return "deny-protected"
    return "allow" if saw_push else "none"


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
    except (json.JSONDecodeError, OSError) as error:
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
    if mode not in {"gh", "git-bypass", "git-push"}:
        raise SystemExit(f"Unknown guard mode: {mode}")
    try:
        commands = _input_commands()
    except ShellParseError:
        return _handle_parse_failure(mode)
    if mode == "git-bypass":
        if git_bypass_blocked(commands):
            print("Don't bypass git hooks.", file=sys.stderr)
            return 2
        return 0
    if mode == "git-push":
        decision = git_push_decision(commands)
        if decision == "deny-force":
            _emit_decision("deny", "Force push is blocked.")
        elif decision == "deny-protected":
            _emit_decision("deny", "Don't push directly to main/master.")
        elif decision == "allow":
            _emit_decision("allow", "Push to feature branch.")
        return 0
    if mode == "gh":
        decision = gh_decision(commands)
        if decision is not None:
            _emit_decision(*decision)
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
