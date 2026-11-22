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
        pytest.param('echo "$(echo case)"; git commit --no-verify -m msg',
                     id="G19-case-argument-then-bypass"),
        pytest.param("echo $(( $(git commit --no-verify -m msg) + 1 ))",
                     id="G20-substitution-inside-arithmetic"),
        pytest.param('echo "$({ case a in a) git commit --no-verify -m msg;; esac; })"',
                     id="G21-case-in-brace-group-in-substitution"),
        pytest.param('echo "$(echo $(case a in a) git commit -n -m msg;; esac))"',
                     id="G22-case-in-nested-substitution"),
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
        pytest.param('echo "$(echo case)"', id="G19-case-as-argument"),
        pytest.param("z=$((1<<(2)))", id="G20-arithmetic-with-parentheses"),
        pytest.param('echo "$(echo ${x} case)"', id="G21-brace-expansion-then-case"),
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


# Every rule of the gh policy, stated independently of _classify_gh.
GH_POLICY = [
    *[(f"repo {a} o/r", "deny", "Destructive repo operation blocked.")
      for a in ("archive", "change-visibility", "delete", "rename")],
    *[(f"{g} {a}", "deny", "Credential operation blocked.")
      for g in ("auth", "gpg-key", "ssh-key") for a in ("login", "list", "")],
    ("config set editor vim", "deny", "Config change blocked."),
    *[(f"extension {a} x", "deny", "Extension management blocked.")
      for a in ("install", "remove")],
    *[(f"codespace {a}", "deny", "Codespace operation blocked.") for a in ("list", "ssh")],
    ("issue delete 1", "deny", "Issue deletion blocked."),
    ("pr merge 1", "ask", "PR merge — confirm."),
    *[(f"pr {a} 1", "allow", "PR workflow.")
      for a in ("close", "comment", "create", "edit", "ready", "review")],
    *[(f"issue {a} 1", "allow", "Issue workflow.")
      for a in ("close", "comment", "create", "edit")],
    ("gist create f", "allow", "Gist creation."),
    ("api repos/o/r", "allow", "Read-only API call."),
    ("api -X GET repos/o/r", "allow", "Read-only API call."),
    ("api --method get repos/o/r", "allow", "Read-only API call."),
    *[(f"api {flag} repos/o/r", "ask", "Mutating API call — confirm.")
      for flag in ("--field a=1", "--input f", "--raw-field a=1", "-F a=1", "-f a=1",
                   "--field=a=1", "--input=f", "--raw-field=a=1", "-F=a=1", "-f=a=1",
                   "-X DELETE", "-X patch", "--method POST", "--method=put", "-XDELETE",
                   "-Xpost")],
    *[(f"{g} {a} X", "ask", "Sensitive operation — confirm.")
      for g in ("cache", "secret") for a in ("delete", "set")],
    ("release delete v1", "ask", "Release deletion — confirm."),
    ("gist delete 1", "ask", "Gist deletion — confirm."),
    *[(f"{g}", "allow", "Read-only gh command.")
      for g in ("browse", "completion", "search", "status", "version")],
    *[(f"{g} {a}", "allow", "Read-only gh command.") for g, actions in {
        "alias": ["list"], "attestation": ["verify"], "cache": ["list"],
        "config": ["get", "list"], "extension": ["browse", "list", "search"],
        "gist": ["clone", "list", "view"], "issue": ["list", "status", "view"],
        "label": ["list"], "pr": ["checks", "diff", "list", "status", "view"],
        "release": ["download", "list", "verify", "verify-asset", "view"],
        "repo": ["list", "view"], "run": ["download", "list", "view", "watch"],
        "secret": ["list"], "variable": ["list"], "workflow": ["list", "view"],
    }.items() for a in actions],
    *[(f"{g} {a}", "ask", "Unmatched gh command — confirm.") for g, a in [
        ("alias", "set"), ("label", "create"), ("run", "rerun"), ("workflow", "run"),
        ("variable", "set"), ("repo", "create"), ("pr", "unknown"), ("ruleset", "list"),
        ("config", "clear-cache"), ("release", "create"), ("gist", "edit"),
        ("issue", "transfer"), ("attestation", "download"), ("extension", "upgrade"),
    ]],
    ("--hostname h repo delete o/r", "deny", "Destructive repo operation blocked."),
    ("-R o/r pr -R o/r merge 1", "ask", "PR merge — confirm."),
    ("pr --repo o/r view 1", "allow", "Read-only gh command."),
    ("pr --hostname h view", "allow", "Read-only gh command."),
    ("pr --web view", "allow", "Read-only gh command."),
]


