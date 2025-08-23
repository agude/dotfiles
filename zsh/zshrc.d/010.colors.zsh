# ------------------------------------------------------------------------------
# Color Environment Variables
#
# Sets LS_COLORS (GNU) or LSCOLORS (BSD) for colored output.
# ------------------------------------------------------------------------------

# This script requires the PLATFORM variable to be set by the OS detection script.

# For Linux/WSL, or macOS with GNU coreutils installed.
if [[ "$PLATFORM" == "linux" || "$PLATFORM" == "wsl" ]] || command -v gdircolors >/dev/null 2>&1; then
    # Use 'gdircolors' on macOS, 'dircolors' on Linux.
    local dircolors_cmd="dircolors"
    [[ "$PLATFORM" == "mac" ]] && dircolors_cmd="gdircolors"

    # Use a custom ~/.dircolors file if it exists, otherwise use the default.
    if [[ -f "$HOME/.dircolors" ]]; then
        eval "$($dircolors_cmd -b "$HOME/.dircolors")"
    else
        eval "$($dircolors_cmd -b)"
    fi

# For a default macOS environment (without GNU coreutils).
elif [[ "$PLATFORM" == "mac" ]]; then
    # macOS/BSD 'ls' uses the LSCOLORS variable (no underscore).
    # This sets a readable default color scheme.
    export LSCOLORS="exfxcxdxbxegedabagacad"
fi

unset dircolors_cmd
