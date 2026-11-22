# /// script
# requires-python = ">=3.10"
# dependencies = ["hypothesis==6.170.14"]
# ///
"""Property tests for the portable Johnny.Decimal CLI.

Runs under unittest (the Windows job) and pytest alike. Every mutation
stays inside temporary document systems.
"""

import contextlib
from datetime import date
import importlib.util
import io
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
from hypothesis.stateful import (  # noqa: E402
    RuleBasedStateMachine, initialize, invariant, rule)

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / 'llm/skills/johnny-decimal/scripts/jd.py'
SPEC = importlib.util.spec_from_file_location('jd', SCRIPT)
jd = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(jd)

# Independent statement of the Windows naming rules (not jd.safe_name).
WINDOWS_RESERVED = ({'con', 'prn', 'aux', 'nul', 'conin$', 'conout$'}
                    | {f'{kind}{digit}' for kind in ('com', 'lpt')
                       for digit in '123456789\u00b9\u00b2\u00b3'})
WINDOWS_FORBIDDEN = set('<>:"/\\|?*') | {chr(code) for code in range(32)} | {'\x7f'}


def windows_allows(name):
    if not name or name in ('.', '..') or name[-1] in ' .':
        return False
    if any(character in WINDOWS_FORBIDDEN for character in name):
        return False
    return name.split('.')[0].casefold() not in WINDOWS_RESERVED


PART = st.sampled_from(['a', 'b c', '..', '.', '', 'C:', 'CON', 'com1.txt', 'Aux.', 'x ',
                        'y.', 'ü', 'a:b', 'n\x00', 't\x1f', 'x*y', 'link', 'COM\u00b9',
                        'conin$', 'lpt9', 'nul.tar.gz', 'ok.pdf'])
RELATIVE = st.one_of(
    st.lists(PART, min_size=1, max_size=4).flatmap(
        lambda parts: st.sampled_from(['/', '\\']).map(lambda sep: sep.join(parts))),
    st.sampled_from(['C:/x', 'C:x', '\\\\server\\share\\x', '/abs', '\\abs']),
    st.text(max_size=12),
)


class PathProperties(unittest.TestCase):
    @given(RELATIVE)
    def test_child_path_never_escapes_or_follows_links(self, relative):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary).resolve()
            parent = base / '21.10 Bank'
            parent.mkdir()
            outside = base / 'outside'
            outside.mkdir()
            try:
                (parent / 'link').symlink_to(outside, target_is_directory=True)
            except OSError:
                pass
            try:
                result = jd.child_path(parent, relative)
            except jd.JDException:
                return
            self.assertTrue(result.resolve().is_relative_to(parent.resolve()), result)
            parts = relative.replace('\\', '/').split('/')
            self.assertTrue(all(windows_allows(part) for part in parts), relative)
            prefix = parent
            for part in parts:
                prefix = prefix / part
                self.assertFalse(prefix.is_symlink(), prefix)

    @given(st.one_of(PART, st.text(max_size=10)))
    def test_safe_name_accepts_exactly_windows_safe_names(self, name):
        try:
            jd.safe_name(name)
            accepted = True
        except jd.JDException:
            accepted = False
        self.assertEqual(accepted, windows_allows(name), repr(name))


AREAS = {'21': '20-29 Finances/21 Banks', '22': '20-29 Finances/22 Cards'}
TITLES = st.sampled_from(['Alpha', 'Beta Bank', 'Café', 'Gamma'])
FILES = st.sampled_from(['a.pdf', 'A.PDF', 'b.txt', 'scan ü.pdf', 'c.md'])
CONTENT = st.binary(min_size=1, max_size=8)


def run_cli(*argv):
    output, errors = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
        status = jd.main([*argv, '--porcelain'])
    return status, output.getvalue(), errors.getvalue()


