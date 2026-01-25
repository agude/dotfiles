# shellcheck shell=bash
# Set the cargo path (supports both XDG and legacy locations)
CARGO_XDG_BIN="${XDG_DATA_HOME:-${HOME}/.local/share}/cargo/bin"
CARGO_LEGACY_BIN="${HOME}/.cargo/bin"

# Prefer XDG location, fall back to legacy
if [[ -d ${CARGO_XDG_BIN} ]]; then
    export PATH="${CARGO_XDG_BIN}:${PATH}"
elif [[ -d ${CARGO_LEGACY_BIN} ]]; then
    export PATH="${CARGO_LEGACY_BIN}:${PATH}"
fi

unset -v CARGO_XDG_BIN CARGO_LEGACY_BIN
