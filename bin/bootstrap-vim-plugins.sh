#!/usr/bin/env bash
# Install vim-plug and synchronize Vim or Neovim plugins.

set -euo pipefail

if command -v nvim >/dev/null 2>&1; then
    EDITOR_COMMAND=nvim
elif command -v vim >/dev/null 2>&1; then
    EDITOR_COMMAND=vim
else
    echo "Error: Vim or Neovim is required." >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required." >&2
    exit 1
fi

PLUG_PATH="${HOME}/.vim/autoload/plug.vim"
PLUG_TEMP="${PLUG_PATH}.tmp.$$"
mkdir -p "$(dirname "$PLUG_PATH")"
trap 'rm -f "$PLUG_TEMP"' EXIT HUP INT TERM

curl --fail --location --output "$PLUG_TEMP" \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
mv "$PLUG_TEMP" "$PLUG_PATH"
trap - EXIT HUP INT TERM

if [[ "$EDITOR_COMMAND" == "nvim" ]]; then
    nvim --headless "+PlugInstall --sync" +qa
else
    vim -T dumb -i NONE -c "PlugInstall --sync" -c qall!
fi
