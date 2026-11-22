# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Behavior tables for jd.py functions that mutation testing showed untested.

Runs under unittest on every platform; POSIX-only checks are skipped
elsewhere.
"""

import contextlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / 'llm/skills/johnny-decimal/scripts/jd.py'
SPEC = importlib.util.spec_from_file_location('jd', SCRIPT)
jd = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(jd)
POSIX = os.name != 'nt'


class FakeOS:
    """os with another name, for jd only: pathlib must keep the real os.name."""

    def __init__(self, name):
        self.name = name

    def __getattr__(self, attribute):
        return getattr(os, attribute)


class Tree(unittest.TestCase):
    """A small JD tree with the environment pointing at it."""

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.workspace = Path(temporary.name).resolve()
        self.root = self.workspace / 'Documents'
        self.jdex = self.root / jd.JDEX
        self.jdex.mkdir(parents=True)
        self.bank = self.root / '20-29 Finances/21 Banks/21.10 Example Bank'
        self.bank.mkdir(parents=True)
        (self.root / '20-29 Finances/22 X-Ray/22.10 Scans').mkdir(parents=True)
        (self.root / '10-19 Personal/11 Alex/11.70 Legal').mkdir(parents=True)
        env = patch.dict(os.environ, {'JD_ROOT': str(self.root), 'JDEX_PATH': str(self.jdex)})
        env.start()
        self.addCleanup(env.stop)

    def cli(self, *argv, porcelain=True):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            status = jd.main([*argv, *(['--porcelain'] if porcelain else [])])
        return status, out.getvalue(), err.getvalue()

    def args(self, **values):
        return type('Args', (), dict(dict(porcelain=False), **values))()


class PathsTests(unittest.TestCase):
    def run_paths(self, environment, name='posix'):
        script = Path('/nowhere/dotfiles/llm/skills/johnny-decimal/scripts/jd.py')
        with patch.object(jd, 'os', FakeOS(name)):
            return jd.paths(environment, script)

    def test_home_comes_from_home_or_userprofile_by_platform(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary).resolve()
            env = dict(HOME=str(base / 'h'), USERPROFILE=str(base / 'u'))
            self.assertEqual(self.run_paths(env)[0], base / 'h/Documents')
            self.assertEqual(self.run_paths(env, 'nt')[0], base / 'u/Documents')
            self.assertEqual(self.run_paths(dict(HOME=str(base / 'h')), 'nt')[0],
                             base / 'h/Documents')

    def test_host_configuration_location_and_keys(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary).resolve()
            (base / 'h/.config/johnnydecimal').mkdir(parents=True)
            (base / 'h/.config/johnnydecimal/config.json').write_text(
                '{"root": "${HOME}/R", "jdex": "$HOME/J"}', encoding='utf-8')
            self.assertEqual(self.run_paths(dict(HOME=str(base / 'h'))),
                             (base / 'h/R', base / 'h/J'))
            (base / 'x/johnnydecimal').mkdir(parents=True)
            (base / 'x/johnnydecimal/config.json').write_text('{"root": "/xdg"}',
                                                              encoding='utf-8')
            env = dict(HOME=str(base / 'h'), XDG_CONFIG_HOME=str(base / 'x'))
            self.assertEqual(self.run_paths(env)[0], Path('/xdg').resolve())

    def test_configured_paths_must_be_nonempty_strings_and_unknown_variables_stay(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary).resolve()
            config = base / 'config.json'
            for value in ('5', '[1]'):
                config.write_text('{"root": %s}' % value, encoding='utf-8')
                with self.assertRaises(jd.JDException):
                    self.run_paths(dict(HOME=str(base), JD_CONFIG=str(config)))
            config.write_text('{"root": "%s/$NOPE/${HOME}"}' % base.as_posix(),
                              encoding='utf-8')
            root, _ = self.run_paths(dict(HOME=str(base), JD_CONFIG=str(config)))
            self.assertEqual(root, (base / '$NOPE' / str(base).lstrip('/')).resolve()
                             if POSIX else root)


class NamingTests(unittest.TestCase):
    def test_identifier_returns_its_argument(self):
        self.assertEqual(jd.identifier('21.10'), '21.10')

    def test_child_path_reports_traversal_as_an_invalid_relative_path(self):
        parent = Path(tempfile.gettempdir())
        for relative in ('..', '.', 'a//b', 'a/../b', 'C:/x', '/x', '\\x'):
            with self.assertRaisesRegex(jd.JDException, 'Invalid relative path'):
                jd.child_path(parent, relative)


class InteractionTests(Tree):
    def test_interactive_requires_both_terminals_and_no_porcelain(self):
        for porcelain, stdin, stdout, expected in [
                (False, True, True, True), (True, True, True, False),
                (False, False, True, False), (False, True, False, False)]:
            with patch.object(jd.sys.stdin, 'isatty', return_value=stdin), \
                    patch.object(jd.sys.stdout, 'isatty', return_value=stdout):
                self.assertIs(jd.interactive(self.args(porcelain=porcelain)), expected)

    def browse(self, answers):
        errors = io.StringIO()
        with patch('builtins.input', side_effect=answers), contextlib.redirect_stderr(errors):
            selected = jd.browse(self.root)
        return selected, errors.getvalue()

    def test_browse_numbers_choices_and_rejects_invalid_input(self):
        selected, prompts = self.browse(['x', '0', '4', '3', '1', '1'])
        self.assertEqual(selected, '21.10')
        self.assertIn('1: 00-09 System\n2: 10-19 Personal\n3: 20-29 Finances\n', prompts)
        self.assertIn('1: 21 Banks\n2: 22 X-Ray\n', prompts)
        self.assertIn('1: 21.10 Example Bank\n', prompts)
        self.assertEqual(prompts.count('Enter number: '), 6)
        selected, _ = self.browse(['3', '2', '1'])
        self.assertEqual(selected, '22.10')

    def test_browse_fails_on_an_empty_level_and_on_end_of_input(self):
        (self.root / '30-39 Empty').mkdir()
        with self.assertRaisesRegex(jd.JDException, 'No folders to select'):
            self.browse(['4'])
        with patch.object(jd, 'interactive', return_value=True), \
                patch('builtins.input', side_effect=EOFError):
            status, _, errors = self.cli('list', porcelain=False)
        self.assertEqual(status, 1)
        self.assertIn('Error', errors)

    def test_list_browses_only_when_interactive_without_a_target(self):
        with patch.object(jd, 'interactive', return_value=True), \
                patch('builtins.input', side_effect=['3', '1', '1']), \
                contextlib.redirect_stderr(io.StringIO()):
            status, out, _ = self.cli('list', porcelain=False)
        self.assertEqual((status, out), (0, ''))
        with patch.object(jd, 'interactive', return_value=False):
            status, out, _ = self.cli('list', porcelain=False)
        self.assertEqual(out.splitlines(), ['00-09 System', '10-19 Personal', '20-29 Finances'])


class ListingTests(Tree):
    def test_search_modes_match_only_their_level(self):
        cases = {'20-': ['20-29 Finances'], '21': ['21 Banks'], '21.': ['21.10 Example Bank'],
                 'bank': ['21 Banks', '21.10 Example Bank'], '2': ['20-29 Finances',
                                                               '21 Banks', '21.10 Example Bank',
                                                               '22 X-Ray', '22.10 Scans']}
        for query, expected in cases.items():
            status, out, _ = self.cli('search', query, porcelain=False)
            self.assertEqual(sorted(out.splitlines()), sorted(expected), query)

    def test_list_marks_directories_and_lists_each_level(self):
        (self.bank / 'statements').mkdir()
        (self.bank / 'a.pdf').write_text('x')
        _, out, _ = self.cli('list', '21.10', porcelain=False)
        self.assertEqual(out.splitlines(), ['a.pdf', 'statements/'])
        _, out, _ = self.cli('list', '20-', porcelain=False)
        self.assertEqual(out.splitlines(), ['21 Banks', '22 X-Ray'])
        # Regression J2: a dash early in a category name made it look like an area.
        _, out, _ = self.cli('list', '22', porcelain=False)
        self.assertEqual(out.splitlines(), ['22.10 Scans'])

    def test_tree_depth_order_and_filtering(self):
        for name in ('10 b', '2 a', 'B c', 'a d', '.hidden'):
            (self.bank / name).mkdir()
        (self.bank / '2 a/inner').mkdir()
        (self.bank / 'file').write_text('x')
        if POSIX:
            (self.bank / 'link').symlink_to(self.bank / '2 a')
        status, out, _ = self.cli('tree', '21.10', porcelain=False)
        self.assertEqual(out.splitlines()[1:],
                         ['  2 a', '    inner', '  10 b', '  a d', '  B c'])
        _, out, _ = self.cli('tree', '21.10', '-L', '1', porcelain=False)
        self.assertEqual(out.splitlines()[1:], ['  2 a', '  10 b', '  a d', '  B c'])
        status, _, errors = self.cli('tree', '21.10', '-L', '0')
        self.assertEqual(status, 1)
        self.assertIn('Depth must be positive', errors)

    def test_validate_reports_each_file(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            status = jd.main(['validate', 'dir/ok.pdf', 'dir\\has space.pdf',
                              'statement.pdf', 'bad:name', 'a;b'])
        self.assertEqual(status, 1)
        self.assertEqual(out.getvalue().splitlines(), [
            'OK:ok.pdf',
            'WARN:has space.pdf:Contains spaces - prefer underscores',
            'WARN:statement.pdf:Transient document without date prefix - consider '
            'YYYY-MM-DD_name.ext',
            "ERROR:bad:name:Invalid name: 'bad:name'",
            'ERROR:a;b:Contains problematic special characters',
        ])
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(jd.main(['validate', 'fine.pdf']), 0)


class FilingTests(Tree):
    @unittest.skipUnless(POSIX, 'POSIX permissions')
    def test_created_and_moved_directories_are_private(self):
        self.cli('mkdir', '21', 'New')
        self.assertEqual((self.bank.parent / '21.11 New').stat().st_mode & 0o777, 0o700)
        source = self.workspace / 'folder'
        source.mkdir(mode=0o755)
        self.cli('move', str(source), '21.10')
        self.assertEqual((self.bank / 'folder').stat().st_mode & 0o777, 0o700)

    def test_directory_move_removes_source_and_keeps_links_and_times(self):
        source = self.workspace / 'folder'
        (source / 'sub').mkdir(parents=True)
        (source / 'sub/file').write_text('content')
        if POSIX:
            (source / 'link').symlink_to('sub/file')
        status, _, errors = self.cli('move', str(source), '21.10')
        self.assertEqual(status, 0, errors)
        self.assertFalse(source.exists())
        self.assertEqual((self.bank / 'folder/sub/file').read_text(), 'content')
        if POSIX:
            self.assertEqual(os.readlink(self.bank / 'folder/link'), 'sub/file')
        old = time.time() - 86400
        document = self.workspace / 'old.pdf'
        document.write_text('x')
        os.utime(document, (old, old))
        self.cli('move', str(document), '21.10')
        self.assertAlmostEqual((self.bank / 'old.pdf').stat().st_mtime, old, delta=2)

    def test_transfer_reserves_a_new_directory_and_cleans_up_failures(self):
        source = self.workspace / 'folder'
        source.mkdir()
        (source / 'file').write_text('content')
        existing = self.bank / 'existing'
        existing.mkdir()
        (existing / 'keep').write_text('keep')
        with self.assertRaises(FileExistsError):
            jd.transfer(source, existing, False)
        self.assertEqual(sorted(p.name for p in existing.iterdir()), ['keep'])
        self.assertTrue((source / 'file').exists())

        def partial_copy(src, dst, **kwargs):
            (Path(dst) / 'partial').write_text('x')
            raise OSError('copy failed')

        destination = self.bank / 'fresh'
        with patch.object(jd.shutil, 'copytree', partial_copy):
            with self.assertRaises(OSError):
                jd.transfer(source, destination, False)
        self.assertFalse(destination.exists())
        self.assertTrue((source / 'file').exists())

    def test_force_replaces_only_regular_files_and_never_a_source_itself(self):
        (self.bank / 'target').mkdir()
        source = self.workspace / 'target'
        source.write_text('new')
        status, _, errors = self.cli('move', str(source), '21.10', '--force')
        self.assertEqual(status, 1)
        self.assertIn('--force only replaces regular files', errors)
        folder = self.workspace / 'folder'
        folder.mkdir()
        (self.bank / 'folder').write_text('file')
        status, _, errors = self.cli('move', str(folder), '21.10', '--force')
        self.assertIn('--force only replaces regular files', errors)
        inside = self.bank / 'inside.pdf'
        inside.write_text('same')
        status, _, errors = self.cli('move', str(inside), '21.10', '--force')
        self.assertEqual(status, 1)
        self.assertIn('onto or inside itself', errors)
        self.assertEqual(inside.read_text(), 'same')
        status, _, errors = self.cli('move', str(self.bank), '21.10', '--subdir', 'deeper')
        self.assertIn('onto or inside itself', errors)
        self.assertTrue(self.bank.is_dir())


class EditorTests(Tree):
    def edit_command(self, environment, name='posix', editor_file=None):
        recorded = []
        with patch.dict(os.environ, environment, clear=False), \
                patch.object(jd, 'os', FakeOS(name)), \
                patch.object(jd.subprocess, 'run', lambda command, check: recorded.append(
                    (command, check))):
            for key in ('EDITOR', 'VISUAL'):
                if key not in environment:
                    os.environ.pop(key, None)
            jd.edit(Path('note.md'))
        return recorded[0]

    def test_editor_selection(self):
        self.assertEqual(self.edit_command({'EDITOR': 'ed -s', 'VISUAL': 'vis'}),
                         (['ed', '-s', 'note.md'], True))
        self.assertEqual(self.edit_command({'VISUAL': 'vis'}), (['vis', 'note.md'], True))
        self.assertEqual(self.edit_command({}), (['vi', 'note.md'], True))
        self.assertEqual(self.edit_command({}, 'nt'), (['notepad', 'note.md'], True))
        self.assertEqual(self.edit_command({'EDITOR': "ed 'a b'"}), (['ed', 'a b', 'note.md'], True))
        self.assertEqual(self.edit_command({'EDITOR': "ed 'a b'"}, 'nt'),
                         (['ed', "'a b'", 'note.md'], True))
        program = self.workspace / 'my editor'
        program.write_text('')
        self.assertEqual(self.edit_command({'EDITOR': str(program)}),
                         ([str(program), 'note.md'], True))

    def test_failing_editor_is_reported(self):
        with patch.object(jd, 'interactive', return_value=True), \
                patch.dict(os.environ, {'EDITOR': 'false'}):
            status, _, errors = self.cli('read', '21.10', '--edit', porcelain=False)
        self.assertEqual(status, 1)
        self.assertIn('Error', errors)


class NoteTests(Tree):
    def test_new_note_text_is_normalized_to_lf(self):
        status, _, _ = self.cli('note', '21.10', 'a\r\nb\rc\n')
        self.assertEqual(status, 0)
        content = (self.jdex / '21.10.md').read_bytes()
        self.assertTrue(content.endswith(b'a\nb\nc\n\n'), content)
        self.assertNotIn(b'\r', content)

    def test_notes_require_an_id_and_text_outside_a_terminal(self):
        with patch.object(jd, 'interactive', return_value=False):
            status, _, errors = self.cli('note', porcelain=False)
            self.assertIn('An ID is required', errors)
            status, _, errors = self.cli('note', '21.10', porcelain=False)
            self.assertIn('Note text required', errors)
            status, _, errors = self.cli('read', '21.10', '--edit', porcelain=False)
            self.assertIn('--edit requires interactive mode', errors)

    def test_unknown_id_note_is_titled_unknown_and_reported(self):
        status, out, _ = self.cli('note', '45.67', 'text', porcelain=False)
        self.assertEqual((status, out), (0, 'Added note to 45.67.md\n'))
        self.assertTrue((self.jdex / '45.67.md').read_text().startswith('# 45.67 Unknown\n'))

    def test_interactive_edit_and_draft_notes(self):
        edits = []

        def fake_edit(path):
            edits.append(path.read_text(encoding='utf-8'))
            if path.name == 'note.md':
                path.write_text(self.draft, encoding='utf-8')

        with patch.object(jd, 'interactive', return_value=True), \
                patch.object(jd, 'edit', fake_edit):
            self.cli('read', '21.10', '--edit', porcelain=False)
            self.assertEqual(edits[-1], '# 21.10 Example Bank\n\n')
            self.cli('read', '21.10', '--edit', porcelain=False)
            self.assertEqual(edits[-1], '# 21.10 Example Bank\n\n')
            note = self.jdex / '11.70.md'
            self.draft = '  drafted text  \n'
            status, _, _ = self.cli('note', '11.70', porcelain=False)
            self.assertEqual(edits[-1], '')
            self.assertEqual(status, 0)
            self.assertIn('drafted text\n', note.read_text(encoding='utf-8'))
            before = note.read_bytes()
            self.draft = '   \n'
            self.cli('note', '11.70', porcelain=False)
            self.assertEqual(note.read_bytes(), before)


class CommandLineTests(Tree):
    def test_output_is_utf8_even_when_the_stream_encoding_is_not(self):
        (self.bank / 'récépissé').mkdir()
        env = dict(os.environ, PYTHONIOENCODING='ascii', PYTHONUTF8='0')
        result = subprocess.run([sys.executable, '-B', str(SCRIPT), 'list', '21.10'],
                                env=env, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('récépissé/'.encode('utf-8'), result.stdout)
        result = subprocess.run([sys.executable, '-B', str(SCRIPT), 'list', '99.ü'],
                                env=env, capture_output=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('99.ü'.encode('utf-8'), result.stderr)

    def test_parser_contract(self):
        result = subprocess.run([sys.executable, '-B', str(SCRIPT)], capture_output=True,
                                text=True)
        self.assertEqual(result.returncode, 2)
        self.assertTrue(result.stderr.startswith('usage: jd.py'), result.stderr)
        args = jd.parser().parse_args(['tree'])
        self.assertEqual(args.depth, 2)


if __name__ == '__main__':
    unittest.main()
