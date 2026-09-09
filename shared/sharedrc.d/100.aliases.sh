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
# $SHELL is the login shell, not necessarily the running shell.
if [[ -n "$ZSH_VERSION" ]]; then
    alias reload='source "${HOME}/.zshrc"'
elif [[ -n "$BASH_VERSION" ]]; then
    alias reload='source "${HOME}/.bashrc"'
fi

# Claude Code aliases
if command -v claude >/dev/null 2>&1; then
    # Claude Code pinned to Opus 4.6
    alias opus='claude --model claude-opus-4-6'
    # Claude Code pinned to Sonnet 5
    alias sonnet='claude --model claude-sonnet-4-6'
    # Claude Code pinned to Fable 5
    alias fable='claude --model claude-fable-5'
fi

# Codex CLI aliases
if command -v codex >/dev/null 2>&1; then
    # Synced profile and session capture enabled
    codex() { KNOWLEDGE_OBSERVE=1 command codex --profile agude "$@"; }
    alias luna='codex --model gpt-5.6-luna -c model_reasoning_effort=xhigh'
    alias terra='codex --model gpt-5.6-terra -c model_reasoning_effort=medium'
    alias sol='codex --model gpt-5.6-sol -c model_reasoning_effort=medium'
    alias astra='codex --model gpt-6-astra -c model_reasoning_effort=low'
fi

# Pi coding agent aliases using the OpenAI Codex provider
if command -v pi >/dev/null 2>&1; then
    alias luna-pi='pi --provider openai-codex --model gpt-5.6-luna --thinking xhigh'
    alias terra-pi='pi --provider openai-codex --model gpt-5.6-terra --thinking medium'
    alias sol-pi='pi --provider openai-codex --model gpt-5.6-sol --thinking medium'
    alias astra-pi='pi --provider openai-codex --model gpt-6-astra --thinking low'
fi

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

# Johnny.Decimal navigation function.
# Calls the `jd` script and cds to the directory it returns.
jd() {
    local target_dir
    # Call the script, capturing its output. The `|| true` prevents the shell
    # from exiting if the script returns a non-zero exit code (e.g., user hits Esc in fzf).
    target_dir=$(command jd "$@" || true)

    # If the script returned a path, change to it.
    if [[ -n "$target_dir" && -d "$target_dir" ]]; then
        cd "$target_dir" || return 1
    fi
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
