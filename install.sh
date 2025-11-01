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

# Source the platform detection script to set the PLATFORM variable.
PLATFORM_SCRIPT="${DOTFILES_DIR}/shared/sharedrc.d/000.set_platform.sh"
if [[ -f "${PLATFORM_SCRIPT}" ]]; then
    source "${PLATFORM_SCRIPT}"
fi

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

# Link generic config directories, skipping special cases handled later.
for config_sub_directory in "$DOTFILES_DIR/config/"*; do
    program_directory=${config_sub_directory##*/}
    # Skip directories that require special handling.
    if [[ "$program_directory" == "systemd" || "$program_directory" == "launchd" ]]; then
        continue
    fi
    link "${XDG_CONFIG_HOME}/${program_directory}" "config/${program_directory}"
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

echo "› Setting up automated cleanup tasks..."
if [[ "${PLATFORM}" == "linux" ]]; then
    if command -v systemctl &> /dev/null; then
        echo "  -> Setting up systemd user service for emptying Downloads..."
        SYSTEMD_USER_DIR="${XDG_CONFIG_HOME}/systemd/user"
        SERVICE_FILE="${SYSTEMD_USER_DIR}/empty-downloads.service"
        SOURCE_SERVICE_FILE="${DOTFILES_DIR}/config/systemd/user/empty-downloads.service"

        # Fix bad state: if the target directory is a symlink, remove it.
        if [[ -L "${SYSTEMD_USER_DIR}" ]]; then
            rm -f "${SYSTEMD_USER_DIR}"
        fi
        mkdir -p "${SYSTEMD_USER_DIR}"

        # Systemd requires a real file, not a symlink, for 'enable'.
        echo "  -> Copying systemd service file (required by systemctl)..."
        cp "${SOURCE_SERVICE_FILE}" "${SERVICE_FILE}"

        # Attempt to reload and enable, but don't fail the script if the user session isn't running.
        systemctl --user daemon-reload || true
        systemctl --user enable --now empty-downloads.service >/dev/null 2>&1 || echo "  -> Warning: Failed to enable systemd service. This may be expected in a non-interactive session."
    else
        echo "  -> Skipping systemd setup: systemctl command not found."
    fi
elif [[ "${PLATFORM}" == "mac" ]]; then
    if command -v launchctl &> /dev/null; then
        echo "  -> Setting up launchd agent for emptying Downloads..."
        LAUNCHD_DIR="${HOME}/Library/LaunchAgents"
        PLIST_FILE="${LAUNCHD_DIR}/com.user.empty-downloads.plist"

        # Fix bad state: if the target directory is a symlink, remove it.
        if [[ -L "${LAUNCHD_DIR}" ]]; then
            rm -f "${LAUNCHD_DIR}"
        fi
        mkdir -p "${LAUNCHD_DIR}"

        # Link the plist file into the real directory.
        link "${PLIST_FILE}" "config/launchd/com.user.empty-downloads.plist"

        # Unload the service first in case it's already running, then load it.
        launchctl unload "${PLIST_FILE}" 2>/dev/null || true
        launchctl load "${PLIST_FILE}" >/dev/null 2>&1 || echo "  -> Warning: Failed to load launchd agent. This may be expected in a non-interactive session."
    else
        echo "  -> Skipping launchd setup: launchctl command not found."
    fi
fi

echo
echo "✓ Dotfiles installation complete!"
echo "Note: Some changes may require a new shell session or a full logout/login to take effect."
