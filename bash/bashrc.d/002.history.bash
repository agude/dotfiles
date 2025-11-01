# shellcheck shell=bash
# Ignore commands that start with space
HISTCONTROL=ignorespace

# Append to the history file, don't overwrite it
shopt -s histappend &>/dev/null

# Put multi-line commands onto one line of history.
shopt -s cmdhist &>/dev/null

# Undocumented feature which sets the size to "unlimited".
# http://stackoverflow.com/questions/9457233/unlimited-bash-history
unset -v HISTFILESIZE
unset -v HISTSIZE
export HISTFILESIZE=
export HISTSIZE=

# Move the default location because some processes truncate ~/.bash_history
# http://superuser.com/questions/575479/bash-history-truncated-to-500-lines-on-each-login
export HISTFILE=~/.bash_eternal_history

# Keep the times of the commands in history
export HISTTIMEFORMAT="[%F %T] "

# Add history entries immediately, not on exit
# http://superuser.com/questions/20900/bash-history-loss
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
