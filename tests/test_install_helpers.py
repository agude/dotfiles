# /// script
# requires-python = ">=3.10"
# dependencies = ["pytest==9.1.1"]
# ///
"""Function-level state tables for install.sh helpers.

The helpers are extracted from install.sh with sed and called directly, so
every starting state of a target can be checked without a full install.
Paths contain spaces and glob characters to expose unquoted expansions.
BASH_UNDER_TEST selects the Bash.
"""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys

import pytest

sys.dont_write_bytecode = True

REPOSITORY = Path(__file__).resolve().parents[1]
BASH = os.environ.get("BASH_UNDER_TEST", "bash")
HELPERS = ["run", "_normalize_path", "_is_owned_symlink", "_backup_target", "_place_link",
           "link", "ensure_real_dir", "install_local_config", "install_managed_copy",
           "install_group", "any_group_enabled", "expand_vars"]

HARNESS = r"""
set -eu
# A permissive umask makes the helpers' own chmod calls observable.
umask 022
DRY_RUN="$1"; DOTFILES_DIR="$2"; shift 2
MANAGED_LINKS=()
eval "$(sed -n "$SED_SCRIPT" "$INSTALL_SH")"
# Keep install.sh's errexit semantics: a failing command ends the run.
trap 'printf "%s\n" ${MANAGED_LINKS[@]+"${MANAGED_LINKS[@]}"} > "$MANIFEST_OUT"' EXIT
"$@"
"""


def call(root: Path, *command: str, dry_run: bool = False, environment=None):
    sed = ";".join(f"/^{name}() {{/,/^}}/p" for name in HELPERS)
    env = {"PATH": os.environ["PATH"], "SED_SCRIPT": sed,
           "INSTALL_SH": str(REPOSITORY / "install.sh"),
           "MANIFEST_OUT": str(root / "manifest.out"), "HOME": str(root / "home")}
    env.update(environment or {})
    repository = root / "dot files [1]"
    return subprocess.run(
        [BASH, "-c", HARNESS, "harness", "true" if dry_run else "false", str(repository),
         *command], env=env, capture_output=True, text=True, timeout=60)


def tree(root: Path) -> dict[str, tuple]:
    result = {}
    for directory, names, files in os.walk(root, followlinks=False):
        for name in [*names, *files]:
            path = Path(directory) / name
            relative = str(path.relative_to(root))
            if relative == "manifest.out":
                continue
            if path.is_symlink():
                result[relative] = ("link", os.readlink(path))
            elif path.is_dir():
                result[relative] = ("dir",)
            else:
                result[relative] = ("file", path.read_bytes(), path.stat().st_mode & 0o777)
    return result


@pytest.fixture
def world(tmp_path: Path) -> Path:
    repository = tmp_path / "dot files [1]"
    (repository / "config").mkdir(parents=True)
    (repository / "config/template").write_text("template\n")
    (repository / "config/other").write_text("other\n")
    # Repository files are world-readable; installed configs must be narrowed.
    (repository / "config/template").chmod(0o644)
    (repository / "config/other").chmod(0o644)
    (tmp_path / "home").mkdir()
    (tmp_path / "outside").mkdir()
    (tmp_path / "outside/foreign").write_text("foreign\n")
    return tmp_path


TARGET_STATES = ["absent", "same-file", "different-file", "owned-link", "owned-dangling",
                 "foreign-link", "foreign-dangling", "directory", "parent-owned-link",
                 "parent-foreign-link"]


def place(world: Path, state: str) -> Path:
    repository = world / "dot files [1]"
    parent = world / "home" / "conf dir [x]"
    if state == "parent-owned-link":
        (repository / "old parent").mkdir()
        parent.symlink_to(repository / "old parent")
    elif state == "parent-foreign-link":
        (world / "outside/parent").mkdir()
        parent.symlink_to(world / "outside/parent")
    else:
        parent.mkdir()
    target = parent / "target file"
    if state == "same-file":
        target.write_text("template\n")
    elif state == "different-file":
        target.write_text("local edits\n")
    elif state == "owned-link":
        target.symlink_to(repository / "config/other")
    elif state == "owned-dangling":
        target.symlink_to(repository / "config/gone")
    elif state == "foreign-link":
        target.symlink_to(world / "outside/foreign")
    elif state == "foreign-dangling":
        target.symlink_to(world / "outside/nothing")
    elif state == "directory":
        target.mkdir()
        (target / "keep").write_text("keep\n")
    return target


