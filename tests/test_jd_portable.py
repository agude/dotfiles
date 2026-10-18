# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Portable CLI tests; all mutations stay in temporary document systems."""

from datetime import date
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / 'llm/skills/johnny-decimal/scripts/jd.py'
SPEC = importlib.util.spec_from_file_location('jd', SCRIPT)
jd = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(jd)


class PortableTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        # jd.py reports resolved paths. Resolve the temporary directory too, since
        # Windows runners use 8.3 temp names (RUNNER~1) and macOS links /var.
        self.workspace = Path(self.temporary.name).resolve()
        self.root = self.workspace / 'Shared Documents ü'
        self.jdex = self.root / jd.JDEX
        self.bank = self.root / '20-29 Finances/21 Banks/21.10 Example Bank'
        self.inbox = self.root / '00-09 System/00 System/00.01 Inbox for System'
        for path in (self.jdex, self.bank, self.inbox):
            path.mkdir(parents=True)
        self.env = {key: value for key, value in os.environ.items()
                    if key not in ('JD_ROOT', 'JDEX_PATH', 'JD_CONFIG', 'XDG_DOCUMENTS_DIR')}
        self.env.update(JD_ROOT=str(self.root), JDEX_PATH=str(self.jdex), PYTHONUTF8='1')

    def run_cli(self, *args, success=True, script=SCRIPT, environment=None):
        result = subprocess.run([sys.executable, '-B', str(script), *map(str, args)],
                                env=self.env if environment is None else environment,
                                text=True, encoding='utf-8', capture_output=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def test_deployed_root_ignores_implicit_host_configuration(self):
        target = self.root / '.agents/skills/johnny-decimal/scripts/jd.py'
        target.parent.mkdir(parents=True)
        shutil.copyfile(SCRIPT, target)
        config = self.workspace / 'config/johnnydecimal/config.json'
        config.parent.mkdir(parents=True)
        config.write_text(json.dumps(dict(root='/wrong/root')), encoding='utf-8')
        env = dict(self.env, XDG_CONFIG_HOME=str(config.parent.parent))
        env.pop('JD_ROOT')
        env.pop('JDEX_PATH')
        result = self.run_cli('list', '21.10', '--porcelain', script=target, environment=env)
        self.assertEqual(result.stdout.strip(), str(self.bank))
        self.assertFalse((target.parent / '__pycache__').exists())

    def test_configuration_precedence_and_json_escapes(self):
        config = self.workspace / 'config.json'
        config.write_text(json.dumps(dict(root=str(self.root), jdex=str(self.jdex))), encoding='utf-8')
        env = dict(JD_CONFIG=str(config))
        self.assertEqual(jd.paths(env, SCRIPT), (self.root, self.jdex))
        env['JD_ROOT'] = str(self.workspace)
        env['JDEX_PATH'] = str(self.root)
        self.assertEqual(jd.paths(env, SCRIPT), (self.workspace, self.root))
        deployed = self.root / '.agents/skills/johnny-decimal/scripts/jd.py'
        self.assertEqual(jd.paths(dict(JD_CONFIG=str(config)), deployed), (self.root, self.jdex))

    def test_global_install_uses_host_config_not_dotfiles_parent(self):
        script = self.workspace / 'dotfiles/llm/skills/johnny-decimal/scripts/jd.py'
        env = dict(HOME=str(self.workspace), XDG_DOCUMENTS_DIR=str(self.root))
        self.assertEqual(jd.paths(env, script), (self.root, self.jdex))

    def test_user_global_copy_uses_host_defaults(self):
        script = self.workspace / '.agents/skills/johnny-decimal/scripts/jd.py'
        env = dict(HOME=str(self.workspace), USERPROFILE=str(self.workspace),
                   XDG_DOCUMENTS_DIR=str(self.root))
        self.assertEqual(jd.paths(env, script), (self.root, self.jdex))

    def test_claude_deployment_uses_nas_root_and_global_copy_uses_host_config(self):
        target = self.root / '.claude/skills/johnny-decimal/scripts/jd.py'
        target.parent.mkdir(parents=True)
        shutil.copyfile(SCRIPT, target)
        env = dict(self.env)
        env.pop('JD_ROOT')
        env.pop('JDEX_PATH')
        result = self.run_cli('list', '21.10', '--porcelain', script=target, environment=env)
        self.assertEqual(result.stdout.strip(), str(self.bank))
        global_copy = self.workspace / '.claude/skills/johnny-decimal/scripts/jd.py'
        host_env = dict(HOME=str(self.workspace), USERPROFILE=str(self.workspace),
                        XDG_DOCUMENTS_DIR=str(self.root))
        self.assertEqual(jd.paths(host_env, global_copy), (self.root, self.jdex))

    def test_missing_root_is_reported(self):
        env = dict(self.env, JD_ROOT=str(self.workspace / 'missing'))
        result = self.run_cli('list', '--porcelain', success=False, environment=env)
        self.assertIn('JD_ROOT does not exist', result.stderr)

    def test_dry_run_does_not_create_subdirectory(self):
        source = self.workspace / 'scan ü.pdf'
        source.write_bytes(b'original')
        result = self.run_cli('move', source, '21.10', '--name', 'statement.pdf',
                              '--subdir', 'new/nested', '--dry-run', '--porcelain')
        self.assertTrue(source.exists())
        self.assertFalse((self.bank / 'new').exists())
        self.assertEqual(result.stdout.strip(), str(self.bank / 'new/nested/statement.pdf'))

    def test_move_and_note_preserve_unicode_and_multiline_text(self):
        source = self.workspace / 'scan.pdf'
        source.write_bytes(b'original')
        self.run_cli('move', source, '21.10', '--name', 'récépissé.pdf', '--porcelain')
        self.assertEqual((self.bank / 'récépissé.pdf').read_bytes(), b'original')
        self.assertFalse(source.exists())
        self.run_cli('note', '21.10', 'First line\n\nSecond ü line', '--porcelain')
        self.run_cli('note', '21.10', 'Another entry', '--porcelain')
        note = (self.jdex / '21.10.md').read_text(encoding='utf-8')
        self.assertIn('First line\n\nSecond ü line', note)
        self.assertEqual(note.count('## '), 1)
        self.assertEqual(self.run_cli('read', '21.10').stdout, note)

    def test_batch_preflight_preserves_all_sources_on_collision(self):
        first, second = self.workspace / 'first.pdf', self.workspace / 'second.pdf'
        first.touch()
        second.touch()
        (self.bank / second.name).write_text('keep', encoding='utf-8')
        self.run_cli('move', first, second, '21.10', success=False)
        self.assertTrue(first.exists())
        self.assertTrue(second.exists())
        self.assertFalse((self.bank / first.name).exists())

    def test_batch_rejects_case_collisions_and_overlapping_sources(self):
        first = self.workspace / 'one/same.pdf'
        second = self.workspace / 'two/SAME.pdf'
        first.parent.mkdir()
        second.parent.mkdir()
        first.touch()
        second.touch()
        self.run_cli('move', first, second, '21.10', success=False)
        self.run_cli('move', first.parent, first, '21.10', success=False)
        self.assertTrue(first.exists())
        self.assertTrue(second.exists())

    def test_unsafe_names_and_subdirectories_are_rejected(self):
        source = self.workspace / 'scan.pdf'
        source.touch()
        for name in ('../escape', 'CON.pdf', 'x:y', 'trailing.', 'a\\b', 'NUL', 'LPT1.txt'):
            with self.subTest(name=name):
                self.run_cli('move', source, '21.10', '--name', name, success=False)
                self.run_cli('mkdir', '21.10', name, success=False)
        for subdir in ('../escape', '/absolute', r'C:\escape', r'\\server\share',
                       r'a\..\escape', r'C:drive-relative'):
            with self.subTest(subdir=subdir):
                self.run_cli('move', source, '21.10', '--subdir', subdir, success=False)
        self.assertTrue(source.exists())

    def test_windows_subdirectory_separators_are_supported(self):
        source = self.workspace / 'scan.pdf'
        source.touch()
        self.run_cli('move', source, '21.10', '--subdir', r'one\two', '--porcelain')
        self.assertTrue((self.bank / 'one/two/scan.pdf').exists())

    def test_directory_moves_and_numeric_id_collisions(self):
        source = self.workspace / 'folder'
        source.mkdir()
        (source / 'nested.txt').write_text('keep', encoding='utf-8')
        self.run_cli('move', source, '21.10', '--porcelain')
        self.assertEqual((self.bank / 'folder/nested.txt').read_text(), 'keep')
        self.run_cli('mkdir', '21', 'Different Name', '--id', '010', success=False)

    def test_new_file_does_not_overwrite_concurrently_created_target(self):
        source, destination = self.workspace / 'source', self.bank / 'target'
        source.write_text('source', encoding='utf-8')
        destination.write_text('created concurrently', encoding='utf-8')
        with self.assertRaises(FileExistsError):
            jd.transfer(source, destination, False)
        self.assertEqual(destination.read_text(), 'created concurrently')
        self.assertTrue(source.exists())

    def test_failed_copy_retains_source_and_removes_partial_target(self):
        source, destination = self.workspace / 'source', self.bank / 'target'
        source.write_text('source', encoding='utf-8')
        with patch.object(jd.shutil, 'copyfileobj', side_effect=OSError('copy failed')):
            with self.assertRaises(OSError):
                jd.transfer(source, destination, False)
        self.assertTrue(source.exists())
        self.assertFalse(destination.exists())

    def test_tree_porcelain_lines_are_absolute_paths(self):
        result = self.run_cli('tree', '20-29', '-L2', '--porcelain')
        self.assertGreater(len(result.stdout.splitlines()), 1)
        self.assertTrue(all(Path(line).is_absolute() for line in result.stdout.splitlines()))

    def test_porcelain_can_enumerate_files_and_rejects_editing(self):
        item = self.bank / 'document.pdf'
        item.touch()
        result = self.run_cli('list', '21.10', '--files', '--porcelain')
        self.assertEqual(result.stdout.strip(), str(item))
        self.run_cli('read', '21.10', '--edit', '--porcelain', success=False)

    def test_force_cannot_replace_another_source_in_batch(self):
        first = self.workspace / 'same.pdf'
        second = self.bank / 'same.pdf'
        first.write_text('first', encoding='utf-8')
        second.write_text('second', encoding='utf-8')
        self.run_cli('move', first, second, '21.10', '--force', success=False)
        self.assertEqual(first.read_text(), 'first')
        self.assertEqual(second.read_text(), 'second')

    def test_two_digit_targets_always_select_categories(self):
        for prefix in ('00', '10', '20', '90'):
            with self.subTest(prefix=prefix):
                area = self.root / f'{prefix}-{int(prefix) + 9:02d} Test Area'
                if prefix == '00':
                    area = self.inbox.parent.parent
                    category = self.inbox.parent
                elif prefix == '20':
                    area = self.bank.parent.parent
                    category = area / '20 Test Category'
                else:
                    category = area / f'{prefix} Test Category'
                category.mkdir(parents=True, exist_ok=True)
                item = category / f'{prefix}.10 Test ID'
                item.mkdir()
                self.assertEqual(self.run_cli('search', prefix, '--porcelain').stdout.strip(),
                                 str(category))
                listing = self.run_cli('list', prefix, '--porcelain').stdout.splitlines()
                self.assertIn(str(item), listing)
                self.assertNotIn(str(category), listing)
                tree = self.run_cli('tree', prefix, '-L1', '--porcelain').stdout.splitlines()
                self.assertEqual(tree[0], str(category))
                self.assertIn(str(item), tree)
                self.assertIn(str(category), self.run_cli('list', prefix + '-',
                                                         '--porcelain').stdout.splitlines())
        self.run_cli('list', '20-28', '--porcelain', success=False)

    def test_explicit_ids_are_padded_without_renaming_legacy_ids(self):
        category = self.bank.parent
        self.run_cli('mkdir', '21', 'Padded ID', '--id', '5', '--porcelain')
        self.assertTrue((category / '21.05 Padded ID').is_dir())
        self.run_cli('mkdir', '21', 'Duplicate', '--id', '005', success=False)
        legacy = category / '21.6 Legacy ID'
        legacy.mkdir()
        self.run_cli('mkdir', '21', 'Duplicate Legacy', '--id', '06', success=False)
        self.assertTrue(legacy.is_dir())
        self.run_cli('mkdir', '21', 'Extended ID', '--id', '100', '--porcelain')
        self.assertTrue((category / '21.100 Extended ID').is_dir())
        self.run_cli('mkdir', '00', 'System ID', '--id', '5', '--porcelain')
        self.assertTrue((self.inbox.parent / '00.05 System ID').is_dir())

    def test_transient_filename_warnings_ignore_case(self):
        for filename in ('Statement.pdf', 'RECEIPT.pdf', 'Invoice.pdf', 'bill.pdf'):
            with self.subTest(filename=filename):
                result = self.run_cli('validate', filename, '--porcelain')
                self.assertIn(f'WARN:{filename}:Transient document without date prefix',
                              result.stdout)
                dated = '2026-10-17_' + filename
                self.assertEqual(self.run_cli('validate', dated, '--porcelain').stdout.strip(),
                                 f'OK:{dated}')

    def test_new_notes_use_utf8_lf_and_one_blank_line_between_entries(self):
        self.run_cli('note', '21.10', 'First ü\r\nline', '--porcelain')
        self.run_cli('note', '21.10', 'Second entry', '--porcelain')
        expected = (f'# 21.10 Example Bank\n\n## {date.today().isoformat()}\n\n'
                    'First ü\nline\n\nSecond entry\n\n').encode('utf-8')
        self.assertEqual((self.jdex / '21.10.md').read_bytes(), expected)

    def test_appends_preserve_history_bytes_and_its_newline_style(self):
        path = self.jdex / '21.10.md'
        for newline in (b'\n', b'\r\n'):
            for trailing_count in (0, 1, 2, 3):
                with self.subTest(newline=newline, trailing_count=trailing_count):
                    history = newline.join((b'# 21.10 Example Bank', b'',
                                            b'## 2000-01-01', b'', b'Old history'))
                    history += newline * trailing_count
                    path.write_bytes(history)
                    self.run_cli('note', '21.10', 'First ü\nline', '--porcelain')
                    self.run_cli('note', '21.10', 'Second entry', '--porcelain')
                    addition = newline.join((f'## {date.today().isoformat()}'.encode(), b'',
                                             'First ü'.encode('utf-8'), b'line', b'',
                                             b'Second entry', b'', b''))
                    expected = history + newline * max(0, 2 - trailing_count) + addition
                    self.assertEqual(path.read_bytes(), expected)

    def test_move_help_identifies_the_final_destination(self):
        result = self.run_cli('move', '--help')
        self.assertIn('SOURCE [SOURCE ...] ID', result.stdout)
        self.assertIn('XX.YY', result.stdout)
        source = self.workspace / 'source.pdf'
        source.touch()
        result = self.run_cli('move', source, success=False)
        self.assertIn('ID', result.stderr)
        self.assertTrue(source.exists())


if __name__ == '__main__':
    unittest.main()