@pytest.mark.parametrize(("arguments", "decision", "reason"), GH_POLICY,
                         ids=[case[0] or "empty" for case in GH_POLICY])
def test_gh_policy_table(arguments: str, decision: str, reason: str) -> None:
    commands = command_guard.shell_commands("gh " + arguments)
    assert command_guard.gh_decision(commands) == (decision, reason)


@pytest.mark.parametrize("text", ["gh", "gh --repo o/r", "gh -R"])
def test_gh_without_group_has_no_decision(text: str) -> None:
    assert command_guard.gh_decision(command_guard.shell_commands(text)) is None


def test_gh_chain_takes_most_severe_and_first_deny() -> None:
    commands = command_guard.shell_commands(
        "gh pr view 1; gh pr merge 1; gh issue list; gh auth logout; gh repo delete o/r")
    assert command_guard.gh_decision(commands) == ("deny", "Credential operation blocked.")
    commands = command_guard.shell_commands("gh pr merge 1; gh pr view 1")
    assert command_guard.gh_decision(commands) == ("ask", "PR merge — confirm.")
    commands = command_guard.shell_commands("gh pr view 1; gh api -X POST x")
    assert command_guard.gh_decision(commands) == ("ask", "Mutating API call — confirm.")


# Malformed input must parse or raise ShellParseError; any other exception
# crashes the hook, and a crash is non-blocking.
@pytest.mark.parametrize(
    "text",
    [
        'echo "a\\', "echo $'abc\\", "echo $'\\01", "echo $'\\x4", "echo $'\\u00",
        "echo $'\\c", "echo $'\\X'", "echo $((1", "echo $((1<<2", "echo $(case",
        "echo $(echo; case", "x=$(( (1) )", "echo \\", "echo 'a",
    ],
)
def test_malformed_input_never_crashes(text: str) -> None:
    try:
        command_guard.shell_commands(text)
    except command_guard.ShellParseError:
        pass


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ("echo $'\\0101'", ["\x081"]),
        ("echo $'\\u00e9a'", ["\u00e9a"]),
        ("echo $'\\U0001F600a'", ["\U0001F600a"]),
        ("echo $'\\x41g'", ["Ag"]),
        ("echo $'\\xg'", ["\\xg"]),
        ("echo $'\\xX'", ["\\xX"]),
        ("echo $'\\uX'", ["\\uX"]),
        ("echo $'\\X'", ["\\X"]),
        ("echo $'\\ca'", ["\x01"]),
        ('echo "\\a"', ["\\a"]),
    ],
)
def test_ansi_c_and_double_quote_escapes(text: str, expected: list[str]) -> None:
    assert command_guard.shell_commands(text) == [
        command_guard.ShellCommand("echo", tuple(expected))]


@pytest.mark.parametrize(
    "text",
    [" git commit --no-verify -m msg", "echo $( git commit --no-verify -m msg)",
     "\tgit commit -n -m msg"],
)
def test_leading_blanks_do_not_hide_the_command(text: str) -> None:
    assert command_guard.git_bypass_blocked(command_guard.shell_commands(text))


def test_word_starting_with_case_is_a_command() -> None:
    commands = command_guard.shell_commands('echo "$(caseX)"; git commit -n -m msg')
    assert command_guard.ShellCommand("caseX", ()) in commands
    assert command_guard.git_bypass_blocked(commands)