def backups(path: Path) -> list[Path]:
    return sorted(p for p in path.parent.iterdir() if p.name.startswith(path.name + ".dotfiles-backup."))


# --- install_managed_copy ----------------------------------------------------

MANAGED_COPY_RESULT = {
    # state: (target is a fresh 0644 copy, backups of the target, backups of the parent)
    "absent": (True, 0, 0), "same-file": ("unchanged", 0, 0), "different-file": (True, 1, 0),
    "owned-link": (True, 0, 0), "owned-dangling": (True, 0, 0), "foreign-link": (True, 1, 0),
    "foreign-dangling": (True, 1, 0), "directory": (True, 1, 0),
    "parent-owned-link": (True, 0, 0), "parent-foreign-link": (True, 0, 1),
}


@pytest.mark.parametrize("dry_run", [False, True], ids=["normal", "dry-run"])
@pytest.mark.parametrize("state", TARGET_STATES)
def test_install_managed_copy(world: Path, state: str, dry_run: bool) -> None:
    target = place(world, state)
    before = tree(world)
    source = world / "dot files [1]/config/template"
    result = call(world, "install_managed_copy", str(target), str(source), dry_run=dry_run)
    assert result.returncode == 0, result.stderr
    if dry_run:
        assert tree(world) == before
        return
    fresh, target_backups, parent_backups = MANAGED_COPY_RESULT[state]
    if fresh == "unchanged":
        assert tree(world) == before
        return
    assert not target.is_symlink() and target.read_text() == "template\n"
    assert target.stat().st_mode & 0o777 == 0o644
    assert not target.parent.is_symlink()
    assert len(backups(target)) == target_backups, result.stdout
    assert len(backups(target.parent)) == parent_backups, result.stdout
    leftovers = [p for p in target.parent.iterdir() if ".dotfiles-tmp." in p.name]
    assert leftovers == []


def test_install_managed_copy_skips_missing_source(world: Path) -> None:
    target = place(world, "different-file")
    before = tree(world)
    result = call(world, "install_managed_copy", str(target), str(world / "missing"))
    assert result.returncode == 0
    assert "source does not exist" in result.stderr
    assert tree(world) == before


# --- install_local_config ----------------------------------------------------

LOCAL_CONFIG_RESULT = {
    # state: what the target holds afterwards
    "absent": "template", "same-file": "unchanged", "different-file": "unchanged",
    "owned-link": "migrated", "owned-dangling": "template", "foreign-link": "unchanged",
    "foreign-dangling": "unchanged", "directory": "unchanged",
    "parent-owned-link": "template", "parent-foreign-link": "template",
}


@pytest.mark.parametrize("dry_run", [False, True], ids=["normal", "dry-run"])
@pytest.mark.parametrize("state", TARGET_STATES)
def test_install_local_config(world: Path, state: str, dry_run: bool) -> None:
    target = place(world, state)
    before = tree(world)
    source = world / "dot files [1]/config/template"
    result = call(world, "install_local_config", str(target), str(source), dry_run=dry_run)
    expected = LOCAL_CONFIG_RESULT[state]
    assert result.returncode == 0, result.stderr
    if dry_run:
        assert tree(world) == before
        return
    assert result.returncode == 0, result.stderr
    if expected == "unchanged":
        assert tree(world) == before
        if state.startswith("foreign"):
            assert "foreign config symlink" in result.stderr
        return
    assert not target.is_symlink() and target.is_file()
    assert target.stat().st_mode & 0o777 == 0o600
    content = "other\n" if expected == "migrated" else "template\n"
    assert target.read_text() == content
    assert backups(target) == []
    assert not [p for p in target.parent.iterdir() if ".dotfiles-migration." in p.name]
    if state == "parent-foreign-link":
        assert len(backups(target.parent)) == 1
        assert (world / "outside/parent").is_dir()


