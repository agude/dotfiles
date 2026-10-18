#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Publish the dotfiles-owned Johnny.Decimal skill as ordinary files."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import uuid

SOURCE = Path(__file__).resolve().parents[1] / 'llm/skills/johnny-decimal'
MANIFEST = '.publish-manifest.json'
RESOURCES = ('SKILL.md', 'references', 'scripts', 'assets', 'agents')
TARGETS = ('.agents', '.claude')
WORKSPACE = SOURCE.parents[1] / 'johnnydecimal/workspace'


def fingerprint(directory):
    """Hash all deployed files; reject links rather than copying foreign data."""
    result = {}
    for path in sorted(directory.rglob('*')):
        if path.is_symlink():
            raise ValueError(f'Symlinks are not supported: {path}')
        if path.is_dir():
            result[path.relative_to(directory).as_posix() + '/'] = 'directory'
            continue
        if not path.is_file():
            raise ValueError(f'Not a regular file: {path}')
        relative = path.relative_to(directory).as_posix()
        if relative != MANIFEST:
            result[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def validate_destination(destination):
    for path in (destination.parent.parent, destination.parent, destination):
        if path.is_symlink():
            raise ValueError(f'Refusing symlink destination: {path}')
    if not destination.exists():
        return None
    manifest = destination / MANIFEST
    if not manifest.is_file():
        raise ValueError(f'Refusing unmanaged destination: {destination}')
    previous = json.loads(manifest.read_text(encoding='utf-8'))
    if previous != fingerprint(destination):
        raise ValueError(f'Destination has local changes; reconcile them first: {destination}')
    return previous


def publish_target(source, documents, target_name, dry_run=False):
    documents = documents.expanduser().resolve(strict=True)
    if not documents.is_dir():
        raise ValueError(f'Not a Documents directory: {documents}')
    agents = documents / target_name
    destination = agents / 'skills/johnny-decimal'
    # Never follow a skill link back into dotfiles or another installation.
    for path in (agents, destination.parent, destination):
        if path.is_symlink():
            raise ValueError(f'Refusing symlink destination: {path}')
    if not (source / 'SKILL.md').is_file():
        raise ValueError(f'Skill source missing: {source}')

    with tempfile.TemporaryDirectory(prefix='publish-jd-') as temporary:
        snapshot = Path(temporary) / 'johnny-decimal'
        snapshot.mkdir()
        for name in RESOURCES:
            item = source / name
            if item.is_symlink():
                raise ValueError(f'Symlinks are not supported: {item}')
            if item.is_dir():
                fingerprint(item)
                shutil.copytree(item, snapshot / name)
            elif item.is_file():
                shutil.copy(item, snapshot / name)
        current = fingerprint(snapshot)
        previous = validate_destination(destination)
        if previous == current:
            print(f'Already up to date: {destination}')
            return
        for name in sorted(current.keys() | (previous or {}).keys()):
            if current.get(name) != (previous or {}).get(name):
                action = 'Delete' if name not in current else 'Copy'
                print(f'{action}: {name}')
        if dry_run:
            print(f'Dry run: {destination}')
            return
        (snapshot / MANIFEST).write_text(json.dumps(current, indent=2) + '\n', encoding='utf-8')
        agents.mkdir(exist_ok=True)
        lock = agents / '.publish-jd.lock'
        try:
            lock.mkdir()
        except FileExistsError:
            raise ValueError(f'Publication lock exists: {lock}') from None
        try:
            # Stage on the destination filesystem before replacing the live copy.
            with tempfile.TemporaryDirectory(prefix='.publish-jd-', dir=agents) as staging:
                staged = Path(staging) / 'johnny-decimal'
                shutil.copytree(snapshot, staged, copy_function=shutil.copy)
                if fingerprint(staged) != current:
                    raise ValueError('Staged copy failed verification')
                if validate_destination(destination) != previous:
                    raise ValueError('Destination changed during publication; retry')
                destination.parent.mkdir(exist_ok=True)
                backup = None
                if destination.exists():
                    backup_root = agents / 'skill-backups'
                    if backup_root.is_symlink():
                        raise ValueError(f'Refusing symlink backup directory: {backup_root}')
                    backup_root.mkdir(exist_ok=True)
                    backup = backup_root / f'johnny-decimal-{uuid.uuid4().hex}'
                    destination.rename(backup)
                try:
                    staged.rename(destination)
                except OSError:
                    if backup is not None:
                        backup.rename(destination)
                    raise
                if backup is not None:
                    print(f'Previous version: {backup}')
        finally:
            lock.rmdir()
    print(f'Published: {destination}')


def publish(source, documents, dry_run=False):
    documents = documents.expanduser().resolve(strict=True)
    if not documents.is_dir():
        raise ValueError(f'Not a Documents directory: {documents}')
    # Check both copies before changing either; preserve edits made from Windows.
    for name in TARGETS:
        validate_destination(documents / name / 'skills/johnny-decimal')
    for name in TARGETS:
        publish_target(source, documents, name, dry_run)
    # Workspace instructions belong to the workspace owner after first setup.
    # Codex and Claude Code both read AGENTS.md, so no CLAUDE.md is seeded.
    template = WORKSPACE / 'AGENTS.md'
    destination = documents / 'AGENTS.md'
    if template.is_file() and not os.path.lexists(destination):
        print(f'Seed: {destination}')
        if not dry_run:
            with template.open('rb') as content, destination.open('xb') as output:
                shutil.copyfileobj(content, output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--documents', type=Path,
                        default=Path(os.environ.get('XDG_DOCUMENTS_DIR', str(Path.home() / 'Documents'))),
                        help='existing Documents root (default: XDG_DOCUMENTS_DIR or ~/Documents)')
    parser.add_argument('--dry-run', action='store_true', help='preview without writing to Documents')
    args = parser.parse_args()
    try:
        publish(SOURCE, args.documents, args.dry_run)
    except (OSError, ValueError) as error:
        parser.exit(1, f'publish-jd: {error}\n')


if __name__ == '__main__':
    main()
