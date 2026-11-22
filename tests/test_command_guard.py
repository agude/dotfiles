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


# Regressions found by the property campaign (.plans/property-mutation/plan.md).
@pytest.mark.parametrize(
    "text",
    [
        pytest.param("git commit -nm msg", id="G1-short-cluster"),
        pytest.param("git commit -an -m msg", id="G1-cluster-after-a"),
        pytest.param("git commit --no-verif -m msg", id="G2-long-prefix"),
        pytest.param("git commit --no-gpg -m msg", id="G2-gpg-prefix"),
        pytest.param("{ git commit --no-verify -m msg; }", id="G3-brace-group"),
        pytest.param("if true; then git commit --no-verify -m msg; fi", id="G3-if"),
        pytest.param("for i in 1; do git commit --no-verify -m msg; done", id="G3-for"),
        pytest.param("! git commit --no-verify -m msg", id="G3-bang"),
        pytest.param("time git commit --no-verify -m msg", id="G3-time"),
        pytest.param("function f { git commit --no-verify -m msg; }; f", id="G3-function"),
        pytest.param("command git commit --no-verify -m msg", id="G4-command"),
        pytest.param("exec git commit --no-verify -m msg", id="G4-exec"),
        pytest.param("nice -n 5 git commit --no-verify -m msg", id="G4-nice"),
        pytest.param("sudo -u root git commit --no-verify -m msg", id="G4-sudo"),
        pytest.param("timeout 5 git commit --no-verify -m msg", id="G4-timeout"),
        pytest.param("env -S 'git commit --no-verify -m msg'", id="G5-env-split-string"),
        pytest.param("git commit $'--no-verify' -m msg", id="G6-ansi-c"),
        pytest.param("git commit $'\\x2d-no-verify' -m msg", id="G6-ansi-c-escape"),
        pytest.param("git -c commit.gpgsign=0 commit -m msg", id="G7-gpgsign-0"),
        pytest.param("git -c commit.gpgsign=off commit -m msg", id="G7-gpgsign-off"),
        pytest.param("git -c core.hooksPath=/dev/null commit -m msg", id="G7-hooks-path"),
        pytest.param("git --config-env=commit.gpgsign=VALUE commit -m msg", id="G7-config-env"),
        pytest.param("git 2>/dev/null commit -n -m msg", id="G8-fd-redirect"),
        pytest.param("x=$((1<<2))\ngit commit --no-verify -m msg", id="G9-arithmetic-shift"),
        pytest.param("cat <<'EOF'\ndon't\nEOF\ngit commit \\\n--no-verify -m msg",
                     id="G10-quote-in-heredoc-body"),
        pytest.param("bash <<'EOF'\ngit commit --no-verify -m msg\nEOF", id="G11-heredoc-shell"),
        pytest.param("bash <<< 'git commit --no-verify -m msg'", id="G11-here-string-shell"),
        pytest.param('echo "$(cat <<END\ndon\'t\nEND\n)"; git commit --no-verify -m msg',
                     id="G10-heredoc-in-quoted-substitution"),
        pytest.param("git commit -m ';' -n", id="G15-quoted-operator"),
        pytest.param('echo "$(case a in a) git commit --no-verify -m msg;; esac)"',
                     id="G16-case-in-substitution"),
        pytest.param("cat <<-OUT\n\t$(cat <<IN\n\t$(git commit --no-verify -m msg)\n\tIN\n\t)\n\tOUT",
                     id="G17-nested-heredoc-in-tab-stripped-body"),
        pytest.param("echo \"$(cat <<END\nbody\nEND\ngit commit --no-verify -m msg)\"",
                     id="G18-command-after-heredoc-in-substitution"),
    ],
)
def test_git_bypass_blocks_campaign_regressions(text: str) -> None:
    assert command_guard.git_bypass_blocked(command_guard.shell_commands(text))


@pytest.mark.parametrize(
    "text",
    [
        pytest.param("echo 'git commit --no-verify' | bash", id="G12-piped-shell"),
        pytest.param("xargs git commit --no-verify < list", id="G12-xargs"),
        pytest.param("echo " + "$(echo " * 3000 + "x" + ")" * 3000, id="G13-deep-nesting"),
    ],
)
def test_shell_commands_rejects_opaque_input(text: str) -> None:
    with pytest.raises(command_guard.ShellParseError):
        command_guard.shell_commands(text)


@pytest.mark.parametrize(
    "text",
    [
        pytest.param("printf '%s' '$(git commit --no-verify)'", id="G14-single-quoted-substitution"),
        pytest.param("git commit -mn", id="message-n"),
        pytest.param("git commit --no-verbose -m msg", id="no-verbose"),
        pytest.param("git -c commit.gpgsign=true commit -m msg", id="gpgsign-true"),
        pytest.param("git -c commit.gpgsign commit -m msg", id="gpgsign-implicit-true"),
        pytest.param("printf 'a | bash'", id="quoted-pipe-to-shell"),
    ],
)
def test_git_bypass_allows_campaign_lookalikes(text: str) -> None:
    assert not command_guard.git_bypass_blocked(command_guard.shell_commands(text))


@pytest.mark.parametrize(
    "text",
    [
        "{ gh repo delete owner/repository; }",
        "env -S 'gh repo delete owner/repository'",
        "command gh auth logout",
        "then gh repo delete owner/repository",
    ],
)
def test_gh_denies_wrapped_commands(text: str) -> None:
    decision = command_guard.gh_decision(command_guard.shell_commands(text))
    assert decision is not None and decision[0] == "deny"


def test_shell_commands_preserves_carriage_return_in_quotes() -> None:
    assert command_guard.shell_commands("printf '%s' '\r'") == [
        command_guard.ShellCommand("printf", ("%s", "\r"))
    ]


def test_git_bypass_main_blocks_parse_failure(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    payload = {"tool_input": {"command": "echo 'unterminated"}}
    monkeypatch.setattr(command_guard.sys, "argv", ["command_guard.py", "git-bypass"])
    monkeypatch.setattr(command_guard.sys, "stdin", io.StringIO(json.dumps(payload)))

    status = command_guard.main()

    assert status == 2
    assert "Unable to parse shell command safely" in capsys.readouterr().err


@pytest.mark.parametrize("mode", ["gh"])
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
