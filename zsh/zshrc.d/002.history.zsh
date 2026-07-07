# shellcheck shell=zsh
# ------------------------------------------------------------------------------
# Zsh History Configuration
# ------------------------------------------------------------------------------

# --- Location and Safety ---

# Set the path to the history file.
HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history

# Ensure the history directory exists before proceeding.
# The '-p' flag creates parent directories as needed and doesn't error if it already exists.
if [[ ! -d "${HISTFILE:h}" ]]; then
  mkdir -p "${HISTFILE:h}"
fi

# NOTE: For security, ensure your history file is not world-readable.
# The best way to do this is to set a secure umask at the top of your .zshrc
# umask 077

# --- Size ---

HISTSIZE=100000
SAVEHIST=100000

# --- Behavior and Formatting ---

setopt INC_APPEND_HISTORY
# setopt SHARE_HISTORY
# Add timestamps to history entries.
setopt EXTENDED_HISTORY
# Remove leading and trailing whitespace from commands.
setopt HIST_REDUCE_BLANKS

# --- Duplicate Handling ---

# If a new command is a duplicate, remove the older entry from the history.
setopt HIST_IGNORE_ALL_DUPS
# When searching, don't display adjacent duplicates.
setopt HIST_FIND_NO_DUPS

# --- Control ---

# If a command starts with a space, don't save it to history.
setopt HIST_IGNORE_SPACE
