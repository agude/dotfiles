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

# For Linux and WSL, use the GNU --color flag
if [[ "$PLATFORM" == "linux" || "$PLATFORM" == "wsl" ]]; then
    alias ls='ls --color=auto'
    alias lt='ls --color=auto -ltrh'
    alias grep='grep --color=auto'

# For macOS, check for GNU 'gls' and fall back to BSD 'ls'
elif [[ "$PLATFORM" == "mac" ]]; then
    # If GNU 'gls' is installed (via Homebrew), prefer it
    if command_exists gls; then
        alias ls='gls --color=auto'
        alias lt='gls --color=auto -ltrh'
    else
        # Use the built-in BSD 'ls' with its color flag
        alias ls='ls -G'
        alias lt='ls -Gltrh'
    fi
    
    # Use GNU versions if available, otherwise fall back to BSD versions
    if command_exists ggrep; then
        alias grep='ggrep --color=auto'
    fi
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

# LS variations
alias la="ls -A"
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
