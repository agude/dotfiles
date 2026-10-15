#!/usr/bin/env bash
# Validate a tag against the package version before artifact publication.

set -euo pipefail

version_file="$(find src -mindepth 2 -maxdepth 2 -name __init__.py -print -quit)"
[ -n "$version_file" ] || { echo "release: cannot find src/*/__init__.py" >&2; exit 1; }
version="$(awk -F'"' '/^__version__/ {print $2; exit}' "$version_file")"
[ -n "$version" ] || { echo "release: cannot read __version__ from $version_file" >&2; exit 1; }

tag="${GITHUB_REF_NAME:-${1:-}}"
case "$tag" in
    "") echo "release: no tag context; version $version is valid" ;;
    v*)
        [ "${tag#v}" = "$version" ] || {
            echo "release: tag '$tag' does not match package version '$version'" >&2
            exit 1
        }
        echo "release: tag '$tag' matches package version '$version'"
        ;;
    *) echo "release: expected a v<version> tag, got '$tag'" >&2; exit 1 ;;
esac