# Lexical cases from mutation survivors: each separator, quoting form and
# boundary that decides where a command or a heredoc starts.
@pytest.mark.parametrize(
    "text",
    [
        "true;2>/dev/null git commit -n -m msg",
        "true&2>/dev/null git commit -n -m msg",  # G23: dropping "2" made "&>"
        "true|2>/dev/null git commit -n -m msg",
        "(2>/dev/null git commit -n -m msg)",
        "true\n2>/dev/null git commit -n -m msg",
        "git\t2>/dev/null commit -n -m msg",
        "echo $(2>/dev/null git commit -n -m msg)",
        "echo x; bash <<'E'\ngit commit --no-verify -m msg\nE",
        "echo x && bash <<'E'\ngit commit --no-verify -m msg\nE",
        "echo x | bash <<'E'\ngit commit --no-verify -m msg\nE",
        "(bash <<'E'\ngit commit --no-verify -m msg\nE\n)",
        "{ bash <<'E'\ngit commit --no-verify -m msg\nE\n}",
        "echo $(bash <<'E'\ngit commit --no-verify -m msg\nE\n)",
        "cat <<\\EOF\nbody\nEOF\ngit commit -n -m msg",
        "cat <<E\\OF\nbody\nEOF\ngit commit -n -m msg",
        "cat <<'E\\F'\nbody\nE\\F\ngit commit -n -m msg",
        "cat <<\"E'F\"\nbody\nE'F\ngit commit -n -m msg",
        "cat <<'E\"F'\nbody\nE\"F\ngit commit -n -m msg",
        "cat <<XEND\nbody\nXEND\ngit commit -n -m msg",
        "echo \"`date`\"; git commit $'--no-verify' -m msg",
        "echo \"`echo \\\"x\\\"`\"; git commit $'--no-verify' -m msg",
    ],
)
def test_git_bypass_blocks_lexical_cases(text: str) -> None:
    assert command_guard.git_bypass_blocked(command_guard.shell_commands(text))


@pytest.mark.parametrize(
    "text",
    [
        'echo "$(echo {case)"', 'echo "$(echo X{ case)"', 'echo "$(Xcase)"',
        'echo "$(echo X case)"', "echo bash <<'E'\ngit commit --no-verify -m msg\nE",
        "cat <<EOF\nhello\nEOF", "cat <<XEND\ngit commit --no-verify -m msg\nXEND",
        "cat <<\"EOF\"\n$(git commit --no-verify -m msg)\nEOF",
        "cat <<OUT\nit's $(cat <<'IN'\n(\nIN\n)\nOUT",
    ],
)
def test_git_bypass_allows_lexical_lookalikes(text: str) -> None:
    assert not command_guard.git_bypass_blocked(command_guard.shell_commands(text))


@pytest.mark.parametrize("text", ["echo {x", "echo }x", 'echo "\\"', "echo $'\\'",
                                  "echo $'\\1", "cat <<E\\"])
def test_unterminated_or_edge_text_never_crashes(text: str) -> None:
    try:
        command_guard.shell_commands(text)
    except command_guard.ShellParseError:
        pass


@pytest.mark.parametrize(("text", "words"), [
    ("echo a\\", ["a\\"]), ("echo \\", ["\\"]), ("echo $'\\1X'", ["\x01X"]),
    ("echo 2X 3x 4", ["2X", "3x", "4"]), ("echo 2>&1 5", ["5"]),
])
def test_trailing_backslash_and_octal_boundaries(text: str, words: list[str]) -> None:
    assert command_guard.shell_commands(text) == [
        command_guard.ShellCommand("echo", tuple(words))]


@pytest.mark.parametrize("text", ['echo "\\"', "echo $'\\'"])
def test_escaped_closing_quote_is_unterminated(text: str) -> None:
    with pytest.raises(command_guard.ShellParseError):
        command_guard.shell_commands(text)


def test_nesting_limit_is_exact() -> None:
    limit = command_guard.MAX_DEPTH

    def nested(depth: int) -> str:
        return "echo " + "$(" * depth + "git status" + ")" * depth

    assert command_guard.ShellCommand("git", ("status",)) in command_guard.shell_commands(
        nested(limit))
    with pytest.raises(command_guard.ShellParseError):
        command_guard.shell_commands(nested(limit + 1))


