# shellcheck shell=zsh
# ~/.zshrc.d/060.keybindings.zsh
# ------------------------------------------------------------------------------
# Custom Zsh Keybindings
# ------------------------------------------------------------------------------

# Only set up keybindings for interactive shells, as they are meaningless otherwise.
if [[ -o interactive ]]; then
    # Explicitly load the terminfo module to ensure the $key array is populated.
    zmodload -i zsh/terminfo

    # Define the custom history search widgets.
    autoload -U up-line-or-beginning-search
    autoload -U down-line-or-beginning-search
    zle -N up-line-or-beginning-search
    zle -N down-line-or-beginning-search

    # --- Arrow Key History Search ---

    # Bind both standard and application mode key sequences for maximum compatibility.
    # This ensures the bindings work regardless of the terminal emulator or its mode.

    # Up Arrow
    # Only bind the terminfo key if it's actually defined.
    if [[ -n "${key[Up]-}" ]]; then
        bindkey "${key[Up]}" up-line-or-beginning-search
    fi
    bindkey "^[[A" up-line-or-beginning-search

    # Down Arrow
    if [[ -n "${key[Down]-}" ]]; then
        bindkey "${key[Down]}" down-line-or-beginning-search
    fi
    bindkey "^[[B" down-line-or-beginning-search
fi
