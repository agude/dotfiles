# /// script
# requires-python = ">=3.10"
# dependencies = ["hypothesis==6.170.14"]
# ///
"""Property tests for Johnny.Decimal skill publication.

Runs under unittest (the Windows job) and pytest alike.
"""

import hashlib
import importlib.util
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))

import hypothesis_profiles  # noqa: E402,F401
from hypothesis import given, settings, strategies as st  # noqa: E402

SPEC = importlib.util.spec_from_file_location(
    'publish_jd', Path(__file__).resolve().parents[1] / 'bin/publish-jd.py')
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)

NAMES = st.sampled_from(['a.md', 'b.txt', 'c', 'jd.sh', 'notes', 'x y.md', 'ü.md'])
CONTENT = st.binary(max_size=16)


@st.composite
def resource_trees(draw):
    """A source tree: SKILL.md plus some resource directories, depth <= 2."""
    tree = {'SKILL.md': draw(CONTENT)}
    for directory in draw(st.sets(st.sampled_from(['references', 'scripts', 'assets']),
                                  max_size=3)):
        for name in draw(st.sets(NAMES, min_size=1, max_size=3)):
            if draw(st.booleans()):
                tree[f'{directory}/{name}'] = draw(CONTENT)
            else:
                tree[f'{directory}/{name}/{draw(NAMES)}'] = draw(CONTENT)
    tree['tests/ignored.txt'] = b'not deployed'
    return tree


def write_tree(root, tree):
    if root.exists():
        shutil.rmtree(root)
    root.mkdir(parents=True)
    for relative, content in tree.items():
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)