# Exact parses of keywords, wrappers and nested shells, reviewed against bash.
WRAPPER_PARSES = [
    ('! git log', [('git', ('log',))]),
    ('{ git log; }', [('git', ('log',))]),
    ('if git log; then :; fi', [('git', ('log',)), (':', ())]),
    ('while git log; do :; done', [('git', ('log',)), (':', ())]),
    ('until git log; do :; done', [('git', ('log',)), (':', ())]),
    ('for x in git status; do git log; done', [('git', ('log',))]),
    ('select x in a; do git log; done', [('git', ('log',))]),
    ('case $x in a) git log;; esac', [('git', ('log',))]),
    ('function f { git log; }', [('git', ('log',))]),
    ('function f() { git log; }', [('git', ('log',))]),
    ('coproc git log', [('git', ('log',))]),
    ('coproc NAME { git log; }', [('git', ('log',))]),
    ('[[ -n x ]] && git log', [('git', ('log',))]),
    ('A=1 B=2 git log', [('git', ('log',))]),
    ('a[1]=x git log', [('git', ('log',))]),
    ('A+=1 git log', [('git', ('log',))]),
    ('env git log', [('git', ('log',))]),
    ('env A=1 -i git log', [('git', ('log',))]),
    ('env -u HOME git log', [('git', ('log',))]),
    ('env --unset HOME git log', [('git', ('log',))]),
    ('env -C /tmp git log', [('git', ('log',))]),
    ('env --chdir /tmp git log', [('git', ('log',))]),
    ('env -- git log', [('git', ('log',))]),
    ("env -S 'git log -n 1'", [('git', ('log', '-n', '1'))]),
    ("env --split-string='git log'", [('git', ('log',))]),
    ("env -S'git log'", [('git', ('log',))]),
    ("env -iS 'git log'", [('git', ('log',))]),
    ("env -vS'git log'", [('git', ('log',))]),
    ('command git log', [('git', ('log',))]),
    ('command -p git log', [('git', ('log',))]),
    ('builtin git log', [('git', ('log',))]),
    ('exec -a name git log', [('git', ('log',))]),
    ('exec -cl git log', [('git', ('log',))]),
    ('nice git log', [('git', ('log',))]),
    ('nice -n 5 git log', [('git', ('log',))]),
    ('nice -5 git log', [('git', ('log',))]),
    ('nice --adjustment=5 git log', [('git', ('log',))]),
    ('nice --adjustment 5 git log', [('git', ('log',))]),
    ('nohup git log', [('git', ('log',))]),
    ('time git log', [('git', ('log',))]),
    ('time -p git log', [('git', ('log',))]),
    ('sudo git log', [('git', ('log',))]),
    ('sudo -u root git log', [('git', ('log',))]),
    ('sudo -u root -g wheel -- git log', [('git', ('log',))]),
    ('sudo --user=root git log', [('git', ('log',))]),
    ('doas -u root git log', [('git', ('log',))]),
    ('setsid -w git log', [('git', ('log',))]),
    ('stdbuf -o L git log', [('git', ('log',))]),
    ('stdbuf -oL git log', [('git', ('log',))]),
    ('ionice -c 3 git log', [('git', ('log',))]),
    ('timeout 5 git log', [('git', ('log',))]),
    ('timeout -s KILL 5 git log', [('git', ('log',))]),
    ('timeout --signal=KILL 5 git log', [('git', ('log',))]),
    ('timeout -k 1 5 git log', [('git', ('log',))]),
    ("bash -c 'git log'", [('bash', ('-c', 'git log')), ('git', ('log',))]),
    ("bash -xc 'git log'", [('bash', ('-xc', 'git log')), ('git', ('log',))]),
    ("bash -o pipefail -c 'git log'", [('bash', ('-o', 'pipefail', '-c', 'git log')), ('git', ('log',))]),
    ("sh --norc -c 'git log'", [('sh', ('--norc', '-c', 'git log')), ('git', ('log',))]),
    ('bash -c', [('bash', ('-c',))]),
    ('bash script.sh', [('bash', ('script.sh',))]),
    ('eval git log', [('eval', ('git', 'log')), ('git', ('log',))]),
    ('eval', [('eval', ())]),
    ("bash <<< 'git log'", [('bash', ()), ('git', ('log',))]),
    ('x | bash script.sh', [('x', ()), ('bash', ('script.sh',))]),
    ("x | bash -c 'git log'", [('x', ()), ('bash', ('-c', 'git log')), ('git', ('log',))]),
    ('xargs echo', [('xargs', ('echo',))]),
    ('env', []),
    ('nice', []),
    ('timeout 5', []),
]


