# /// script
# requires-python = ">=3.10"
# dependencies = ["pytest==9.1.1"]
# ///
"""Direct tests for the shared command guard."""

from __future__ import annotations

import importlib.util
import io
import json
import sys
from pathlib import Path

import pytest


REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
GUARD_PATH = REPOSITORY_ROOT / "llm/claude/hooks.d/command_guard.py"
MODULE_SPEC = importlib.util.spec_from_file_location("command_guard", GUARD_PATH)
assert MODULE_SPEC is not None
assert MODULE_SPEC.loader is not None
command_guard = importlib.util.module_from_spec(MODULE_SPEC)
sys.modules[MODULE_SPEC.name] = command_guard
MODULE_SPEC.loader.exec_module(command_guard)


def test_shell_commands_parses_environment_and_chain() -> None:
    commands = command_guard.shell_commands(
        "printf ready && env CI=1 git commit --no-verify -m test"
    )

    assert commands == [
        command_guard.ShellCommand("printf", ("ready",)),
        command_guard.ShellCommand("git", ("commit", "--no-verify", "-m", "test")),
    ]


def test_shell_commands_ignores_heredoc_body() -> None:
    commands = command_guard.shell_commands(
        "git commit -F - <<'EOF'\nDocument --no-verify behavior\nEOF"
    )

    assert commands == [command_guard.ShellCommand("git", ("commit", "-F", "-"))]


def test_git_bypass_blocks_expanding_heredoc_substitution() -> None:
    text = "cat <<EOF\n$(git commit --no-verify -m test)\nEOF"

    assert command_guard.git_bypass_blocked(command_guard.shell_commands(text))


def test_git_bypass_allows_literal_heredoc_substitution() -> None:
    text = "cat <<'EOF'\n$(git commit --no-verify -m test)\nEOF"

    assert not command_guard.git_bypass_blocked(command_guard.shell_commands(text))


def test_git_bypass_inspects_multiple_heredocs_in_order() -> None:
    text = (
        "cat <<'ONE' <<TWO\n"
        "literal --no-verify text\n"
        "ONE\n"
        "$(git commit --no-verify -m test)\n"
        "TWO"
    )

    assert command_guard.git_bypass_blocked(command_guard.shell_commands(text))


def test_git_bypass_blocks_continued_option() -> None:
    text = "git commit \\" + "\n--no-verify -m test"

    assert command_guard.git_bypass_blocked(command_guard.shell_commands(text))


@pytest.mark.parametrize(
    "text",
    [
        "cat <(git commit --no-verify -m test)",
        'echo "$(git commit --no-verify -m test)"',
        "echo `git commit --no-verify -m test`",
        "bash -c 'git commit --no-verify -m test'",
        "eval 'git commit --no-verify -m test'",
    ],
)
def test_git_bypass_blocks_nested_commands(text: str) -> None:
    assert command_guard.git_bypass_blocked(command_guard.shell_commands(text))


def test_gh_denies_nested_process_substitution() -> None:
    commands = command_guard.shell_commands("cat >(gh repo delete owner/repository)")

    assert command_guard.gh_decision(commands) == (
        "deny",
        "Destructive repo operation blocked.",
    )


@pytest.mark.parametrize("text", ["echo 'unterminated", "cat <(git status"])
def test_shell_commands_rejects_malformed_input(text: str) -> None:
    with pytest.raises(command_guard.ShellParseError):
        command_guard.shell_commands(text)


@pytest.mark.parametrize(
    "text",
    [
        "git commit --no-verify -m test",
        "git merge -n feature",
        "git push --no-gpg-sign",
        "git -c commit.gpgsign=false commit -m test",
        "env CI=1 git commit --no-verify -m test",
    ],
)
def test_git_bypass_blocks_guarded_options(text: str) -> None:
    assert command_guard.git_bypass_blocked(command_guard.shell_commands(text))


@pytest.mark.parametrize(
    "text",
    [
        "git log -n 5",
        "git clean -n",
        "git commit -m 'Document --no-verify behavior'",
        "echo --no-verify",
    ],
)
def test_git_bypass_allows_unrelated_options(text: str) -> None:
    assert not command_guard.git_bypass_blocked(command_guard.shell_commands(text))


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("git push --force origin feature", "deny-force"),
        ("git push origin +feature:feature", "deny-force"),
        ("git push origin feature:refs/heads/main", "deny-protected"),
        ("git push origin feature", "allow"),
        ("git status", "none"),
    ],
)
def test_git_push_classifies_explicit_refspecs(text: str, expected: str) -> None:
    assert command_guard.git_push_decision(command_guard.shell_commands(text)) == expected


def test_git_push_checks_current_branch(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(command_guard, "_current_branch", lambda: "main")

    decision = command_guard.git_push_decision(command_guard.shell_commands("git push origin"))

    assert decision == "deny-protected"


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("gh repo delete owner/repository", ("deny", "Destructive repo operation blocked.")),
        ("gh pr merge 42", ("ask", "PR merge — confirm.")),
        ("gh api --method DELETE repos/owner/repository", ("ask", "Mutating API call — confirm.")),
        ("gh pr create --fill", ("allow", "PR workflow.")),
        ("gh repo view owner/repository", ("allow", "Read-only gh command.")),
        ("gh ruleset delete 123", ("ask", "Unmatched gh command — confirm.")),
        ("git status", None),
    ],
)
def test_gh_classifies_commands(text: str, expected: tuple[str, str] | None) -> None:
    assert command_guard.gh_decision(command_guard.shell_commands(text)) == expected


def test_git_bypass_main_blocks_parse_failure(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    payload = {"tool_input": {"command": "echo 'unterminated"}}
    monkeypatch.setattr(command_guard.sys, "argv", ["command_guard.py", "git-bypass"])
    monkeypatch.setattr(command_guard.sys, "stdin", io.StringIO(json.dumps(payload)))

    status = command_guard.main()

    assert status == 2
    assert "Unable to parse shell command safely" in capsys.readouterr().err


@pytest.mark.parametrize("mode", ["gh", "git-push"])
def test_decision_guards_ask_on_parse_failure(
    mode: str,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    payload = {"tool_input": {"command": "echo 'unterminated"}}
    monkeypatch.setattr(command_guard.sys, "argv", ["command_guard.py", mode])
    monkeypatch.setattr(command_guard.sys, "stdin", io.StringIO(json.dumps(payload)))

    status = command_guard.main()

    output = json.loads(capsys.readouterr().out)
    assert status == 0
    assert output["hookSpecificOutput"]["permissionDecision"] == "ask"
    assert (
        output["hookSpecificOutput"]["permissionDecisionReason"]
        == "Unable to parse shell command safely — confirm manually."
    )


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, *sys.argv[1:]]))
