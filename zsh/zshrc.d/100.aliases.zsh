# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

# Creates an alias, but only if the target command actually exists.
# This prevents broken aliases for uninstalled software.
#
# Usage: set_alias_if_program_exists 'target_command' 'alias_name'
set_alias_if_program_exists() {
    local target_cmd="$1"
    local alias_name="$2"

    # Check if the target command is executable and in the PATH.
    if command -v "${target_cmd}" >/dev/null 2>&1; then
        alias "${alias_name}"="${target_cmd}"
    fi
}

# ------------------------------------------------------------------------------
# General Command Aliases
# ------------------------------------------------------------------------------

# Use 'git diff' for a powerful two-file diff, if git is available.
# Usage: gdiff <file1> <file2>
set_alias_if_program_exists 'git' 'gdiff=git diff --no-index --'

# Use modern, improved replacements for standard commands if they are installed.
# 'bat' is a 'cat' clone with syntax highlighting and Git integration.
set_alias_if_program_exists 'bat' 'cat'

# ------------------------------------------------------------------------------
# Platform-Specific Aliases (Linux, macOS, WSL)
# ------------------------------------------------------------------------------

# This section requires the PLATFORM variable to be set by the OS detection script.

# For Linux and WSL, use GNU coreutils flags for color.
if [[ "$PLATFORM" == "linux" || "$PLATFORM" == "wsl" ]]; then
    alias ls='ls --color=auto'
    alias lt='ls --color=auto -ltrh'

# For macOS, handle differences between built-in BSD tools and optional GNU tools.
elif [[ "$PLATFORM" == "mac" ]]; then
    # Prefer GNU coreutils (gfind, gsed, etc.) if installed via Homebrew.
    # This shadows the less-featured, built-in BSD versions.
    set_alias_if_program_exists 'gfind' 'find'
    set_alias_if_program_exists 'gsed' 'sed'
    set_alias_if_program_exists 'ggrep' 'grep'

    # Use 'gls' from GNU coreutils for color, as macOS 'ls' uses a different flag.
    if command -v gls >/dev/null 2>&1; then
        alias ls='gls --color=auto'
        alias lt='gls --color=auto -ltrh'
    # If 'gls' is not installed, fall back to the built-in 'ls' with the BSD color flag.
    else
        alias ls='ls -G'
        alias lt='ls -Gltrh'
    fi
fi

# ------------------------------------------------------------------------------
# Application Aliases
# ------------------------------------------------------------------------------

# Alias MATE desktop applications to their more common GNOME equivalent names.
# This provides compatibility if you are used to the GNOME commands.
set_alias_if_program_exists 'atril' 'evince'   # Document viewer
set_alias_if_program_exists 'caja' 'nautilus'  # File manager
set_alias_if_program_exists 'eom' 'eog'        # Image viewer
set_alias_if_program_exists 'pluma' 'gedit'    # Text editor