@pytest.mark.parametrize(("text", "expected"), WRAPPER_PARSES,
                         ids=[text for text, _ in WRAPPER_PARSES])
def test_wrapper_parses(text: str, expected: list) -> None:
    commands = command_guard.shell_commands(text)
    assert [(c.executable, c.arguments) for c in commands] == expected


@pytest.mark.parametrize("text", [
    "x | bash", "x | bash -s", "x | bash -s arg", "x | bash -x", "x | bash +x",
    "x | bash --norc", "x |& sh", "bash < script.sh", "bash -s < script.sh",
    "xargs git log", "find . -exec git log ;", "parallel bash", "watch eval x",
    "xargs -n1 sh -c 'echo'",
])
def test_unfollowable_input_is_unparseable(text: str) -> None:
    with pytest.raises(command_guard.ShellParseError):
        command_guard.shell_commands(text)


@pytest.mark.parametrize("text", [
    "x | bash script.sh", "x | bash -c 'echo'", "x | bash -xc 'echo'", "xargs echo",
    "x | bash <<< 'echo'",
    "find . -name x", "bash <<< 'echo'", "x | bash <<'E'\necho\nE",
])
def test_followable_shell_input_parses(text: str) -> None:
    command_guard.shell_commands(text)


@pytest.mark.parametrize("text", [
    "git commit -F --no-verify", "git commit --file --no-verify",
    "git commit --message --no-verify", "git commit --file=--no-verify",
    "git commit --message=--no-verify", "git commit -F--no-verify", "git commit -m-n",
    "git commit -m msg -- --no-verify", "git commit -- -n", "git commit -a -m msg",
    "git commit -Cn", "git commit -v -m msg", "git -c core.editor=x commit -m msg",
    "git --config-env=core.editor=EDITOR commit -m msg", "git -C dir commit -m msg",
    "git --git-dir x commit -m msg", "git --work-tree x status -n",
    *[f"git -c commit.gpgsign={value} commit -m msg"
      for value in ("true", "yes", "on", "TRUE", "1", "2", "0x10", "1k", "-1", "+1")],
])
def test_git_options_that_are_not_bypasses(text: str) -> None:
    assert not command_guard.git_bypass_blocked(command_guard.shell_commands(text))


@pytest.mark.parametrize("text", [
    "git commit -vn -m msg", "git commit -anm msg", "git commit --no-v=1 -m msg",
    "git commit --no-gpg-sign=x -m msg", "git --config-env=core.hooksPath=X commit -m msg",
    "git --config-env core.hookspath=X commit -m msg",
    "git --config-env=commit.gpgSign=X commit -m msg", "git -c commit.gpgsign=garbage commit",
    "env -iS 'git commit -n -m msg'", "env -vS'git commit -n -m msg'",
    "env -u HOME -S 'git commit -n -m msg'", "env - git commit -n -m msg",
    "env --split-string 'git commit -n -m msg'", "env --ignore-environment git commit -n",
    "env -uHOME git commit -n -m msg", "git --no-pager commit -n -m msg",
    "git commit -a -n -m msg", "git -c commit.gpgsign=07 commit -m msg",
    "git --config-env=commit.gpgsign=yes commit -m msg",
    "echo 'a\\'\ngit commit -n -m msg",
    *[f"git -c commit.gpgsign={value} commit -m msg"
      for value in ("false", "no", "off", "0", "", "00", "0x0", "-0", "+0", "0k", "0M")],
])
def test_git_options_that_are_bypasses(text: str) -> None:
    assert command_guard.git_bypass_blocked(command_guard.shell_commands(text))


@pytest.mark.parametrize(("text", "decision"), [
    ("gh pr --web view 1", "allow"), ("gh pr view 1 --web", "allow"),
    ("gh pr -R o/r --web view 1", "allow"), ("gh api -X", "allow"),
    ("gh api --method", "allow"), ("gh api repos/o/r -X", "allow"),
    ("gh api -X POST", "ask"), ("gh --repo o/r pr view 1", "allow"),
])
def test_gh_argument_edge_cases(text: str, decision: str) -> None:
    result = command_guard.gh_decision(command_guard.shell_commands(text))
    assert result is not None and result[0] == decision


