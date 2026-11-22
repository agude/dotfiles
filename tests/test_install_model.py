# /// script
# requires-python = ">=3.10"
# dependencies = ["pytest==9.1.1"]
# ///
"""Enumerated state model for install.sh link placement and cleanup.

Each case builds a fixture repository, places one target per starting
state, and runs the installer twice (a profile or link-map transition, in
normal or dry-run mode). The whole domain is small, so it is enumerated
rather than sampled. Set BASH_UNDER_TEST to run the installer under a
specific Bash (the CI job uses Bash 3.2).
"""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import pytest

sys.dont_write_bytecode = True

REPOSITORY = Path(__file__).resolve().parents[1]
BASH = os.environ.get("BASH_UNDER_TEST", "bash")

TARGET_STATES = [
    "absent", "correct", "owned-wrong", "owned-dangling", "foreign-file", "foreign-dangling",
    "real-file", "real-directory", "parent-foreign-link", "parent-owned-link",
    "owned-text-escaping", "foreign-sibling-prefix",
]
SOURCE_STATES = ["present", "missing"]
TRANSITIONS = ["same", "disable", "enable", "remove-rows"]
MODES = ["normal", "dry-run"]

DEFAULT_PROFILE = """INSTALL_SHELL=false
INSTALL_VIM=false
INSTALL_GIT=false
INSTALL_SCRIPTS=false
INSTALL_GUI=false
INSTALL_LLM=false
INSTALL_CLEANUP=false
INSTALL_FIXTURE=true

CLAUDE_SETTINGS_REL=""
CODEX_SETTINGS_REL=""
CODEX_AGENTS_REL=""
PI_AGENTS_REL=""
"""


class World:
    """A fixture repository and HOME with one target per (state, source)."""

    def __init__(self, root: Path) -> None:
        self.root = root
        # Spaces and glob characters in every path catch unquoted expansions.
        self.repository = root / "dot files [1]"
        self.home = root / "home dir [2]"
        self.outside = root / "outside"
        self.sibling = root / "dot files [1]-sibling"
        for path in (self.repository / "profiles", self.repository / "fixture",
                     self.repository / "shared/sharedrc.d", self.home, self.outside,
                     self.sibling):
            path.mkdir(parents=True)
        shutil.copy(REPOSITORY / "install.sh", self.repository / "install.sh")
        (self.repository / "shared/sharedrc.d/000.set_platform.sh").write_text(
            "export PLATFORM=linux\n")
        shutil.copy(REPOSITORY / "shared/sharedrc.d/001.xdg_base_directory.sh",
                    self.repository / "shared/sharedrc.d/001.xdg_base_directory.sh")
        (self.repository / "profiles/default.sh").write_text(DEFAULT_PROFILE)
        (self.repository / "profiles/disabled.sh").write_text("INSTALL_FIXTURE=false\n")
        (self.outside / "foreign file").write_text("foreign\n")
        self.rows: list[tuple[str, str, str]] = []
        for state in TARGET_STATES:
            for source in SOURCE_STATES:
                self.add_case(state, source)

    def target(self, state: str, source: str) -> Path:
        return self.home / f"model {state} {source}" / "target"

    def add_case(self, state: str, source: str) -> None:
        name = f"fixture/{state} {source}"
        if source == "present":
            (self.repository / name).write_text(f"{state} {source}\n")
        target = self.target(state, source)
        parent = target.parent
        if state == "parent-foreign-link":
            real = self.outside / f"parent {source}"
            real.mkdir()
            (real / "keep").write_text("foreign parent\n")
            parent.symlink_to(real)
        elif state == "parent-owned-link":
            real = self.repository / "fixture" / f"old parent {source}"
            real.mkdir()
            parent.symlink_to(real)
        else:
            parent.mkdir()
        if state == "correct":
            target.symlink_to(self.repository / name)
        elif state == "owned-wrong":
            other = self.repository / "fixture/other"
            other.write_text("other\n")
            target.symlink_to(other)
        elif state == "owned-dangling":
            target.symlink_to(self.repository / "fixture/gone")
        elif state == "foreign-file":
            target.symlink_to(self.outside / "foreign file")
        elif state == "foreign-dangling":
            target.symlink_to(self.outside / "nothing here")
        elif state == "real-file":
            target.write_text("local edits\n")
        elif state == "real-directory":
            target.mkdir()
            (target / "marker").write_text("local directory\n")
        elif state == "owned-text-escaping":
            target.symlink_to(f"{self.repository}/../outside/foreign file")
        elif state == "foreign-sibling-prefix":
            (self.sibling / f"file {source}").write_text("sibling\n")
            target.symlink_to(self.sibling / f"file {source}")
        self.rows.append(("${HOME}/" + str(target.relative_to(self.home)), name, "fixture"))

    def write_link_map(self, rows: list[tuple[str, str, str]]) -> None:
        lines = [f"{target} | {source} | {groups}" for target, source, groups in rows]
        (self.repository / "links.conf").write_text("\n".join(lines) + "\n")

    def run(self, *arguments: str) -> subprocess.CompletedProcess:
        environment = {
            "PATH": os.environ["PATH"], "HOME": str(self.home),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_CACHE_HOME": str(self.home / ".cache"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "XDG_STATE_HOME": str(self.home / ".local/state"),
        }
        result = subprocess.run([BASH, str(self.repository / "install.sh"), *arguments],
                                env=environment, stdin=subprocess.DEVNULL,
                                capture_output=True, text=True, timeout=120)
        assert result.returncode == 0, result.stdout + result.stderr
        return result

    def manifest(self) -> list[str]:
        path = self.repository / ".link-manifest"
        return path.read_text().splitlines() if path.exists() else []

    def is_owned(self, link_text: str) -> bool:
        """Ownership by normalized location, not by the text prefix."""
        repository = os.path.normpath(str(self.repository))
        return os.path.normpath(link_text).startswith(repository + os.sep)


