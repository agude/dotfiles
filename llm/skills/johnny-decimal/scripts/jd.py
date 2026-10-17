#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Operate on local Johnny.Decimal files on Windows, macOS, and Linux."""

from __future__ import annotations

import argparse
from datetime import date
import json
import os
from pathlib import Path, PureWindowsPath
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

JDEX = Path('00-09 System/00 System/00.00 JDex for System')
ID_PATTERN = r'[0-9]{2}\.[0-9]+'
AREA_PATTERN = r'[0-9]{2}-[0-9]{2} .+'
CATEGORY_PATTERN = r'[0-9]{2} .+'


class JDException(ValueError):
    """An invalid request that must not change the document tree."""


def paths(environment=None, script=None):
    """Prefer explicit overrides, then the deployed workspace, then host config."""
    environment = os.environ if environment is None else environment
    script = Path(__file__) if script is None else Path(script)
    skill = script.resolve().parent.parent
    home_value = (environment.get('USERPROFILE') if os.name == 'nt' else environment.get('HOME'))
    home = Path(home_value or environment.get('HOME') or Path.home()).expanduser().resolve()
    deployed = skill.parent.name == 'skills' and skill.parent.parent.name == '.agents'
    workspace = skill.parent.parent.parent if deployed else None
    if workspace == home:
        workspace = None  # A real copy in the user-global skills directory.
    documents = environment.get('XDG_DOCUMENTS_DIR') or str(home / 'Documents')
    config_home = environment.get('XDG_CONFIG_HOME') or str(home / '.config')
    config_path = Path(environment.get('JD_CONFIG') or
                       str(Path(config_home) / 'johnnydecimal/config.json'))
    config = {}
    # A host's implicit config must not redirect a deployed NAS skill elsewhere.
    if (workspace is None or environment.get('JD_CONFIG')) and config_path.exists():
        config = json.loads(config_path.read_text(encoding='utf-8'))
        if not isinstance(config, dict):
            raise JDException(f'Configuration must be a JSON object: {config_path}')

    variables = dict(HOME=str(home), XDG_DOCUMENTS_DIR=documents,
                     XDG_CONFIG_HOME=config_home)

    def expand(value):
        if not isinstance(value, str) or not value:
            raise JDException('Configured paths must be nonempty strings')
        return Path(re.sub(r'\$\{(\w+)\}|\$(\w+)',
                           lambda match: variables.get(match[1] or match[2], match[0]),
                           value)).expanduser().resolve()

    root = expand(environment.get('JD_ROOT') or config.get('root') or
                  str(workspace or documents))
    jdex = expand(environment.get('JDEX_PATH') or config.get('jdex') or str(root / JDEX))
    return root, jdex


def directories(parent, pattern):
    return sorted((path for path in parent.iterdir()
                   if path.is_dir() and not path.is_symlink()
                   and re.fullmatch(pattern, path.name)), key=lambda path: path.name)


def unique(parent, pattern, description):
    matches = directories(parent, pattern)
    if not matches:
        raise JDException(f'No {description} found')
    if len(matches) != 1:
        raise JDException(f'Ambiguous {description}: {", ".join(p.name for p in matches)}')
    return matches[0]


def location(root, query):
    if not query:
        return root
    if re.fullmatch(r'[0-9]{2}-[0-9]*|[0-9]0', query):
        return unique(root, re.escape(query[:2]) + r'-[0-9]{2} .+', f'area for {query}')
    if not re.fullmatch(r'[0-9]{2}|' + ID_PATTERN, query):
        raise JDException(f'Invalid query format: {query}')
    category = query[:2]
    area = unique(root, category[0] + r'0-[0-9]{2} .+', f'area for {query}')
    folder = unique(area, category + r' .+', f'category for {query}')
    if '.' in query:
        return unique(folder, re.escape(query) + r' .+', f'subcategory for {query}')
    return folder


def identifier(value):
    if not re.fullmatch(ID_PATTERN, value):
        raise JDException(f'Invalid ID format: {value}. Expected XX.YY')
    return value


def safe_name(name):
    """Reject names Windows cannot represent, including paths and ADS syntax."""
    if (not name or name in ('.', '..') or name.endswith((' ', '.'))
            or re.search(r'[<>:"/\\|?*\x00-\x1f\x7f]', name)
            or re.fullmatch(r'(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])', name.split('.')[0])):
        raise JDException(f'Invalid name: {name!r}')
    return name


