#!/usr/bin/env bash
# Prepare a local release tag. This never pushes or publishes.

set -euo pipefail

dry_run="false"
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) dry_run="true"; shift ;;
        -h|--help)
            echo "Usage: just release [--dry-run]"
            exit 0
            ;;
        *) echo "release: unknown option: $1" >&2; exit 2 ;;
    esac
done

version_file="$(find src -mindepth 2 -maxdepth 2 -name __init__.py -print -quit)"
[ -n "$version_file" ] || { echo "release: cannot find src/*/__init__.py" >&2; exit 1; }
version="$(awk -F'"' '/^__version__/ {print $2; exit}' "$version_file")"
[ -n "$version" ] || { echo "release: cannot read __version__ from $version_file" >&2; exit 1; }
tag="v$version"

git diff --quiet || { echo "release: working tree is dirty" >&2; exit 1; }
git diff --cached --quiet || { echo "release: index is dirty" >&2; exit 1; }
if git tag --list "$tag" | grep -qx "$tag"; then
    echo "release: tag '$tag' already exists" >&2
    exit 1
fi

echo "release: validating $tag"
just check
if [ "$dry_run" = "true" ]; then
    echo "release: dry run; would create local tag '$tag'"
else
    git tag "$tag"
    echo "release: created local tag '$tag'; push it explicitly when ready"
fi
