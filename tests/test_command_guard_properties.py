# /// script
# requires-python = ">=3.10"
# dependencies = ["pytest==9.1.1", "hypothesis==6.170.14"]
# ///
"""Property tests for the shared command guard.

The generated programs carry their own expected leaves (see
shell_strategies.py), so every decision here is checked against labels
computed from the generator's structure, never from the parser under test.
Two further tests check the generator against reality: one runs generated
programs under bash with stub git and gh executables, and one replays the
labeled Git leaves against a real repository.
"""

from __future__ import annotations

import importlib.util
import io
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile

import pytest
from hypothesis import given, settings, strategies as st

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))

import hypothesis_profiles  # noqa: E402,F401
from shell_strategies import (  # noqa: E402
    LEAVES, RANK, expected_gh_rank, expected_git_block, programs)

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
GUARD_PATH = REPOSITORY_ROOT / "llm/claude/hooks.d/command_guard.py"
MODULE_SPEC = importlib.util.spec_from_file_location("command_guard", GUARD_PATH)
assert MODULE_SPEC is not None and MODULE_SPEC.loader is not None
command_guard = importlib.util.module_from_spec(MODULE_SPEC)
sys.modules[MODULE_SPEC.name] = command_guard
MODULE_SPEC.loader.exec_module(command_guard)


def git_decision(text: str) -> bool:
    """What the git-bypass hook does: block on bypass or on parse failure."""
    try:
        commands = command_guard.shell_commands(text)
    except command_guard.ShellParseError:
        return True
    return command_guard.git_bypass_blocked(commands)


def gh_rank(text: str) -> int:
    """What the gh hook does: ask on parse failure, else classify."""
    try:
        commands = command_guard.shell_commands(text)
    except command_guard.ShellParseError:
        return RANK["ask"]
    decision = command_guard.gh_decision(commands)
    return RANK[decision[0] if decision else None]


def as_command(argv: tuple[str, ...]):
    return command_guard.ShellCommand(os.path.basename(argv[0]), tuple(argv[1:]))


# --- the generator is honest ----------------------------------------------


@given(programs())
def test_generated_programs_are_valid_bash(program) -> None:
    result = subprocess.run(["bash", "-n"], input=program.text, text=True,
                            capture_output=True)
    assert result.returncode == 0, (program.text, result.stderr)


# --- decisions match labels -----------------------------------------------


@given(programs())
def test_git_decision_matches_labeled_leaves(program) -> None:
    assert git_decision(program.text) == expected_git_block(program), program


@given(programs())
def test_gh_decision_matches_labeled_leaves(program) -> None:
    assert gh_rank(program.text) == expected_gh_rank(program), program


@given(programs())
def test_every_reachable_git_and_gh_leaf_is_parsed(program) -> None:
    if program.opaque:
        return
    commands = command_guard.shell_commands(program.text)
    for leaf in program.reachable:
        if os.path.basename(leaf.argv[0]) in {"git", "gh"}:
            assert as_command(leaf.argv) in commands, (program.text, commands)


@given(programs(), programs())
def test_decisions_do_not_depend_on_order(first, second) -> None:
    def joined(a, b):
        return a.text + ("\n" if a.heredoc else "\n") + b.text

    assert git_decision(joined(first, second)) == git_decision(joined(second, first))
    assert gh_rank(joined(first, second)) == gh_rank(joined(second, first))


# --- robustness ------------------------------------------------------------

SHELL_ALPHABET = st.sampled_from(list("ab -'\"\\$`()<>|&;{}!#\n\t=") + ["<<", "$(", "$'"])


@given(st.lists(st.one_of(SHELL_ALPHABET, st.text(max_size=3)), max_size=40).map("".join))
def test_parser_fails_closed_on_arbitrary_text(text: str) -> None:
    try:
        command_guard.shell_commands(text)
    except command_guard.ShellParseError:
        pass


@given(st.integers(0, 3000), st.sampled_from(["$(", "<("]))
def test_deep_nesting_is_rejected_not_crashed(depth: int, opener: str) -> None:
    text = "echo " + (opener + "echo ") * depth + "git status" + ")" * depth
    try:
        command_guard.shell_commands(text)
    except command_guard.ShellParseError:
        assert depth > 50


SAFE_EXECUTABLES = st.sampled_from(["printf", "cat", "ls", "mytool", "./run.sh"])
ARGUMENT = st.text(st.characters(blacklist_characters="\x00",
                                 blacklist_categories=("Cs",)), min_size=1, max_size=12)


@given(SAFE_EXECUTABLES, st.lists(ARGUMENT, max_size=6))
def test_quoted_words_round_trip(executable: str, arguments: list[str]) -> None:
    text = shlex.join([executable, *arguments])
    assert command_guard.shell_commands(text) == [as_command((executable, *arguments))]


# --- hook entry point ------------------------------------------------------

JSON = st.recursive(
    st.none() | st.booleans() | st.integers() | st.text(max_size=5),
    lambda inner: st.lists(inner, max_size=3) | st.dictionaries(st.text(max_size=5), inner,
                                                                max_size=3),
    max_leaves=6,
)
PAYLOADS = st.one_of(
    JSON.map(json.dumps),
    st.text(max_size=20),
    st.dictionaries(st.just("tool_input"), JSON).map(json.dumps),
    programs().map(lambda program: json.dumps({"tool_input": {"command": program.text}})),
)


