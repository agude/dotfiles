# shellcheck shell=bash
# ------------------------------------------------------------------------------
# Shared Aliases - Common aliases for both bash and zsh
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# General Command Aliases
# ------------------------------------------------------------------------------

# Use 'git diff' for a powerful two-file diff, if git is available.
if command -v git >/dev/null 2>&1; then
    alias gdiff='git diff --no-index --'
fi

# ------------------------------------------------------------------------------
# Shadowing & Replacement Aliases
# ------------------------------------------------------------------------------

# Use modern, improved replacements for standard commands if they exist.
if command -v bat >/dev/null 2>&1; then
    alias cat='bat'
fi

# ------------------------------------------------------------------------------
# Platform-Specific Aliases (macOS)
# ------------------------------------------------------------------------------

# On macOS, prefer GNU coreutils if they are installed with a 'g' prefix.
if [[ "$PLATFORM" == "mac" ]]; then
    if command -v gfind >/dev/null 2>&1; then
        alias find='gfind'
    fi
    if command -v gsed >/dev/null 2>&1; then
        alias sed='gsed'
    fi
fi

# ------------------------------------------------------------------------------
# Common Aliases
# ------------------------------------------------------------------------------

# Additional LS variation (la and lt are handled by 010.tools_and_colors.sh)
alias ld='ls -dltrh ./*/ 2>/dev/null'

# History search
alias hs='history | grep'

# Reload shell configuration
alias reload='source "${HOME}/.${SHELL##*/}rc"'

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

# Report fingerprints for all local SSH keys
ssh-keyreport() {
    echo "--- Public Keys ---"
    for keyfile in "${HOME}"/.ssh/*.pub; do
        if [[ -f "$keyfile" ]]; then
            ssh-keygen -l -f "$keyfile"
        fi
    done
    echo "--- Private Keys ---"
    for keyfile in "${HOME}"/.ssh/id_*; do
        # Ignore .pub files that the glob might catch
        [[ "$keyfile" == *.pub ]] && continue
        if [[ -f "$keyfile" ]]; then
            ssh-keygen -l -f "$keyfile"
        fi
    done
}

# ------------------------------------------------------------------------------
# Application Aliases
# ------------------------------------------------------------------------------

# Alias MATE desktop applications to their more common GNOME equivalent names.
if command -v atril >/dev/null 2>&1; then
    alias evince='atril'
fi
if command -v caja >/dev/null 2>&1; then
    alias nautilus='caja'
fi
if command -v eom >/dev/null 2>&1; then
    alias eog='eom'
fi
if command -v pluma >/dev/null 2>&1; then
    alias gedit='pluma'
fi
