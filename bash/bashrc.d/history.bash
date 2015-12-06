# ignore duplicate entires, and ignore commands that start with space
HISTCONTROL=ignoredups:ignorespace

# append to the history file, don't overwrite it
shopt -s histappend &>/dev/null

# put multi-line commands onto one line of history.
shopt -s cmdhist &>/dev/null

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
unset -v HISTFILESIZE
HISTSIZE=1000000

# keep the times of the commands in history
HISTTIMEFORMAT='%F %T  '

# add history entries immediately, not on exit
PROMPT_COMMAND='history -a'
