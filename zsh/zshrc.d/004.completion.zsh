# ------------------------------------------------------------------------------
# Zsh Completion System Configuration
# ------------------------------------------------------------------------------

# Load the completion system
autoload -Uz compinit

# --- Caching ---
# Check for a cache file (.zcompdump). If it's not there or older than 1 day,
# regenerate it. Otherwise, load from the cache. This speeds up shell startup.
_zcomp_dump_file="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ ! -f "$_zcomp_dump_file" || -z "$(find "$_zcomp_dump_file" -mtime -1)" ]]; then
  compinit -i
else
  compinit -i -C
fi

# --- Configuration via zstyle ---

# Group completions by category
zstyle ':completion:*' group-name ''

# Use a menu to select completions
# You can navigate this with arrow keys
zstyle ':completion:*' menu select

# Add colors to the completion menu (uses LS_COLORS)
# This should be defined in your aliases/colors file
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Format for descriptions in the completion menu
# Example: 'Commands' or 'Git Branches'
zstyle ':completion:*:descriptions' format '%F{yellow}--- %d ---%f'

# --- Enhanced Matching ---
# This is the magic that enables flexible matching (e.g., typos, partial matches)
# - 'm:{a-z}={A-Z}' -> Case-insensitive matching
# - 'r:|[._-]=* r:|=*' -> Match on either side of a separator (., _, -)
# - 'l:|=* r:|=*'   -> Match from the beginning and end of a word
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
