#!/usr/bin/env bash
# Install the Pi packages declared by this dotfiles repository.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_MANIFEST="${SCRIPT_DIR}/../llm/pi/packages.conf"

if ! command -v pi >/dev/null 2>&1; then
    echo "Error: Pi is required. Install Pi, then run this command again." >&2
    exit 1
fi

if [[ ! -f "$PACKAGE_MANIFEST" ]]; then
    echo "Error: Pi package manifest does not exist: $PACKAGE_MANIFEST" >&2
    exit 1
fi

while IFS= read -r package_source || [[ -n "$package_source" ]]; do
    package_source="$(printf '%s' "$package_source" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

    [[ -z "$package_source" || "$package_source" == \#* ]] && continue

    echo "Installing Pi package: $package_source"
    pi install "$package_source"
done < "$PACKAGE_MANIFEST"