def child_path(parent, relative):
    """Accept slash or backslash separators, without traversal or drive paths."""
    windows = PureWindowsPath(relative)
    parts = relative.replace('\\', '/').split('/')
    if windows.drive or windows.root or any(part in ('', '.', '..') for part in parts):
        raise JDException(f'Invalid relative path: {relative!r}')
    result = parent
    for part in parts:
        result = result / safe_name(part)
        if result.is_symlink():
            raise JDException(f'Symlink destination is not supported: {result}')
        if not result.resolve().is_relative_to(parent.resolve()):
            raise JDException(f'Destination escapes the ID directory: {result}')
    return result


def collision(path):
    """Use Windows collision rules even when publishing/filing from Linux."""
    if not path.parent.exists():
        return None
    return next((item for item in path.parent.iterdir()
                 if item.name.casefold() == path.name.casefold()), None)


def interactive(args):
    return not args.porcelain and sys.stdin.isatty() and sys.stdout.isatty()


def browse(root):
    parent = root
    for pattern in (AREA_PATTERN, CATEGORY_PATTERN, ID_PATTERN + r' .+'):
        choices = directories(parent, pattern)
        if not choices:
            raise JDException(f'No folders to select in {parent}')
        for number, path in enumerate(choices, 1):
            print(f'{number}: {path.name}', file=sys.stderr)
        while True:
            print('Enter number: ', end='', file=sys.stderr, flush=True)
            try:
                number = int(input())
                if 1 <= number <= len(choices):
                    parent = choices[number - 1]
                    break
            except ValueError:
                pass
    return parent.name.split(' ', 1)[0]


def display(path, args):
    print(path if args.porcelain else path.name)


def search(root, args):
    query = args.query.strip().casefold()
    matches = []
    pending = [(root, 0)]
    while pending:
        parent, depth = pending.pop()
        pattern = (AREA_PATTERN, CATEGORY_PATTERN, ID_PATTERN + r' .+')[depth]
        for path in directories(parent, pattern):
            name = path.name.casefold()
            if re.match(r'[0-9]{2}-', query):
                matched = depth == 0 and name.startswith(query)
            elif re.fullmatch(r'[0-9]{2}', query):
                matched = depth == 1 and name.startswith(query + ' ')
            elif re.match(r'[0-9]{2}\.', query):
                matched = depth == 2 and name.startswith(query)
            else:
                matched = query in name
            if matched:
                matches.append(path)
            if depth < 2:
                pending.append((path, depth + 1))
    if not matches:
        raise JDException(f'No matches for {args.query!r}')
    for path in sorted(matches):
        display(path, args)


def list_location(root, args):
    query = args.query
    if query is None and interactive(args):
        query = browse(root)
    parent = location(root, query)
    if query and re.fullmatch(ID_PATTERN, query):
        if args.porcelain and not args.files:
            print(parent)
        else:
            for path in sorted(parent.iterdir()):
                print(path if args.porcelain else path.name + ('/' if path.is_dir() else ''))
    else:
        pattern = AREA_PATTERN if not query else (
            CATEGORY_PATTERN if '-' in parent.name[:5] else ID_PATTERN + r' .+')
        for path in directories(parent, pattern):
            display(path, args)


def tree(root, args):
    if args.depth < 1:
        raise JDException('Depth must be positive')
    parent = location(root, args.query)
    print(parent)

    def walk(directory, depth):
        if depth > args.depth:
            return
        for path in sorted(directory.iterdir(), key=lambda path: [
                (0, int(part)) if part.isdigit() else (1, part.casefold())
                for part in re.split(r'([0-9]+)', path.name)]):
            if path.is_dir() and not path.is_symlink() and not path.name.startswith('.'):
                print(path if args.porcelain else '  ' * depth + path.name)
                walk(path, depth + 1)
    walk(parent, 1)


def validate(args):
    failed = False
    for filename in args.files:
        name = filename.replace('\\', '/').rsplit('/', 1)[-1]
        warnings = []
        if ' ' in name:
            warnings.append('Contains spaces - prefer underscores')
        if (not re.match(r'[0-9]{4}[-_]?[0-9]{2}[-_]?[0-9]{2}', name)
                and re.search(r'statement|receipt|invoice|bill|check|paystub', name)):
            warnings.append('Transient document without date prefix - consider YYYY-MM-DD_name.ext')
        try:
            safe_name(name)
            if re.search(r"['`$&;]", name):
                raise JDException('Contains problematic special characters')
        except JDException as error:
            print(f'ERROR:{name}:{error}')
            failed = True
        else:
            print(f'WARN:{name}:{" ".join(warnings)}' if warnings else f'OK:{name}')
    return int(failed)


