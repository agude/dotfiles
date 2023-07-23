# Set location to save history to ~/.zsh_history file
HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history

# Append new history to end of ~/.zsh_history file instead of overwriting
setopt APPEND_HISTORY

# Record start and end times of commands in history file
setopt EXTENDED_HISTORY

# Append history from this session to history from previous sessions
setopt INC_APPEND_HISTORY

# Do not record duplicate entries in history
setopt HIST_IGNORE_DUPS

# Do not display duplicate entries when searching history
setopt HIST_FIND_NO_DUPS

# Remove extra blanks from each command line being added to history
setopt HIST_REDUCE_BLANKS
