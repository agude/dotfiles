# ------------------------------------------------------------------------------
# Custom Zsh Keybindings
# ------------------------------------------------------------------------------

# Explicitly load the terminfo module to ensure the $key array is populated.
# The '-i' flag makes this a no-op if the module is already loaded.
zmodload -i zsh/terminfo

# Define the custom history search widgets.
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

# Bind the widgets to the arrow keys using the terminal-independent $key array.
# This is more robust than hardcoding escape sequences.
bindkey "$key[Up]" up-line-or-beginning-search
bindkey "$key[Down]" down-line-or-beginning-search
