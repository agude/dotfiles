set shell := ["bash", "-euo", "pipefail", "-c"]

# Run every static repository check.
lint: lint-shell lint-zsh lint-data lint-python

# Check tracked Bash and shared shell modules.
lint-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    files=()
    while IFS= read -r file; do
        case "$file" in
            zsh/*|vim/plugged/*) continue ;;
        esac
        files+=("$file")
    done < <(git ls-files '*.sh' '*.bash')
    shellcheck "${files[@]}"

# Parse every tracked Zsh module with Zsh itself.
lint-zsh:
    #!/usr/bin/env bash
    set -euo pipefail
    while IFS= read -r file; do
        zsh -n "$file"
    done < <(git ls-files '*.zsh')

# Validate tracked JSON documents.
lint-data:
    #!/usr/bin/env bash
    set -euo pipefail
    while IFS= read -r file; do
        jq empty "$file"
    done < <(git ls-files '*.json')

# Parse Python without writing bytecode caches.
lint-python:
    git ls-files -z '*.py' | xargs -0 python3 -c 'import ast, pathlib, sys; [ast.parse(pathlib.Path(path).read_text(), filename=path) for path in sys.argv[1:]]'

# Run every shell-based regression suite.
test-shell:
    bats tests/ llm/claude/hooks.d/tests/ llm/codex/hooks.d/tests/ llm/skills/johnny-decimal/tests/

# Run the PDF skill tests in their declared uv environment.
test-pdf:
    uv run llm/skills/pdf/tests/run.py

# Run every repository test suite.
test: test-shell test-pdf

# Run the complete local verification gate.
check: lint test
