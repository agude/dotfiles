# shellcheck shell=bash
# NVM (Node Version Manager) — lazy-loaded to avoid ~200-400ms startup cost.
# Defines stub functions for nvm/node/npm/npx that source nvm on first use.

if [ -d "$HOME/.config/nvm" ]; then
    export NVM_DIR="$HOME/.config/nvm"

    _load_nvm() {
        unset -f nvm node npm npx _load_nvm
        # shellcheck source=/dev/null
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        # shellcheck source=/dev/null
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    }

    nvm()  { _load_nvm; nvm  "$@"; }
    node() { _load_nvm; node "$@"; }
    npm()  { _load_nvm; npm  "$@"; }
    npx()  { _load_nvm; npx  "$@"; }
fi