def snapshot(*roots: Path) -> dict[str, tuple]:
    """Path -> ('link', text) | ('dir',) | ('file', sha256), without following links."""
    result: dict[str, tuple] = {}
    for root in roots:
        for directory, names, files in os.walk(root, followlinks=False):
            for name in [*names, *files]:
                path = Path(directory) / name
                if path.is_symlink():
                    result[str(path)] = ("link", os.readlink(path))
                elif path.is_dir():
                    result[str(path)] = ("dir",)
                else:
                    result[str(path)] = ("file", hashlib.sha256(path.read_bytes()).hexdigest())
    return result


def repository_state(world: World) -> dict[str, str]:
    state = {}
    for name in (".link-manifest", ".active-profile"):
        path = world.repository / name
        state[name] = path.read_text() if path.exists() else None
    return state


def check_no_destruction(world: World, before: dict, after: dict) -> None:
    """Everything not owned by the repository survives, in place or as one backup."""
    for path, entry in before.items():
        if entry[0] == "link" and world.is_owned(entry[1]):
            continue
        if after.get(path) == entry:
            continue
        found = False
        current = Path(path)
        relative = Path()
        while True:
            backups = [candidate for candidate in after
                       if Path(candidate).parent == current.parent
                       and Path(candidate).name.startswith(current.name + ".dotfiles-backup.")]
            for backup in backups:
                if after.get(str(Path(backup) / relative) if relative.parts else backup) == entry:
                    found = True
            if found or current.parent == world.home or current == current.parent:
                break
            relative = Path(current.name) / relative
            current = current.parent
        assert found, f"{path} {entry} was destroyed"


def check_backups(world: World, before: dict, after: dict) -> None:
    """Owned links are replaced without a backup; anything else gets exactly one."""
    for path in {*before, *after}:
        if ".dotfiles-backup." in path:
            continue
        new_backups = [candidate for candidate in after
                       if candidate.startswith(path + ".dotfiles-backup.")
                       and candidate.count(".dotfiles-backup.") == 1
                       and Path(candidate).parent == Path(path).parent
                       and candidate not in before]
        entry = before.get(path)
        if entry is None or (entry[0] == "link" and world.is_owned(entry[1])):
            assert new_backups == [], (path, new_backups)
        else:
            assert len(new_backups) <= 1, (path, new_backups)


