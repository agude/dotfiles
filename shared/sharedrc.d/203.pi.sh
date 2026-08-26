# shellcheck shell=bash
#
# Pi coding agent (@earendil-works/pi-coding-agent)
#
# Adds pi's private node bin directory to PATH. The installer keeps a
# `current` symlink pointing at the active node version, so this survives
# version upgrades.

_pi_bin="${HOME}/.local/share/pi-node/current/bin"
if [[ -d "$_pi_bin" ]] && [[ ":${PATH}:" != *":${_pi_bin}:"* ]]; then
    # Append rather than prepend: the dir bundles node/npm/npx/corepack and
    # must not shadow any other Node toolchain.
    PATH="${PATH}:${_pi_bin}"
fi
unset _pi_bin