def mkdir(root, args):
    safe_name(args.name)
    if re.fullmatch(ID_PATTERN, args.query):
        if args.id is not None:
            raise JDException('--id is not supported inside an existing ID')
        destination = location(root, args.query) / args.name
    else:
        if not re.fullmatch(r'[0-9]{2}', args.query):
            raise JDException('Invalid category format; expected XX or XX.YY')
        # Categories ending in zero are area queries to `location`, so resolve
        # the actual category explicitly when creating IDs.
        area = unique(root, args.query[0] + r'0-[0-9]{2} .+', 'area')
        category = unique(area, args.query + r' .+', 'category')
        existing = directories(category, re.escape(args.query) + r'\.[0-9]+ .+')
        number = max([9] + [int(p.name.split(' ', 1)[0].split('.')[1]) for p in existing]) + 1
        suffix = args.id if args.id is not None else str(number)
        if not re.fullmatch(r'[0-9]+', suffix):
            raise JDException('--id must be a number')
        prefix = args.query + '.' + suffix
        if any(int(p.name.split(' ', 1)[0].split('.')[1]) == int(suffix) for p in existing):
            raise JDException(f'ID already exists: {prefix}')
        destination = category / f'{prefix} {args.name}'
    if collision(destination):
        raise JDException(f'Folder already exists: {destination}')
    if not args.dry_run:
        destination.mkdir(mode=0o700)
    print(destination if args.porcelain else
          f'{"Would create" if args.dry_run else "Created"}: {destination.name}')


def transfer(source, destination, force):
    """Reserve a new target exclusively; remove the source only after copying."""
    if source.is_dir():
        destination.mkdir(mode=0o700)
        try:
            shutil.copytree(source, destination, dirs_exist_ok=True, symlinks=True)
        except BaseException:
            shutil.rmtree(destination)
            raise
        shutil.rmtree(source)
        return
    if force and destination.exists():
        with tempfile.TemporaryDirectory(prefix='.jd-move-', dir=destination.parent) as temporary:
            staged = Path(temporary) / 'file'
            shutil.copy2(source, staged)
            os.replace(staged, destination)
    else:
        # `shutil.move` can overwrite a concurrently created POSIX target.
        output = destination.open('xb')
        try:
            with output:
                with source.open('rb') as content:
                    shutil.copyfileobj(content, output)
            shutil.copystat(source, destination)
        except BaseException:
            destination.unlink()
            raise
    source.unlink()


def move(root, args):
    target_id = '00.01' if args.command == 'inbox' else args.files[-1]
    identifier(target_id)
    sources = args.files if args.command == 'inbox' else args.files[:-1]
    if not sources:
        raise JDException('At least one source is required')
    if args.name and len(sources) != 1:
        raise JDException('--name requires a single source')
    parent = location(root, target_id)
    if args.subdir:
        parent = child_path(parent, args.subdir)
    planned = []
    destinations = set()
    for name in sources:
        source = Path(name).expanduser().absolute()
        if source.is_symlink() or not source.exists():
            raise JDException(f'Source not found or is a symlink: {source}')
        if not source.is_dir() and not source.is_file():
            raise JDException(f'Source must be a regular file or directory: {source}')
        destination = parent / safe_name(args.name or source.name)
        key = str(destination).casefold()
        if key in destinations:
            raise JDException(f'Duplicate destination: {destination}')
        destinations.add(key)
        existing = collision(destination)
        if existing:
            if not args.force:
                raise JDException(f'Target already exists: {existing}')
            if existing.is_symlink() or not existing.is_file() or source.is_dir():
                raise JDException('--force only replaces regular files')
            destination = existing
        if source.resolve() == destination.resolve() or source.resolve() in destination.resolve().parents:
            raise JDException('Cannot move a source onto or inside itself')
        planned.append((source, destination))
    for index, (source, _) in enumerate(planned):
        for other, _ in planned[index + 1:]:
            if (source.resolve() == other.resolve() or source.resolve() in other.resolve().parents
                    or other.resolve() in source.resolve().parents):
                raise JDException('Sources must not repeat or contain each other')
    source_paths = {source.resolve() for source, _ in planned}
    if any(destination.resolve() in source_paths for _, destination in planned):
        raise JDException('A destination cannot replace another source in the batch')
    if not args.dry_run:
        parent.mkdir(parents=True, exist_ok=True)
    for source, destination in planned:
        if not args.dry_run:
            transfer(source, destination, args.force)
        print(destination if args.porcelain else
              f'{"Would move" if args.dry_run else "Moved"}: {source.name} -> {destination}')