def run_main(mode: str, payload: str) -> tuple[int, str, str]:
    old = sys.argv, sys.stdin, sys.stdout, sys.stderr
    sys.argv = ["command_guard.py", mode]
    sys.stdin = io.StringIO(payload)
    sys.stdout, sys.stderr = io.StringIO(), io.StringIO()
    try:
        status = command_guard.main()
        return status, sys.stdout.getvalue(), sys.stderr.getvalue()
    finally:
        sys.argv, sys.stdin, sys.stdout, sys.stderr = old


@given(PAYLOADS)
def test_git_hook_contract(payload: str) -> None:
    status, out, err = run_main("git-bypass", payload)
    assert out == ""
    assert (status, bool(err)) in {(0, False), (2, True)}
    try:
        command = json.loads(payload)["tool_input"]["command"]
        assert isinstance(command, str)
    except (ValueError, KeyError, TypeError, AssertionError):
        assert status == 2


@given(PAYLOADS)
def test_gh_hook_contract(payload: str) -> None:
    status, out, err = run_main("gh", payload)
    assert status == 0 and err == ""
    if out:
        lines = out.splitlines()
        assert len(lines) == 1
        decision = json.loads(lines[0])["hookSpecificOutput"]
        assert decision["hookEventName"] == "PreToolUse"
        assert decision["permissionDecision"] in {"allow", "ask", "deny"}
        assert decision["permissionDecisionReason"]
    try:
        command = json.loads(payload)["tool_input"]["command"]
        assert isinstance(command, str)
    except (ValueError, KeyError, TypeError, AssertionError):
        assert json.loads(out)["hookSpecificOutput"]["permissionDecision"] == "ask"


# --- the generator matches bash -------------------------------------------

STUB = """#!/bin/sh
{ printf '%s\\0' "$(basename "$0")" "$@"; printf '\\036'; } >> "$STUB_LOG"
"""


@pytest.fixture(scope="module")
def stub_directory():
    with tempfile.TemporaryDirectory() as temporary:
        bin_directory = Path(temporary) / "bin"
        bin_directory.mkdir()
        for name in ("git", "gh"):
            path = bin_directory / name
            path.write_text(STUB)
            path.chmod(0o755)
        yield bin_directory


@settings(max_examples=100)
@given(programs())
def test_bash_runs_only_reachable_leaves(stub_directory, program) -> None:
    if not program.executable or program.opaque:
        return
    with tempfile.TemporaryDirectory() as temporary:
        log = Path(temporary) / "log"
        log.touch()
        environment = {
            "PATH": f"{stub_directory}:/usr/bin:/bin",
            "HOME": temporary,
            "STUB_LOG": str(log),
            "GIT_CEILING_DIRECTORIES": temporary,
        }
        subprocess.run(["bash", "-c", program.text], cwd=temporary, env=environment,
                       stdin=subprocess.DEVNULL, capture_output=True, timeout=20)
        records = [record for record in log.read_bytes().split(b"\x1e") if record]
    executed = {tuple(part.decode() for part in record.split(b"\0")[:-1])
                for record in records}
    expected = {as_command(leaf.argv) for leaf in program.reachable}
    for argv in executed:
        assert as_command(argv) in expected, (program.text, argv)


# --- the labels match Git --------------------------------------------------

GPG_STUB = """#!/bin/sh
touch "$SIGNED_MARKER"
cat > /dev/null
echo '[GNUPG:] SIG_CREATED ' >&2
printf -- '-----BEGIN PGP SIGNATURE-----\\nstub\\n-----END PGP SIGNATURE-----\\n'
"""


def _git_outcome(argv: tuple[str, ...], root: Path) -> bool:
    """Return True when real Git commits while skipping a hook or signing."""
    repository = root / "repository"
    shutil.rmtree(repository, ignore_errors=True)
    repository.mkdir()
    hook_marker, sign_marker = root / "hook-ran", root / "signed"
    gpg = root / "gpg"
    gpg.write_text(GPG_STUB)
    gpg.chmod(0o755)
    environment = {"PATH": os.environ["PATH"], "HOME": str(root),
                   "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1",
                   "SIGNED_MARKER": str(sign_marker)}

    def git(*arguments: str) -> subprocess.CompletedProcess:
        return subprocess.run(["git", *arguments], cwd=repository, env=environment,
                              capture_output=True, text=True)

    git("init", "-q")
    for key, value in [("user.name", "Test"), ("user.email", "test@example.com"),
                       ("commit.gpgsign", "true"), ("gpg.program", str(gpg)),
                       ("user.signingkey", "stub")]:
        git("config", key, value)
    hook = repository / ".git/hooks/pre-commit"
    hook.write_text(f"#!/bin/sh\ntouch '{hook_marker}'\n")
    hook.chmod(0o755)
    (repository / "file").write_text("one\n")
    git("add", "file")
    git("commit", "-q", "-m", "initial")
    (repository / "file").write_text("two\n")
    git("add", "file")
    for marker in (hook_marker, sign_marker):
        marker.unlink(missing_ok=True)
    before = git("rev-parse", "HEAD").stdout
    result = git(*argv[1:])
    committed = result.returncode == 0 and git("rev-parse", "HEAD").stdout != before
    return committed and not (hook_marker.exists() and sign_marker.exists())


@pytest.mark.skipif(shutil.which("git") is None, reason="git is not installed")
@pytest.mark.parametrize("leaf", [leaf for leaf in LEAVES if leaf.checked],
                         ids=lambda leaf: " ".join(leaf.argv))
def test_git_labels_match_real_git(leaf, tmp_path) -> None:
    assert _git_outcome(leaf.argv, tmp_path) == (leaf.git == "block")


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, *sys.argv[1:]]))
