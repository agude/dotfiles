# shellcheck shell=zsh
# ~/.zshrc.d/060.keybindings.zsh
# ------------------------------------------------------------------------------
# Custom Zsh Keybindings
# ------------------------------------------------------------------------------

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
bindkey "$key[Up]" up-line-or-beginning-search      # Use terminfo for the primary binding.
bindkey "^[[A" up-line-or-beginning-search         # Manually bind the "normal mode" sequence.

# Down Arrow
bindkey "$key[Down]" down-line-or-beginning-search  # Use terminfo for the primary binding.
bindkey "^[[B" down-line-or-beginning-search       # Manually bind the "normal mode" sequence.
