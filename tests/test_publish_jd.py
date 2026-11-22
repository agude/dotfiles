# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Exercise publication against temporary source and destination trees."""

import contextlib
import hashlib
import importlib.util
import io
import os
import subprocess
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True

SPEC = importlib.util.spec_from_file_location(
    'publish_jd', Path(__file__).resolve().parents[1] / 'bin/publish-jd.py')
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


class PublishTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        (self.source / 'SKILL.md').write_text('version one')
        (self.source / 'scripts').mkdir()
        script = self.source / 'scripts/jd.sh'
        script.write_text('#!/bin/bash\n')
        script.chmod(0o755)
        (self.source / 'tests').mkdir()
        (self.source / 'tests/test.txt').write_text('not deployed')
        self.documents = self.root / 'Documents with spaces'
        self.documents.mkdir()
        self.destination = self.documents / '.agents/skills/johnny-decimal'
        self.claude_destination = self.documents / '.claude/skills/johnny-decimal'
        workspace = self.root / 'workspace'
        workspace.mkdir()
        (workspace / 'AGENTS.md').write_text('Template AGENTS.md', encoding='utf-8')
        workspace_patch = patch.object(module, 'WORKSPACE', workspace)
        workspace_patch.start()
        self.addCleanup(workspace_patch.stop)

    def publish(self, dry_run=False):
        module.publish(self.source, self.documents, dry_run)

    def publish_output(self, dry_run=False):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            self.publish(dry_run)
        return output.getvalue().splitlines()

    def test_fingerprint_format_is_stable(self):
        # Published manifests on shared drives use this format; it must not drift.
        tree = self.root / 'tree'
        (tree / 'scripts').mkdir(parents=True)
        (tree / 'SKILL.md').write_bytes(b'skill')
        (tree / 'scripts/jd.sh').write_bytes(b'run')
        (tree / module.MANIFEST).write_text('{}')
        self.assertEqual(module.fingerprint(tree), {
            'SKILL.md': hashlib.sha256(b'skill').hexdigest(),
            'scripts/': 'directory',
            'scripts/jd.sh': hashlib.sha256(b'run').hexdigest(),
        })

    def test_output_reports_each_change(self):
        # publish() reports resolved paths (macOS /var and Windows 8.3 names differ).
        documents = self.documents.resolve()
        destination = documents / '.agents/skills/johnny-decimal'
        lines = self.publish_output()
        for target in (destination, documents / '.claude/skills/johnny-decimal'):
            self.assertIn(f'Published: {target}', lines)
        self.assertEqual(lines.count('Copy: SKILL.md'), 2)
        self.assertEqual(lines.count('Copy: scripts/'), 2)
        self.assertEqual(lines.count('Copy: scripts/jd.sh'), 2)
        self.assertIn(f'Seed: {documents / "AGENTS.md"}', lines)
        self.assertFalse(any(line.startswith(('Delete:', 'Previous version:', 'Dry run:'))
                             for line in lines))
        (self.source / 'scripts/jd.sh').unlink()
        lines = self.publish_output(dry_run=True)
        self.assertEqual(lines.count('Delete: scripts/jd.sh'), 2)
        self.assertNotIn('Copy: SKILL.md', lines)
        self.assertIn(f'Dry run: {destination}', lines)
        self.assertFalse(any(line.startswith('Published:') for line in lines))
        lines = self.publish_output()
        backups = sorted((documents / '.agents/skill-backups').iterdir())
        self.assertIn(f'Previous version: {backups[0]}', lines)

    def test_each_update_keeps_its_own_backup(self):
        self.publish()
        for version in ('two', 'three'):
            (self.source / 'SKILL.md').write_text(f'version {version}')
            self.publish()
        backups = list((self.documents / '.agents/skill-backups').iterdir())
        self.assertEqual(sorted((b / 'SKILL.md').read_text() for b in backups),
                         ['version one', 'version two'])

    def run_main(self, *arguments, environment=None):
        script = Path(__file__).resolve().parents[1] / 'bin/publish-jd.py'
        env = dict(os.environ if environment is None else environment)
        return subprocess.run([sys.executable, '-B', str(script), *arguments], env=env,
                              capture_output=True, text=True)

    def test_main_defaults_and_errors(self):
        documents = self.root / 'xdg documents'
        documents.mkdir()
        env = dict(os.environ, XDG_DOCUMENTS_DIR=str(documents))
        result = self.run_main('--dry-run', environment=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Dry run:', result.stdout)
        self.assertEqual(list(documents.iterdir()), [])
        home = self.root / 'home'
        (home / 'Documents').mkdir(parents=True)
        env = {key: value for key, value in os.environ.items() if key != 'XDG_DOCUMENTS_DIR'}
        env.update(HOME=str(home), USERPROFILE=str(home))
        result = self.run_main('--dry-run', environment=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(str((home / 'Documents').resolve()), result.stdout)
        result = self.run_main('--documents', str(self.root / 'missing'), '--dry-run')
        self.assertEqual(result.returncode, 1)
        self.assertTrue(result.stderr.startswith('publish-jd: '), result.stderr)
        not_directory = self.root / 'file'
        not_directory.write_text('x')
        result = self.run_main('--documents', str(not_directory), '--dry-run')
        self.assertEqual(result.returncode, 1)
        self.assertIn('Not a Documents directory', result.stderr)

    def test_dry_run_writes_nothing(self):
        self.publish(dry_run=True)
        self.assertEqual(list(self.documents.iterdir()), [])

    def test_update_removes_old_files_and_preserves_backup(self):
        self.publish()
        self.assertFalse((self.destination / 'tests').exists())
        if os.name != 'nt':
            self.assertTrue((self.destination / 'scripts/jd.sh').stat().st_mode & 0o111)
        (self.source / 'scripts/jd.sh').unlink()
        (self.source / 'SKILL.md').write_text('version two')
        self.publish()
        self.assertFalse((self.destination / 'scripts/jd.sh').exists())
        backups = list((self.documents / '.agents/skill-backups').iterdir())
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / 'SKILL.md').read_text(), 'version one')
        self.publish()
        self.assertEqual(len(list(backups[0].parent.iterdir())), 1)

    def test_local_edits_and_unmanaged_files_are_preserved(self):
        self.publish()
        (self.destination / 'SKILL.md').write_text('local edit')
        with self.assertRaisesRegex(ValueError, 'local changes'):
            self.publish()
        self.assertEqual((self.destination / 'SKILL.md').read_text(), 'local edit')
        (self.destination / module.MANIFEST).unlink()
        with self.assertRaisesRegex(ValueError, 'unmanaged'):
            self.publish()

    def test_added_destination_file_blocks_update(self):
        self.publish()
        (self.destination / 'personal.txt').write_text('keep')
        with self.assertRaisesRegex(ValueError, 'local changes'):
            self.publish()

    def test_symlink_destination_is_rejected(self):
        self.destination.parent.mkdir(parents=True)
        try:
            self.destination.symlink_to(self.source, target_is_directory=True)
        except OSError:
            self.skipTest('Creating symlinks requires Windows Developer Mode or privileges')
        with self.assertRaisesRegex(ValueError, 'symlink destination'):
            self.publish()
        self.assertTrue(self.destination.is_symlink())

    def test_source_symlink_is_rejected(self):
        try:
            (self.source / 'scripts/foreign').symlink_to(self.source / 'SKILL.md')
        except OSError:
            self.skipTest('Creating symlinks requires Windows Developer Mode or privileges')
        with self.assertRaisesRegex(ValueError, 'Symlinks'):
            self.publish()

    def test_failed_replacement_restores_previous_version(self):
        self.publish()
        (self.source / 'SKILL.md').write_text('version two')
        original = Path.rename

        def fail_staged_rename(path, target):
            if path.parent.name.startswith('.publish-jd-'):
                raise OSError('simulated rename failure')
            return original(path, target)

        with patch.object(Path, 'rename', fail_staged_rename):
            with self.assertRaisesRegex(OSError, 'simulated'):
                self.publish()
        self.assertEqual((self.destination / 'SKILL.md').read_text(), 'version one')
        self.assertFalse((self.documents / '.agents/.publish-jd.lock').exists())

    def test_unrelated_skill_is_untouched_and_empty_local_directory_blocks_update(self):
        other = self.documents / '.agents/skills/other/SKILL.md'
        other.parent.mkdir(parents=True)
        other.write_text('unmanaged')
        self.publish()
        (self.destination / 'local empty directory').mkdir()
        with self.assertRaisesRegex(ValueError, 'local changes'):
            self.publish()
        self.assertEqual(other.read_text(), 'unmanaged')

    def test_lock_contention_preserves_previous_version(self):
        self.publish()
        lock = self.documents / '.agents/.publish-jd.lock'
        lock.mkdir()
        (self.source / 'SKILL.md').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'lock exists'):
            self.publish()
        self.assertEqual((self.destination / 'SKILL.md').read_text(), 'version one')
        self.assertTrue(lock.exists())

    def test_lock_on_one_target_leaves_both_targets_unchanged(self):
        # Regression P1: a held .claude lock let .agents update first.
        self.publish()
        lock = self.documents / '.claude/.publish-jd.lock'
        lock.mkdir()
        (self.source / 'SKILL.md').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'lock exists'):
            self.publish()
        self.assertEqual((self.destination / 'SKILL.md').read_text(), 'version one')
        self.assertEqual((self.claude_destination / 'SKILL.md').read_text(), 'version one')
        self.assertFalse((self.documents / '.agents/.publish-jd.lock').exists())

    def test_staging_failure_preserves_live_copy(self):
        self.publish()
        (self.source / 'SKILL.md').write_text('changed')
        original = module.shutil.copytree

        def fail_staging(source, destination, **kwargs):
            if Path(destination).parent.name.startswith('.publish-jd-'):
                raise OSError('simulated staging failure')
            return original(source, destination, **kwargs)

        with patch.object(module.shutil, 'copytree', fail_staging):
            with self.assertRaisesRegex(OSError, 'staging failure'):
                self.publish()
        self.assertEqual((self.destination / 'SKILL.md').read_text(), 'version one')
        self.assertFalse((self.documents / '.agents/.publish-jd.lock').exists())

    def test_both_targets_are_published_and_local_claude_edits_block_both(self):
        self.publish()
        self.assertEqual(module.fingerprint(self.destination),
                         module.fingerprint(self.claude_destination))
        (self.claude_destination / 'SKILL.md').write_text('Windows edit')
        (self.source / 'SKILL.md').write_text('new source')
        with self.assertRaisesRegex(ValueError, 'local changes'):
            self.publish()
        self.assertEqual((self.destination / 'SKILL.md').read_text(), 'version one')
        self.assertEqual((self.claude_destination / 'SKILL.md').read_text(), 'Windows edit')

    def test_workspace_instructions_are_seeded_once_and_existing_settings_preserved(self):
        settings = self.documents / '.claude/settings.local.json'
        settings.parent.mkdir()
        settings.write_text('{}', encoding='utf-8')
        self.publish()
        instructions = self.documents / 'AGENTS.md'
        self.assertEqual(instructions.read_text(), 'Template AGENTS.md')
        self.assertFalse((self.documents / 'CLAUDE.md').exists())
        instructions.write_text('User instructions', encoding='utf-8')
        self.publish()
        self.assertEqual(instructions.read_text(), 'User instructions')
        self.assertEqual(settings.read_text(), '{}')


if __name__ == '__main__':
    unittest.main()
