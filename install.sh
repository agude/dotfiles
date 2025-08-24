#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u

# --- Configuration and Helper Functions ---

# Find the absolute path of the dotfiles directory, so the script can be run from anywhere.
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# A safer and more informative link function.
link() {
    local target="$1"
    local source="$2" # Source is relative to the dotfiles directory

    # If the target exists (as file, dir, or link), remove it first.
    if [[ -e "$target" || -L "$target" ]]; then
        echo "→ Removing existing target: $target"
        rm -rf "$target"
    fi

    echo "✓ Linking: $DOTFILES_DIR/$source -> $target"
    ln -s "$DOTFILES_DIR/$source" "$target"
}

# --- Main Installation ---

echo "› Setting up shell configurations..."

# Source the XDG file to ensure $XDG_CONFIG_HOME is available for the rest of the script.
# NOTE: The path has been updated to the new shared location.
XDG_FILE="$DOTFILES_DIR/shared/sharedrc.d/001.xdg_base_directory.sh"
if [[ -f ${XDG_FILE} ]]; then
    source "${XDG_FILE}"
fi

# Link shell configuration files and directories
link "${HOME}/.bashrc" "bash/bashrc"
link "${HOME}/.bash_profile" "bash/bashrc"
link "${HOME}/.bash_login" "bash/bashrc"
link "${HOME}/.bashrc.d" "bash/bashrc.d"
link "${HOME}/.bash_logout" "bash/bash_logout"
link "${HOME}/.bashrc.profiler" "bash/bashrc.profiler"

link "${HOME}/.zshrc" "zsh/zshrc"
link "${HOME}/.zshrc.d" "zsh/zshrc.d"

# *** NEW: Link the shared directory ***
link "${HOME}/.sharedrc.d" "shared/sharedrc.d"

echo "› Linking other configuration files..."
link "${HOME}/.Xmodmap" "xmodmap/Xmodmap"
link "${HOME}/.astylerc" "astyle/astylerc"
link "${HOME}/.terminfo" "terminfo"
link "${HOME}/.editorconfig" "editorconfig/editorconfig"

echo "› Setting up ~/bin directory..."
mkdir -p "${HOME}/bin"
for full_path in "$DOTFILES_DIR/bin/"*; do
    script_file=${full_path##*/}
    script_name=${script_file%%.*}
    link "${HOME}/bin/${script_name}" "bin/${script_file}"
done

echo "› Setting up XDG config directories..."
mkdir -p "${XDG_CONFIG_HOME}"
for config_sub_directory in "$DOTFILES_DIR/config/"*; do
    program_directory=${config_sub_directory##*/}
    mkdir -p "${XDG_CONFIG_HOME}/${program_directory}"
    for full_file_path in "${config_sub_directory}/"*; do
        file_name="${full_file_path##*/}"
        link "${XDG_CONFIG_HOME}/${program_directory}/${file_name}" "config/${program_directory}/${file_name}"
    done
done

echo "› Setting up Vim and Neovim..."
link "${HOME}/.vim" "vim"
link "${HOME}/.vimrc" "vim/vimrc"
link "${HOME}/.gvimrc" "vim/gvimrc"
link "${HOME}/.ideavimrc" "vim/ideavimrc"
# Neovim uses the same config as Vim
link "${XDG_CONFIG_HOME}/nvim" "vim"

# Install plugins for both Vim and Neovim, if they exist.
if command -v vim &> /dev/null; then
    echo "› Installing Vim plugins..."
    vim +PlugInstall +qall
fi

if command -v nvim &> /dev/null; then
    echo "› Installing Neovim plugins..."
    nvim +PlugInstall +qall
fi

echo "✓ Installation complete!"