def test_hook_input_errors_fail_closed(monkeypatch: pytest.MonkeyPatch,
                                       capsys: pytest.CaptureFixture[str]) -> None:
    class Broken(io.StringIO):
        def read(self, *args):
            raise OSError("closed")

    for stdin in (Broken(), io.TextIOWrapper(io.BytesIO(b"\xff\xfe"), encoding="utf-8")):
        monkeypatch.setattr(command_guard.sys, "argv", ["command_guard.py", "git-bypass"])
        monkeypatch.setattr(command_guard.sys, "stdin", stdin)
        assert command_guard.main() == 2
    capsys.readouterr()


def test_unknown_mode_exits_with_a_message(monkeypatch: pytest.MonkeyPatch) -> None:
    for argv in (["command_guard.py"], ["command_guard.py", "other"]):
        monkeypatch.setattr(command_guard.sys, "argv", argv)
        with pytest.raises(SystemExit, match="Unknown guard mode"):
            command_guard.main()


@pytest.mark.parametrize(("text", "expected"), [
    ("env -uS git log", [("git", ("log",))]), ("env -S", []), ("env --split-string", []),
    ("env - git log", [("git", ("log",))]),
])
def test_env_option_edge_parses(text: str, expected: list) -> None:
    commands = command_guard.shell_commands(text)
    assert [(c.executable, c.arguments) for c in commands] == expected


