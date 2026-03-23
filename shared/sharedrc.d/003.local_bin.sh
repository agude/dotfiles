# shellcheck shell=bash
#
# Add ~/.local/bin to PATH
#
# Many tools (pip, pipx, Claude Code, etc.) install executables here.

if [[ -d "${HOME}/.local/bin" ]]; then
    PATH="${HOME}/.local/bin:${PATH}"
fi
