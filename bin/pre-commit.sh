#!/usr/bin/env bash
# pre-commit hook: run ShellCheck on staged shell scripts.
#
# Skips zsh/ (shellcheck doesn't fully support zsh syntax) and vim/plugged/
# (third-party code). Matches the CI shellcheck configuration.

set -euo pipefail

# Collect staged .sh and .bash files, excluding directories we skip in CI.
files=()
while IFS= read -r f; do
    [[ -n "$f" ]] && files+=("$f")
done < <(
    git diff --cached --name-only --diff-filter=ACM -- '*.sh' '*.bash' |
        grep -vE '^(zsh/|vim/plugged/)' || true
)

if [[ ${#files[@]} -eq 0 ]]; then
    exit 0
fi

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "pre-commit: shellcheck not found, skipping lint" >&2
    exit 0
fi

shellcheck "${files[@]}"