def test_main_messages(monkeypatch: pytest.MonkeyPatch,
                       capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.setattr(command_guard.sys, "argv", ["command_guard.py"])
    with pytest.raises(SystemExit) as raised:
        command_guard.main()
    assert str(raised.value) == "Unknown guard mode: "
    payload = json.dumps({"tool_input": {"command": "git commit -n -m msg"}})
    monkeypatch.setattr(command_guard.sys, "argv", ["command_guard.py", "git-bypass"])
    monkeypatch.setattr(command_guard.sys, "stdin", io.StringIO(payload))
    assert command_guard.main() == 2
    assert capsys.readouterr().err == "Don't bypass git hooks.\n"


# Exact parses of substitutions, quoting and escaped newlines, reviewed against bash.
LEXICAL_PARSES = [
    ('echo $(echo \\))', [('echo', ('nested-command',)), ('echo', (')',))]),
    ("echo $(echo ')')", [('echo', ('nested-command',)), ('echo', (')',))]),
    ('echo $(echo ")")', [('echo', ('nested-command',)), ('echo', (')',))]),
    ('echo $(echo `echo x`)', [('echo', ('nested-command',)), ('echo', ('nested-command',)), ('echo', ('x',))]),
    ('echo $(echo "it\'s")', [('echo', ('nested-command',)), ('echo', ("it's",))]),
    ('echo $(echo \'say "hi\')', [('echo', ('nested-command',)), ('echo', ('say "hi',))]),
    ('echo $(echo $(( 1 + 2 )))', [('echo', ('nested-command',)), ('echo', ('0',))]),
    ('echo <(echo a) >(echo b)', [('echo', ('nested-command', 'nested-command')), ('echo', ('a',)), ('echo', ('b',))]),
    ('echo "<(not)"', [('echo', ('<(not)',))]),
    ('echo $((1+2)) $(echo x)', [('echo', ('0', 'nested-command')), ('echo', ('x',))]),
    ('echo "$((1+$(echo 2)))"', [('echo', ('0',)), ('echo', ('2',))]),
    ('echo $((1+2))', [('echo', ('0',))]),
    ('echo a\\\\\ngit log', [('echo', ('a\\',)), ('git', ('log',))]),
    ("echo \\'\ngit log", [('echo', ("'",)), ('git', ('log',))]),
    ("echo 'a\nb'", [('echo', ('a\nb',))]),
    ('echo "a\nb"', [('echo', ('a\nb',))]),
    ("x | bash <<< 'echo'", [('x', ()), ('bash', ()), ('echo', ())]),
    ('echo "`echo \'"\'`" $\'x\'', [('echo', ('nested-command', 'x')), ('echo', ('"',))]),
    ('echo `echo \\`date\\``', [('echo', ('nested-command',)), ('echo', ('nested-command',)), ('date', ())]),
    ("cat <(cat <<'E'\n)\nE\n)", [('cat', ('nested-command',)), ('cat', ())]),
    ('echo `echo \\`git commit --no-verify -m msg\\``', [('echo', ('nested-command',)), ('echo', ('nested-command',)), ('git', ('commit', '--no-verify', '-m', 'msg'))]),
    ('echo `echo \\\\$HOME`', [('echo', ('nested-command',)), ('echo', ('$HOME',))]),
]


@pytest.mark.parametrize(("text", "expected"), LEXICAL_PARSES,
                         ids=[text for text, _ in LEXICAL_PARSES])
def test_lexical_parses(text: str, expected: list) -> None:
    commands = command_guard.shell_commands(text)
    assert [(c.executable, c.arguments) for c in commands] == expected


def test_nested_backtick_substitution_is_inspected() -> None:
    # Regression G25: \` inside backticks starts a nested substitution.
    assert command_guard.git_bypass_blocked(command_guard.shell_commands(
        "echo `echo \\`git commit --no-verify -m msg\\``"))


def test_nesting_through_eval_is_limited() -> None:
    limit = command_guard.MAX_DEPTH
    assert command_guard.ShellCommand("git", ("status",)) in command_guard.shell_commands(
        "eval " * limit + "git status")
    with pytest.raises(command_guard.ShellParseError):
        command_guard.shell_commands("eval " * (limit + 2) + "git status")


# Exact parses where substitution frames, heredoc lifting and quote state meet.
FRAME_PARSES = [
    ('echo "$(case a in a) cat <<\'E\'\n(\nE\n;; esac)"', [('echo', ('nested-command',)), ('cat', ())]),
    ('echo "$( (true) ; cat <<\'E\'\n(\nE\n)"', [('echo', ('nested-command',)), ('true', ()), ('cat', ())]),
    ("cat <(bash <<'E'\ngit commit --no-verify -m msg\nE\n)", [('cat', ('nested-command',)), ('bash', ()), ('git', ('commit', '--no-verify', '-m', 'msg'))]),
    ("echo `echo '\\X'`", [('echo', ('nested-command',)), ('echo', ('\\X',))]),
    ('echo ``; git log', [('echo', ('nested-command',)), ('git', ('log',))]),
    ("echo $(echo '\\')", [('echo', ('nested-command',)), ('echo', ('\\',))]),
    ("echo $(echo '`')", [('echo', ('nested-command',)), ('echo', ('`',))]),
    ('echo $(case a in a) case b in b) x;; esac;; c) git status;; esac)', [('echo', ('nested-command',)), ('x', ()), ('c', ()), ('git', ('status',))]),
    ('echo $(case a in a)case b in b) git status;; esac;; esac)', [('echo', ('nested-command',)), ('git', ('status',))]),
    ('echo $(true;case a in a) git status;; esac)', [('echo', ('nested-command',)), ('true', ()), ('git', ('status',))]),
    ("echo '\\' $(git commit --no-verify -m msg)", [('echo', ('\\', 'nested-command')), ('git', ('commit', '--no-verify', '-m', 'msg'))]),
    ("echo 'a' <(git commit --no-verify -m msg)", [('echo', ('a', 'nested-command')), ('git', ('commit', '--no-verify', '-m', 'msg'))]),
    ('echo "a" <(git commit --no-verify -m msg)', [('echo', ('a', 'nested-command')), ('git', ('commit', '--no-verify', '-m', 'msg'))]),
    ('echo \'"\' <(git commit --no-verify -m msg)', [('echo', ('"', 'nested-command')), ('git', ('commit', '--no-verify', '-m', 'msg'))]),
    ('echo "\'" <(git commit --no-verify -m msg)', [('echo', ("'", 'nested-command')), ('git', ('commit', '--no-verify', '-m', 'msg'))]),
]


@pytest.mark.parametrize(("text", "expected"), FRAME_PARSES,
                         ids=[text for text, _ in FRAME_PARSES])
def test_frame_parses(text: str, expected: list) -> None:
    commands = command_guard.shell_commands(text)
    assert [(c.executable, c.arguments) for c in commands] == expected


def test_unclosed_escaped_backtick_is_unparseable() -> None:
    with pytest.raises(command_guard.ShellParseError):
        command_guard.shell_commands("echo `a\\`")


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
