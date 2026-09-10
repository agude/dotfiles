set shell := ["bash", "-euo", "pipefail", "-c"]

[private]
default:
    @just --list

# Install dotfiles (flags: --profile NAME, --dry-run, --show).
install *ARGS:
    ./install.sh {{ARGS}}

# Install dotfiles and synchronize editor plugins.
bootstrap *ARGS:
    ./install.sh {{ARGS}}
    ./bin/bootstrap-vim-plugins.sh

# Install the pinned, network-dependent Pi packages.
bootstrap-pi:
    ./bin/bootstrap-pi-packages.sh

# Run every static check.
lint: lint-shell lint-zsh lint-data lint-python lint-opencode

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

# Validate the OpenCode config against the installed OpenCode.
#
# OpenCode's own validator is the only source of truth that cannot drift from
# the binary in use: permission keys differ in shape (bash takes a pattern map,
# webfetch takes a bare action), and a vendored schema would eventually reject
# valid configs. Skipped when OpenCode is not installed, so CI stays green.
lint-opencode CONFIG="llm/opencode/opencode.json":
    #!/usr/bin/env bash
    set -euo pipefail
    binary="$(command -v opencode || true)"
    if [[ -z "$binary" ]] && [[ -x "${HOME}/.opencode/bin/opencode" ]]; then
        binary="${HOME}/.opencode/bin/opencode"
    fi
    if [[ -z "$binary" ]]; then
        echo "lint-opencode: opencode not installed, skipping {{CONFIG}}"
        exit 0
    fi
    config="$(cd "$(dirname '{{CONFIG}}')" && pwd)/$(basename '{{CONFIG}}')"
    root="$(mktemp -d)"
    trap 'rm -rf "$root"' EXIT
    mkdir -p "$root/config/opencode" "$root/project"
    cp "$config" "$root/config/opencode/opencode.json"
    # An empty project directory and a scratch XDG root keep the real user and
    # project configs out of the merge; --pure keeps plugins from loading.
    cd "$root/project"
    if ! XDG_CONFIG_HOME="$root/config" \
         XDG_DATA_HOME="$root/data" \
         XDG_CACHE_HOME="$root/cache" \
         XDG_STATE_HOME="$root/state" \
         "$binary" debug config --pure > /dev/null; then
        echo "lint-opencode: {{CONFIG}} is rejected by opencode $("$binary" --version)" >&2
        exit 1
    fi

# Parse Python without writing bytecode caches.
lint-python:
    git ls-files -z '*.py' | xargs -0 python3 -c 'import ast, pathlib, sys; [ast.parse(pathlib.Path(path).read_text(), filename=path) for path in sys.argv[1:]]'

# Run every test suite.
test: test-shell test-python test-pdf test-integration

# Run shell-based regression suites.
test-shell:
    bats tests/ llm/claude/hooks.d/tests/ llm/codex/hooks.d/tests/ llm/skills/johnny-decimal/tests/ llm/skills/skill-creator/tests/

# Run Python tests for the shared command guard.
test-python:
    uv run tests/test_command_guard.py -q

# Run PDF skill tests.
test-pdf:
    uv run llm/skills/pdf/tests/run.py

# Install and verify in an isolated throwaway HOME.
test-integration:
    #!/usr/bin/env bash
    set -euo pipefail
    DOTFILES_DIR="$(pwd)"
    TEST_HOME="$(mktemp -d)"
    STASH_DIR="$(mktemp -d)"
    cleanup() {
        for f in .link-manifest .active-profile; do
            if [[ -f "${STASH_DIR}/${f}" ]]; then
                mv "${STASH_DIR}/${f}" "${DOTFILES_DIR}/${f}"
            else
                rm -f "${DOTFILES_DIR}/${f}"
            fi
        done
        rm -rf "$TEST_HOME" "$STASH_DIR"
    }
    trap cleanup EXIT
    for f in .link-manifest .active-profile; do
        [[ -f "${DOTFILES_DIR}/${f}" ]] && mv "${DOTFILES_DIR}/${f}" "${STASH_DIR}/${f}"
    done
    export HOME="$TEST_HOME"
    export XDG_CONFIG_HOME="$TEST_HOME/.config"
    export XDG_DATA_HOME="$TEST_HOME/.local/share"
    export XDG_CACHE_HOME="$TEST_HOME/.cache"
    export XDG_STATE_HOME="$TEST_HOME/.local/state"
    # Keep the first-run profile selection non-interactive when just test runs
    # from a terminal.
    ./install.sh </dev/null
    [[ -L "$TEST_HOME/.codex/themes/eldar.tmTheme" ]]
    [[ "$(readlink "$TEST_HOME/.codex/themes/eldar.tmTheme")" == "$DOTFILES_DIR/llm/codex/themes/eldar.tmTheme" ]]
    ./install.sh
    ./install.sh --dry-run
    ./install.sh --profile server
    if command -v nvim &>/dev/null; then
        nvim --headless +qall
    elif command -v vim &>/dev/null; then
        vim -T dumb -i NONE -c qall! 2>/dev/null
    fi
    bash -i -c 'source "${HOME}/.bashrc"; exit 0'
    zsh -i -c 'source "${HOME}/.zshrc"; exit 0'

# Run the complete verification gate.
check: lint test
