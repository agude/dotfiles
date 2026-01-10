#!/usr/bin/env bash
# shellcheck shell=bash
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
    # shellcheck disable=SC1090
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

# Create a real directory, removing any existing symlink first.
# This is important when transitioning from "symlink the whole directory"
# to "symlink individual files inside a real directory". Without this guard,
# mkdir -p silently succeeds on symlinks, and subsequent file creation
# ends up in the symlink target (often back in this repo).
ensure_real_dir() {
    local dir="$1"
    if [[ -L "$dir" ]]; then
        echo "  -> Removing symlink to create real directory: $dir"
        rm "$dir"
    fi
    mkdir -p "$dir"
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
ensure_real_dir "${HOME}/bin"
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
    # shellcheck disable=SC1090
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

echo "› Setting up LLM tool configurations..."
# Claude Code uses ~/.claude and stores runtime files there.
# We create a real directory and symlink only the files we manage.
CLAUDE_DIR="${HOME}/.claude"
ensure_real_dir "${CLAUDE_DIR}"

# Symlink only the configuration files we control
link "${CLAUDE_DIR}/settings.json" "llm/claude/settings.json"
# Symlink custom commands individually (excludes README.md)
# Using individual symlinks allows external commands to coexist.
COMMANDS_DIR="${CLAUDE_DIR}/commands"
ensure_real_dir "$COMMANDS_DIR"
for cmd_file in "$DOTFILES_DIR/llm/claude/commands/"*.md; do
    [ -f "$cmd_file" ] || continue
    cmd_name=$(basename "$cmd_file")
    # Skip README files
    [[ "$cmd_name" == "README.md" ]] && continue
    link "${COMMANDS_DIR}/${cmd_name}" "llm/claude/commands/${cmd_name}"
done

link "${CLAUDE_DIR}/CLAUDE.md" "llm/claude/CLAUDE.md"

# Symlink shared Agent Skills individually (allows external skills to coexist)
# Using individual symlinks instead of a directory symlink lets you add
# work-specific or machine-local skills alongside the dotfiles-managed ones.
SKILLS_DIR="${CLAUDE_DIR}/skills"
ensure_real_dir "$SKILLS_DIR"
for skill_dir in "$DOTFILES_DIR/llm/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    link "${SKILLS_DIR}/${skill_name}" "llm/skills/${skill_name}"
done

# Expose Johnny Decimal scripts without .sh extension
# (subdirs are added to PATH by shared/sharedrc.d/002.bin_subdirs.sh)
ensure_real_dir "${HOME}/bin/johnny-decimal"
for script in "$DOTFILES_DIR/llm/skills/johnny-decimal/scripts/"*.sh; do
    script_basename=$(basename "$script")
    # Skip the library file - it's not meant to be run directly
    [[ "$script_basename" == "jd-lib.sh" ]] && continue
    script_name="${script_basename%.sh}"
    link "${HOME}/bin/johnny-decimal/${script_name}" "llm/skills/johnny-decimal/scripts/${script_basename}"
done

# Gemini CLI uses ~/.gemini and stores runtime files there.
# We create a real directory and symlink only the files we manage.
GEMINI_DIR="${HOME}/.gemini"
ensure_real_dir "${GEMINI_DIR}"

# Symlink only the configuration files we control
link "${GEMINI_DIR}/settings.json" "llm/gemini/settings.json"

echo "› Setting up automated cleanup tasks..."
if [[ "${PLATFORM}" == "linux" ]]; then
    if command -v systemctl &> /dev/null; then
        echo "  -> Setting up systemd user service for emptying Downloads..."
        SYSTEMD_USER_DIR="${XDG_CONFIG_HOME}/systemd/user"
        SERVICE_FILE="${SYSTEMD_USER_DIR}/empty-downloads.service"
        SOURCE_SERVICE_FILE="${DOTFILES_DIR}/config/systemd/user/empty-downloads.service"

        ensure_real_dir "${SYSTEMD_USER_DIR}"

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

        ensure_real_dir "${LAUNCHD_DIR}"

        # Link the plist file into the real directory.
        link "${PLIST_FILE}" "config/launchd/com.user.empty-downloads.plist"

        # Unload the service first in case it's already running, then load it.
        launchctl unload "${PLIST_FILE}" 2>/dev/null || true
        launchctl load "${PLIST_FILE}" >/dev/null 2>&1 || echo "  -> Warning: Failed to load launchd agent. This may be expected in a non-interactive session."
    fi
fi

echo
echo "✓ Dotfiles installation complete!"
echo "Note: Some changes may require a new shell session or a full logout/login to take effect."
