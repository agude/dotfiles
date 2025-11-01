# shellcheck shell=bash
# ------------------------------------------------------------------------------
# Shared Aliases - Common aliases for both bash and zsh
# ------------------------------------------------------------------------------

# Helper function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# General Command Aliases
# ------------------------------------------------------------------------------

# Use 'git diff' for a powerful two-file diff, if git is available
if command_exists git; then
    alias gdiff="git diff --no-index --"
fi

# Use modern, improved replacements for standard commands if they are installed
if command_exists bat; then
    alias cat="bat"
fi

# ------------------------------------------------------------------------------
# Platform-Specific Aliases (Linux, macOS, WSL)
# ------------------------------------------------------------------------------
# Note: ls, lt, la, grep aliases are now handled by shared/sharedrc.d/010.tools_and_colors.sh

# For macOS, use GNU versions if available
if [[ "$PLATFORM" == "mac" ]]; then
    if command_exists gfind; then
        alias find='gfind'
    fi
    if command_exists gsed; then
        alias sed='gsed'
    fi
fi

# ------------------------------------------------------------------------------
# Common Aliases
# ------------------------------------------------------------------------------

# Additional LS variation (la and lt are handled by 010.tools_and_colors.sh)
alias ld="ls -dltrh ./*/ 2>/dev/null"

# History search
alias hs="history | grep"

# Reload shell configuration
alias reload='source ${HOME}/.${SHELL##*/}rc'

# ------------------------------------------------------------------------------
# Application Aliases
# ------------------------------------------------------------------------------

# Alias MATE desktop applications to their more common GNOME equivalent names
if command_exists atril; then
    alias evince='atril'
fi
if command_exists caja; then
    alias nautilus='caja'
fi
if command_exists eom; then
    alias eog='eom'
fi
if command_exists pluma; then
    alias gedit='pluma'
fi
