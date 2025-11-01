# shellcheck shell=bash
# ------------------------------------------------------------------------------
# Unified Tool and Color Configuration
#
# This file configures 'ls' and 'grep' with sane, colorful defaults.
# It is self-contained and works for both bash and zsh.
# ------------------------------------------------------------------------------

# Do nothing if not running interactively.
[[ $- != *i* ]] && return

# --- Phase 1: Tool Detection and Color Setup ---

# Use temporary variables for configuration (will be unset at the end).
_ls_cmd="ls"
_grep_cmd="grep"
_dircolors_cmd=""
_ls_has_color_flag=false

# Check for GNU coreutils on macOS (g-prefixed commands).
if [[ "$PLATFORM" == "mac" ]]; then
    command -v gls >/dev/null && _ls_cmd="gls"
    command -v ggrep >/dev/null && _grep_cmd="ggrep"
    command -v gdircolors >/dev/null && _dircolors_cmd="gdircolors"
else
    # On Linux, check for the standard commands.
    command -v dircolors >/dev/null && _dircolors_cmd="dircolors"
fi

# Set up LS_COLORS (for GNU ls) or LSCOLORS (for BSD ls).
if [[ -n "$_dircolors_cmd" ]]; then
    # GNU ls: prefer user's custom file, otherwise use defaults.
    if [[ -f "$HOME/.dircolors" ]]; then
        eval "$($_dircolors_cmd -b "$HOME/.dircolors")"
    else
        eval "$($_dircolors_cmd -b)"
    fi
    _ls_has_color_flag=true
elif [[ "$PLATFORM" == "mac" ]]; then
    # BSD ls on macOS: set a default color scheme.
    export LSCOLORS="exfxcxdxbxegedabagacad"
    _ls_has_color_flag=true
fi

# --- Phase 2: Alias Definition ---

# For `ls`, define options within a function for clarity.
_configure_ls_alias() {
    local opts=""
    if [[ "$_ls_has_color_flag" == true ]]; then
        # Use --color for GNU ls, -G for BSD ls.
        [[ "$_ls_cmd" == "gls" || "$PLATFORM" != "mac" ]] && opts="--color=auto" || opts="-G"
    fi
    # Set the alias with the detected command and options.
    alias ls="$_ls_cmd $opts"
    alias lt="$_ls_cmd $opts -ltrh"
    alias la="$_ls_cmd $opts -A"
}
_configure_ls_alias
unset -f _configure_ls_alias # Clean up the helper function.

# For `grep`, build a robust set of options, avoiding deprecated ENV vars.
_configure_grep_alias() {
    local opts="-I" # Always ignore binary files.

    # Check for GNU grep's advanced features.
    if "$_grep_cmd" --version 2>/dev/null | grep -q "GNU"; then
        opts="$opts --exclude=.gitignore --exclude-dir=.git"
        if command -v tput >/dev/null 2>&1 && [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
            opts="$opts --color=auto"
        fi
    fi
    # Set the aliases.
    alias grep="$_grep_cmd $opts"
    alias fgrep="$_grep_cmd -F $opts"
    alias egrep="$_grep_cmd -E $opts"
}
_configure_grep_alias
unset -f _configure_grep_alias # Clean up the helper function.

# For coreutils 8.25+ - revert new quoting behavior
export QUOTING_STYLE=literal

# --- Phase 3: Cleanup ---

unset _ls_cmd _grep_cmd _dircolors_cmd _ls_has_color_flag