class JDMachine(RuleBasedStateMachine):
    """Compare the CLI against a dictionary model of IDs and their files."""

    @initialize()
    def setup(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.workspace = Path(self.temporary.name).resolve()
        self.root = self.workspace / 'Documents'
        self.jdex = self.root / jd.JDEX
        self.jdex.mkdir(parents=True)
        (self.root / '00-09 System/00 System/00.01 Inbox for System').mkdir()
        for path in AREAS.values():
            (self.root / path).mkdir(parents=True)
        self.sources = self.workspace / 'sources'
        self.sources.mkdir()
        self.environment = patch.dict(os.environ, {
            'JD_ROOT': str(self.root), 'JDEX_PATH': str(self.jdex)})
        self.environment.start()
        # model: category -> {suffix: {'name': dirname, 'files': {name: bytes}}}
        self.model = {category: {} for category in AREAS}
        self.notes = {}

    def teardown(self):
        if hasattr(self, 'environment'):
            self.environment.stop()
            self.temporary.cleanup()

    def directory(self, category, suffix):
        return self.root / AREAS[category] / self.model[category][suffix]['name']

    def all_ids(self):
        return [(category, suffix) for category in self.model for suffix in self.model[category]]

    @rule(category=st.sampled_from(sorted(AREAS)), title=TITLES,
          explicit=st.one_of(st.none(), st.integers(0, 120),
                             st.integers(0, 120).map(lambda n: '0' + str(n))))
    def mkdir(self, category, title, explicit):
        existing = self.model[category]
        argv = ['mkdir', category, title]
        if explicit is not None:
            argv += ['--id', str(explicit)]
            suffix = int(explicit)
            text = str(explicit).zfill(2)
        else:
            suffix = max([9, *existing]) + 1
            text = str(suffix).zfill(2)
        status, _, _ = run_cli(*argv)
        if suffix in existing:
            assert status == 1
            return
        assert status == 0
        existing[suffix] = {'name': f'{category}.{text} {title}', 'files': {}}

    @rule(names=st.lists(FILES, min_size=1, max_size=3), contents=st.data(),
          force=st.booleans(), rename=st.one_of(st.none(), FILES), fail=st.booleans())
    def move(self, names, contents, force, rename, fail):
        ids = self.all_ids()
        if not ids:
            return
        category, suffix = contents.draw(st.sampled_from(ids))
        entry = self.model[category][suffix]
        batch = self.sources / f'batch-{len(os.listdir(self.sources))}'
        batch.mkdir()
        sources = []
        for index, name in enumerate(names):
            folder = batch / str(index)
            folder.mkdir()
            path = folder / name
            path.write_bytes(contents.draw(CONTENT))
            sources.append(path)
        before = {path: path.read_bytes() for path in sources}
        target_id = self.directory(category, suffix).name.split(' ', 1)[0]
        argv = ['move', *map(str, sources), target_id]
        if force:
            argv.append('--force')
        if rename is not None:
            argv += ['--name', rename]

        final = [rename or path.name for path in sources]
        folded = [name.casefold() for name in final]
        existing = {name.casefold(): name for name in entry['files']}
        valid = (rename is None or len(sources) == 1) and len(set(folded)) == len(folded) \
            and all(force or key not in existing for key in folded)
        fail = fail and valid and len(sources) == 1

        def broken(*args, **kwargs):
            raise OSError('injected copy failure')

        with contextlib.ExitStack() as stack:
            if fail:
                stack.enter_context(patch.object(jd.shutil, 'copyfileobj', broken))
                stack.enter_context(patch.object(jd.shutil, 'copy2', broken))
            status, _, _ = run_cli(*argv)

        if not valid or fail:
            assert status == 1, (argv, entry['files'])
            for path, content in before.items():
                assert path.read_bytes() == content
            return
        assert status == 0, argv
        for path, name in zip(sources, final):
            assert not path.exists()
            key = name.casefold()
            name = existing.get(key, name)
            entry['files'][name] = before[path]
            existing[key] = name

    @rule(data=st.data(), text=st.text(st.characters(blacklist_categories=('Cs',),
                                                     blacklist_characters='\x00'),
                                       min_size=1, max_size=20))
    def note(self, data, text):
        ids = self.all_ids()
        if not ids:
            return
        category, suffix = data.draw(st.sampled_from(ids))
        title = self.directory(category, suffix).name
        identifier = title.split(' ', 1)[0]
        path = self.jdex / f'{identifier}.md'
        previous = path.read_bytes() if path.exists() else b''
        text = 'x' + text
        status, _, _ = run_cli('note', identifier, text)
        cleaned = text.replace('\r\n', '\n').replace('\r', '\n').strip('\n')
        if not cleaned.strip():
            return
        assert status == 0
        content = path.read_bytes()
        assert content.startswith(previous)
        # The appended bytes are exactly the note under the right headings.
        appended = content[len(previous):].replace(b'\r\n', b'\n').decode('utf-8')
        assert appended.endswith(cleaned + '\n\n'), (previous, appended)
        heading = appended[:-len(cleaned) - 2].strip('\n')
        today = f'## {date.today().isoformat()}'
        if not previous:
            assert heading == f'# {title}\n\n{today}', appended
        elif today.encode() in previous.splitlines():
            assert heading == '', appended
        else:
            assert heading == today, appended
        lines = content.decode('utf-8').splitlines()
        headers = [line for line in lines if line.startswith('## ') and line[3:4].isdigit()]
        assert len(headers) == len(set(headers))

    @invariant()
    def tree_matches_model(self):
        if not hasattr(self, 'model'):
            return
        for category, ids in self.model.items():
            folder = self.root / AREAS[category]
            on_disk = {path.name for path in folder.iterdir()}
            assert on_disk == {entry['name'] for entry in ids.values()}
            for entry in ids.values():
                directory = folder / entry['name']
                files = {path.name: path.read_bytes() for path in directory.iterdir()}
                assert files == entry['files']


JDMachine.TestCase.settings = settings(
    max_examples=1000 if hypothesis_profiles.LONG else 60, stateful_step_count=15)
TestJDMachine = JDMachine.TestCase


if __name__ == '__main__':
    unittest.main()