def edit(path):
    editor = os.environ.get('EDITOR') or os.environ.get('VISUAL')
    if not editor:
        editor = 'notepad' if os.name == 'nt' else 'vi'
    # An existing executable path may contain spaces on Windows.
    command = [editor] if Path(editor).is_file() else shlex.split(editor, posix=os.name != 'nt')
    subprocess.run([*command, str(path)], check=True)


def notes(root, jdex, args):
    selected = args.query
    if selected is None:
        if not interactive(args):
            raise JDException('An ID is required in non-interactive mode')
        selected = browse(root)
    identifier(selected)
    if not jdex.is_dir():
        raise JDException(f'JDex directory not found: {jdex}')
    path = jdex / f'{selected}.md'
    if path.is_symlink():
        raise JDException(f'Symlink note is not supported: {path}')
    try:
        title = location(root, selected).name
    except JDException:
        title = selected + ' Unknown'
    if args.command == 'read':
        if args.edit:
            if not interactive(args):
                raise JDException('--edit requires interactive mode')
            if not path.exists():
                with path.open('x', encoding='utf-8') as output:
                    output.write(f'# {title}\n\n')
            edit(path)
        elif path.exists():
            print(path if args.porcelain else path.read_text(encoding='utf-8'),
                  end='\n' if args.porcelain else '')
        else:
            print(f'No notes found for {selected}', file=sys.stderr)
        return
    text = ' '.join(args.text)
    if not text:
        if not interactive(args):
            raise JDException('Note text required in non-interactive mode')
        with tempfile.TemporaryDirectory(prefix='jd-note-') as temporary:
            draft = Path(temporary) / 'note.md'
            draft.write_text('', encoding='utf-8')
            edit(draft)
            text = draft.read_text(encoding='utf-8').strip()
        if not text:
            return
    today = f'## {date.today().isoformat()}'
    # Read and append under a lock rather than rewriting existing note history.
    lock = jdex / f'.{selected}.lock'
    try:
        lock.mkdir()
    except FileExistsError:
        raise JDException(f'Note is locked: {lock}') from None
    try:
        if path.exists():
            content = path.read_text(encoding='utf-8')
            addition = f'\n{text}\n\n' if today in content.splitlines() else f'\n{today}\n\n{text}\n\n'
            with path.open('a', encoding='utf-8') as output:
                output.write(addition)
        else:
            with path.open('x', encoding='utf-8') as output:
                output.write(f'# {title}\n\n{today}\n\n{text}\n\n')
    finally:
        lock.rmdir()
    print(path if args.porcelain else f'Added note to {selected}.md')


def parser():
    result = argparse.ArgumentParser(description=__doc__, usage='Usage: %(prog)s <command> [options]')
    commands = result.add_subparsers(dest='command', required=True)
    for name in ('search', 'list', 'tree', 'validate', 'mkdir', 'move', 'inbox', 'read', 'note'):
        command = commands.add_parser(name)
        command.add_argument('--porcelain', action='store_true', help='plain, absolute output; never prompt')
        if name == 'search':
            command.add_argument('query')
        elif name in ('list', 'tree', 'read', 'note'):
            command.add_argument('query', nargs='?')
        if name == 'list':
            command.add_argument('--files', action='store_true', help='list entries within an ID in porcelain mode')
        if name == 'tree':
            command.add_argument('-L', '--depth', type=int, default=2)
        if name == 'validate':
            command.add_argument('files', nargs='+')
        if name == 'mkdir':
            command.add_argument('query')
            command.add_argument('name')
            command.add_argument('--id')
        if name in ('move', 'inbox'):
            command.add_argument('files', nargs='+', help='source(s), followed by target ID for move')
            command.add_argument('--name')
            command.add_argument('--subdir')
            command.add_argument('-f', '--force', action='store_true')
        if name in ('mkdir', 'move', 'inbox'):
            command.add_argument('-n', '--dry-run', action='store_true')
        if name == 'read':
            command.add_argument('-e', '--edit', action='store_true')
        if name == 'note':
            command.add_argument('text', nargs='*')
    return result


def main(argv=None):
    # Keep machine-readable paths and diagnostics UTF-8 when Windows pipes output.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, 'reconfigure'):
            stream.reconfigure(encoding='utf-8')
    args = parser().parse_args(argv)
    try:
        if args.command == 'validate':
            return validate(args)
        root, jdex = paths()
        if not root.is_dir():
            raise JDException(f'JD_ROOT does not exist: {root}')
        if args.command in ('read', 'note'):
            notes(root, jdex, args)
        else:
            handlers = dict(search=search, list=list_location, tree=tree, mkdir=mkdir,
                            move=move, inbox=move)
            handlers[args.command](root, args)
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError, EOFError) as error:
        print(f'Error: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