def test_install_local_config_skips_missing_template(world: Path) -> None:
    target = place(world, "absent")
    before = tree(world)
    result = call(world, "install_local_config", str(target), str(world / "missing"))
    assert result.returncode == 0
    assert "config template does not exist" in result.stderr
    assert tree(world) == before


# --- ensure_real_dir and link ---------------------------------------------------


@pytest.mark.parametrize("dry_run", [False, True], ids=["normal", "dry-run"])
@pytest.mark.parametrize("state", ["absent", "directory", "owned-link", "foreign-link"])
def test_ensure_real_dir(world: Path, state: str, dry_run: bool) -> None:
    repository = world / "dot files [1]"
    directory = world / "home" / "dir [y]"
    if state == "directory":
        directory.mkdir()
        (directory / "keep").write_text("keep\n")
    elif state == "owned-link":
        (repository / "managed").mkdir()
        directory.symlink_to(repository / "managed")
    elif state == "foreign-link":
        (world / "outside/dir").mkdir()
        directory.symlink_to(world / "outside/dir")
    before = tree(world)
    result = call(world, "ensure_real_dir", str(directory), dry_run=dry_run)
    assert result.returncode == 0, result.stderr
    if dry_run:
        assert tree(world) == before
        return
    assert directory.is_dir() and not directory.is_symlink()
    assert len(backups(directory)) == (1 if state == "foreign-link" else 0)
    if state == "directory":
        assert (directory / "keep").read_text() == "keep\n"
    if state == "owned-link":
        assert (repository / "managed").is_dir()


def test_link_rejects_empty_source(world: Path) -> None:
    result = call(world, "link", str(world / "home/target"), "")
    assert result.returncode == 1
    assert "empty source" in result.stderr
    assert not (world / "home/target").exists()
    assert (world / "manifest.out").read_text() == "\n"


def test_link_records_target_and_links_into_repository(world: Path) -> None:
    target = world / "home/linked [z]"
    result = call(world, "link", str(target), "config/template")
    assert result.returncode == 0, result.stderr
    assert os.readlink(target) == str(world / "dot files [1]/config/template")
    assert (world / "manifest.out").read_text() == f"{target}\n"


# --- pure helpers ----------------------------------------------------------------


@pytest.mark.parametrize(("path", "expected"), [
    ("/a/b/../c", "/a/c"), ("/a/./b//", "/a/b"), ("/..", "/"), ("/", "/"), ("", "/"),
    ("/a/../..", "/"), ("/x y/../z [1]", "/z [1]"), ("/a/*/b", "/a/*/b"),
    ("/a b/c d/../../e", "/e"),
])
def test_normalize_path(world: Path, path: str, expected: str) -> None:
    result = call(world, "_normalize_path", path)
    assert result.returncode == 0, result.stderr
    assert result.stdout == expected


@pytest.mark.parametrize(("link", "owned"), [
    ("{repo}/config/other", True), ("{repo}/config/gone", True),
    ("{repo}/../outside/foreign", False), ("{repo}-sibling/x", False),
    ("{root}/outside/foreign", False), ("../dot files [1]/config/other", True),
    ("{repo}", False),
])
def test_is_owned_symlink(world: Path, link: str, owned: bool) -> None:
    repository = world / "dot files [1]"
    target = world / "home/probe link"
    target.symlink_to(link.format(repo=repository, root=world))
    result = call(world, "_is_owned_symlink", str(target), str(repository))
    assert (result.returncode == 0) == owned


def test_is_owned_symlink_rejects_regular_files(world: Path) -> None:
    (world / "home/regular").write_text("x")
    assert call(world, "_is_owned_symlink", str(world / "home/regular"),
                str(world / "dot files [1]")).returncode == 1


@pytest.mark.parametrize(("groups", "enabled"), [
    ("*", True), ("alpha", True), ("beta", False), ("beta, alpha", True),
    (" alpha ", True), ("beta,gamma", False), ("", False), (" , ", False),
])
def test_any_group_enabled(world: Path, groups: str, enabled: bool) -> None:
    result = call(world, "any_group_enabled", groups,
                  environment={"INSTALL_ALPHA": "true", "INSTALL_BETA": "false",
                               "INSTALL_GAMMA": "false"})
    assert (result.returncode == 0) == enabled, result.stderr


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, *sys.argv[1:]]))
