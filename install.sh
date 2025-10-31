#!/usr/bin/env bash
#
# Dotfiles Installation Script
#
# This script sets up the user's environment by creating symbolic links from the
# home directory to the configuration files stored in this repository. It also
# performs one-time setup tasks like configuring XDG user directories.

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u

# --- Configuration and Helper Functions ---

# Find the absolute path of the dotfiles directory, so the script can be run from anywhere.
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# A safer and more informative link function.
# It removes any existing file, directory, or symlink at the target location
# before creating the new symlink.
link() {
    local target="$1"
    local source="$2" # Source is relative to the dotfiles directory

    if [[ -e "$target" || -L "$target" ]]; then
        echo "  -> Removing existing target: $target"
        rm -rf "$target"
    fi

    echo "  -> Linking: $DOTFILES_DIR/$source -> $target"
    ln -s "$DOTFILES_DIR/$source" "$target"
}

# --- Main Installation ---

echo "› Linking shell configurations..."
link "${HOME}/.bashrc" "bash/bashrc"
link "${HOME}/.bash_profile" "bash/bashrc"
link "${HOME}/.bash_login" "bash/bashrc"
link "${HOME}/.bashrc.d" "bash/bashrc.d"
link "${HOME}/.bash_logout" "bash/bash_logout"
link "${HOME}/.bashrc.profiler" "bash/bashrc.profiler"

link "${HOME}/.zshrc" "zsh/zshrc"
link "${HOME}/.zshrc.d" "zsh/zshrc.d"

link "${HOME}/.sharedrc.d" "shared/sharedrc.d"

echo "› Linking core configuration files..."
link "${HOME}/.Xmodmap" "xmodmap/Xmodmap"
link "${HOME}/.astylerc" "astyle/astylerc"
link "${HOME}/.terminfo" "terminfo"
link "${HOME}/.editorconfig" "editorconfig/editorconfig"

echo "› Setting up executable scripts in ~/bin..."
mkdir -p "${HOME}/bin"
# Loop through each file in the dotfiles/bin directory.
for full_path in "$DOTFILES_DIR/bin/"*; do
    script_file=${full_path##*/}
    script_name=${script_file%%.*}
    # Link the file into ~/bin, stripping its original extension.
    link "${HOME}/bin/${script_name}" "bin/${script_file}"
done

echo "› Setting up XDG configuration directories..."
# Source the XDG file to ensure $XDG_CONFIG_HOME is available for the rest of the script.
XDG_FILE="$DOTFILES_DIR/shared/sharedrc.d/001.xdg_base_directory.sh"
if [[ -f ${XDG_FILE} ]]; then
    source "${XDG_FILE}"
fi

mkdir -p "${XDG_CONFIG_HOME}"
# This loop automatically links any directory in dotfiles/config into ~/.config.
for config_sub_directory in "$DOTFILES_DIR/config/"*; do
    program_directory=${config_sub_directory##*/}
    mkdir -p "${XDG_CONFIG_HOME}/${program_directory}"
    for full_file_path in "${config_sub_directory}/"*; do
        file_name="${full_file_path##*/}"
        link "${XDG_CONFIG_HOME}/${program_directory}/${file_name}" "config/${program_directory}/${file_name}"
    done
done

echo "› Configuring XDG User Directories for the graphical session..."
# This ensures the ~/.config/user-dirs.dirs file is correctly set up
# for graphical environments (like GNOME, KDE, MATE) to find the right folders.
if command -v xdg-user-dirs-update &> /dev/null; then
    xdg-user-dirs-update --set DESKTOP "${HOME}/Desktop"
    xdg-user-dirs-update --set DOCUMENTS "${HOME}/Documents"
    xdg-user-dirs-update --set DOWNLOAD "${HOME}/Downloads"
    xdg-user-dirs-update --set MUSIC "${HOME}/Music"
    xdg-user-dirs-update --set PICTURES "${HOME}/Pictures"
    xdg-user-dirs-update --set VIDEOS "${HOME}/Videos"

    # Create the directories if they don't exist to be thorough.
    mkdir -p "${HOME}/Desktop" "${HOME}/Documents" "${HOME}/Downloads" \
             "${HOME}/Music" "${HOME}/Pictures" "${HOME}/Videos" \
             "${HOME}/Templates" "${HOME}/Public"
else
    echo "  -> Skipping: xdg-user-dirs-update command not found."
fi

echo "› Setting up Vim and Neovim..."
link "${HOME}/.vim" "vim"
link "${HOME}/.vimrc" "vim/vimrc"
link "${HOME}/.gvimrc" "vim/gvimrc"
link "${HOME}/.ideavimrc" "vim/ideavimrc"

# Neovim uses the same config as Vim, linked into its XDG-compliant directory.
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

echo
echo "✓ Dotfiles installation complete!"
echo "Note: Some changes may require a new shell session or a full logout/login to take effect."