def snapshot(root):
    """Every path under root with its type, link target or content hash."""
    result = {}
    for directory, names, files in os.walk(root, followlinks=False):
        for name in names + files:
            path = Path(directory) / name
            relative = path.relative_to(root).as_posix()
            if path.is_symlink():
                result[relative] = 'link:' + os.readlink(path)
            elif path.is_dir():
                result[relative] = 'dir'
            else:
                result[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def can_symlink(root):
    probe = root / 'symlink-probe'
    try:
        probe.symlink_to(root, target_is_directory=True)
    except OSError:
        return False
    probe.unlink()
    return True


class Fixture:
    def __init__(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.source = self.root / 'source'
        self.documents = self.root / 'Documents'
        self.documents.mkdir()
        workspace = self.root / 'workspace'
        workspace.mkdir()
        (workspace / 'AGENTS.md').write_text('Template AGENTS.md', encoding='utf-8')
        self.patch = patch.object(module, 'WORKSPACE', workspace)
        self.patch.start()

    def close(self):
        self.patch.stop()
        self.temporary.cleanup()

    def destination(self, target):
        return self.documents / target / 'skills/johnny-decimal'

    def publish(self, tree, dry_run=False):
        write_tree(self.source, tree)
        module.publish(self.source, self.documents, dry_run)


def quietly(function, *args, **kwargs):
    with patch('builtins.print'):
        return function(*args, **kwargs)


TAMPERS = ['edit-file', 'add-file', 'add-directory', 'remove-manifest', 'lock',
           'symlink-destination', 'symlink-skills', 'symlink-agents']


class PublishProperties(unittest.TestCase):
    def fixture(self):
        fixture = Fixture()
        self.addCleanup(fixture.close)
        return fixture

    @given(resource_trees(), st.one_of(st.none(), resource_trees()))
    def test_dry_run_changes_nothing(self, tree, previous):
        fixture = Fixture()
        try:
            if previous is not None:
                quietly(fixture.publish, previous)
            before = snapshot(fixture.documents)
            quietly(fixture.publish, tree, dry_run=True)
            self.assertEqual(snapshot(fixture.documents), before)
        finally:
            fixture.close()

    @given(resource_trees(), st.one_of(st.none(), resource_trees()))
    def test_publication_is_idempotent_and_exact(self, tree, previous):
        fixture = Fixture()
        try:
            if previous is not None:
                quietly(fixture.publish, previous)
            quietly(fixture.publish, tree)
            after = snapshot(fixture.documents)
            with patch('builtins.print') as output:
                fixture.publish(tree)
            self.assertEqual(snapshot(fixture.documents), after)
            messages = [call.args[0] for call in output.call_args_list]
            self.assertEqual(sum(m.startswith('Already up to date') for m in messages), 2)
            expected = {relative: hashlib.sha256(content).hexdigest()
                        for relative, content in tree.items()
                        if not relative.startswith('tests/')}
            for target in module.TARGETS:
                files = {relative: digest for relative, digest
                         in snapshot(fixture.destination(target)).items()
                         if digest != 'dir' and relative != module.MANIFEST}
                self.assertEqual(files, expected)
        finally:
            fixture.close()

    @given(resource_trees(), st.sampled_from(['byte', 'rename', 'empty-directory', 'same']))
    def test_fingerprint_detects_every_change(self, tree, change):
        with tempfile.TemporaryDirectory() as temporary:
            first, second = Path(temporary) / 'first', Path(temporary) / 'second'
            write_tree(first, tree)
            write_tree(second, tree)
            target = second / 'SKILL.md'
            if change == 'byte':
                target.write_bytes(target.read_bytes() + b'!')
            elif change == 'rename':
                target.rename(second / 'SKILL.markdown')
            elif change == 'empty-directory':
                (second / 'new-directory').mkdir()
            same = module.fingerprint(first) == module.fingerprint(second)
            self.assertEqual(same, change == 'same')

    @given(resource_trees(), resource_trees(), st.sampled_from(module.TARGETS),
           st.sampled_from(TAMPERS))
    def test_refused_publication_changes_nothing(self, old, new, target, tamper):
        fixture = Fixture()
        try:
            if tamper.startswith('symlink') and not can_symlink(fixture.root):
                return
            quietly(fixture.publish, old)
            destination = fixture.destination(target)
            if tamper == 'edit-file':
                (destination / 'SKILL.md').write_bytes(b'local edit')
            elif tamper == 'add-file':
                (destination / 'personal.txt').write_bytes(b'keep')
            elif tamper == 'add-directory':
                (destination / 'personal').mkdir()
            elif tamper == 'remove-manifest':
                (destination / module.MANIFEST).unlink()
            elif tamper == 'lock':
                (fixture.documents / target / '.publish-jd.lock').mkdir()
            else:
                link = {'symlink-destination': destination,
                        'symlink-skills': destination.parent,
                        'symlink-agents': destination.parent.parent}[tamper]
                moved = link.with_name(link.name + '-real')
                link.rename(moved)
                link.symlink_to(moved, target_is_directory=True)
            before = snapshot(fixture.documents)
            changed = dict(new, **{'SKILL.md': new['SKILL.md'] + b'changed'})
            with self.assertRaises(ValueError):
                quietly(fixture.publish, changed)
            self.assertEqual(snapshot(fixture.documents), before)
        finally:
            fixture.close()

    @settings(max_examples=150)
    @given(resource_trees(), resource_trees(),
           st.sampled_from(['rename', 'mkdir', 'copytree', 'copy', 'write_text']), st.data())
    def test_failure_leaves_each_copy_old_or_new(self, old, new, operation, data):
        new = dict(new, **{'SKILL.md': new['SKILL.md'] + b'changed'})
        owner = {'rename': Path, 'mkdir': Path, 'write_text': Path,
                 'copytree': module.shutil, 'copy': module.shutil}[operation]
        calls = {'count': 0, 'fail': None}

        def counting(original):
            def wrapper(*args, **kwargs):
                calls['count'] += 1
                if calls['count'] == calls['fail']:
                    raise OSError('injected failure')
                return original(*args, **kwargs)
            return wrapper

        # A twin update counts the calls, so every drawn index is one that fires.
        twin = Fixture()
        try:
            quietly(twin.publish, old)
            write_tree(twin.source, new)
            with patch.object(owner, operation, counting(getattr(owner, operation))):
                quietly(module.publish, twin.source, twin.documents)
            total = calls['count']
            new_prints = {target: module.fingerprint(twin.destination(target))
                          for target in module.TARGETS}
        finally:
            twin.close()
        if total == 0:
            return
        calls.update(count=0, fail=data.draw(st.integers(1, total), label='failing call'))

        fixture = Fixture()
        try:
            quietly(fixture.publish, old)
            old_prints = {target: module.fingerprint(fixture.destination(target))
                          for target in module.TARGETS}
            # SKILL.md always changes, so "old or new" below allows two states.
            for target in module.TARGETS:
                self.assertNotEqual(old_prints[target], new_prints[target])
            write_tree(fixture.source, new)
            with patch.object(owner, operation, counting(getattr(owner, operation))):
                with self.assertRaises(OSError):
                    quietly(module.publish, fixture.source, fixture.documents)
            self.assertGreaterEqual(calls['count'], calls['fail'])
            for target in module.TARGETS:
                destination = fixture.destination(target)
                current = module.fingerprint(destination)
                self.assertFalse((fixture.documents / target / '.publish-jd.lock').exists())
                self.assertIn(current, (old_prints[target], new_prints[target]),
                              (target, operation, calls['fail']))
                # The manifest still describes the live copy exactly.
                self.assertEqual(module.validate_destination(destination), current)
                backups = fixture.documents / target / 'skill-backups'
                kept = list(backups.iterdir()) if backups.exists() else []
                self.assertLessEqual(len(kept), 1)
                for backup in kept:
                    self.assertEqual(module.fingerprint(backup), old_prints[target])
                    self.assertEqual(current, new_prints[target])
                staging = [p for p in (fixture.documents / target).iterdir()
                           if p.name.startswith('.publish-jd-')]
                self.assertEqual(staging, [])
            # A retry without the fault completes the update.
            quietly(module.publish, fixture.source, fixture.documents)
            for target in module.TARGETS:
                destination = fixture.destination(target)
                self.assertEqual(module.fingerprint(destination), new_prints[target])
                self.assertEqual(module.validate_destination(destination), new_prints[target])
        finally:
            fixture.close()

if __name__ == '__main__':
    unittest.main()