def check_links(world: World, before: dict, after: dict, enabled: bool) -> None:
    for target, source, _ in world.rows:
        path = Path(target.replace("${HOME}", str(world.home)))
        present = (world.repository / source).exists()
        if enabled and present:
            assert after.get(str(path)) == ("link", str(world.repository / source)), path
            assert not path.parent.is_symlink(), path
        if not present:
            if before.get(str(path)) is None or not (
                    before[str(path)][0] == "link" and world.is_owned(before[str(path)][1])):
                assert after.get(str(path)) == before.get(str(path)), path
            assert str(path) not in world.manifest()


def check_cleanup(world: World, before: dict, after: dict, old: list[str], new: list[str]) -> None:
    removed = {path for path, entry in before.items() if path not in after and entry[0] == "link"}
    expected = {path for path in set(old) - set(new)
                if before.get(path, ("",))[0] == "link" and world.is_owned(before[path][1])}
    stale_removed = {path for path in removed if path in set(old) - set(new)}
    assert stale_removed == expected


CASES = [(transition, mode) for transition in TRANSITIONS for mode in MODES]


@pytest.mark.parametrize(("transition", "mode"), CASES, ids=[f"{t}-{m}" for t, m in CASES])
def test_install_transitions(tmp_path: Path, transition: str, mode: str) -> None:
    world = World(tmp_path)
    world.write_link_map(world.rows)
    first_profile = "disabled" if transition == "enable" else "default"
    before_first = snapshot(world.home, world.outside)
    world.run("--profile", first_profile)
    after_first = snapshot(world.home, world.outside)
    check_no_destruction(world, before_first, after_first)
    check_backups(world, before_first, after_first)
    check_links(world, before_first, after_first, enabled=first_profile == "default")

    old_manifest = world.manifest()
    second_profile = {"same": "default", "disable": "disabled", "enable": "default",
                      "remove-rows": "default"}[transition]
    if transition == "remove-rows":
        world.write_link_map(world.rows[::2])
    before = snapshot(world.home, world.outside)
    repository_before = repository_state(world)
    arguments = ["--profile", second_profile] + (["--dry-run"] if mode == "dry-run" else [])
    result = world.run(*arguments)
    after = snapshot(world.home, world.outside)

    if mode == "dry-run":
        assert after == before
        assert repository_state(world) == repository_before
        return
    check_no_destruction(world, before, after)
    check_backups(world, before, after)
    new_manifest = world.manifest()
    check_cleanup(world, before, after, old_manifest, new_manifest)
    if transition == "same":
        assert after == before
        assert new_manifest == old_manifest
        for word in ("Backing up", "Updating", "Linking", "Cleaning up"):
            assert word not in result.stdout
    if transition == "enable":
        check_links(world, before, after, enabled=True)


def test_first_run_dry_run_changes_nothing(tmp_path: Path) -> None:
    world = World(tmp_path)
    world.write_link_map(world.rows)
    before = snapshot(world.home, world.outside)
    repository_before = repository_state(world)
    world.run("--profile", "default", "--dry-run")
    assert snapshot(world.home, world.outside) == before
    assert repository_state(world) == repository_before


def test_expand_vars_resolves_every_real_target(tmp_path: Path) -> None:
    home = tmp_path / "home"
    script = f"""
set -eu
HOME={home}
XDG_CONFIG_HOME={home}/.config
source {REPOSITORY}/profiles/default.sh
eval "$(sed -n '/^expand_vars() {{/,/^}}/p' {REPOSITORY}/install.sh)"
while IFS='|' read -r target source groups; do
    target="${{target#"${{target%%[! ]*}}"}}"; target="${{target%"${{target##*[! ]}}"}}"
    [[ -z "$target" || "$target" == "#"* ]] && continue
    expand_vars "$target"; echo
done < {REPOSITORY}/links.conf
"""
    output = subprocess.run([BASH, "-c", script], capture_output=True, text=True, check=True)
    targets = output.stdout.split()
    assert targets
    for target in targets:
        assert "$" not in target, target
        assert target.startswith(str(home) + "/"), target


if __name__ == "__main__":
    raise SystemExit(pytest.main([__file__, *sys.argv[1:]]))
