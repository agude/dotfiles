# shellcheck shell=zsh
# ------------------------------------------------------------------------------
# Zsh Completion System Configuration
# ------------------------------------------------------------------------------

# Add Homebrew's completion directory to fpath if it exists.
# This should be done before adding our custom directory to ensure
# official completions are preferred.
if command -v brew &>/dev/null; then
  fpath=("$(brew --prefix)/share/zsh/site-functions" $fpath)
fi

# Create a directory for custom completions and add it to the function path.
# This MUST be done BEFORE compinit is called.
mkdir -p ~/.zfunc
fpath=(~/.zfunc $fpath)

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
