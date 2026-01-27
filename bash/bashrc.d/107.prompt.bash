# shellcheck shell=bash
# ------------------------------------------------------------------------------
# Bash Prompt Configuration
# ------------------------------------------------------------------------------

# --- Color Definitions ---
# Use tput for terminal-independent color codes.
if command -v tput >/dev/null && [[ $(tput colors) -ge 8 ]]; then
    RESET=$(tput sgr0)
    # BOLD=$(tput bold)
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    # BLACK=$(tput setaf 0)
    # CYAN=$(tput setaf 6)
    # WHITE=$(tput setaf 7)
else
    # Fallback to static codes if tput is not available or doesn't support colors.
    RESET='\e[0m'
    # BOLD='\e[1m'
    RED='\e[0;31m'
    GREEN='\e[0;32m'
    YELLOW='\e[0;33m'
    BLUE='\e[0;34m'
    MAGENTA='\e[0;35m'
    # BLACK='\e[0;30m'
    # CYAN='\e[0;36m'
    # WHITE='\e[0;37m'
fi

# --- Prompt Building ---

# Set user color based on shared prompt state
case "$PROMPT_USER_STATE" in
  root)   _user_color="$RED" ;;
  sudo)   _user_color="$YELLOW" ;;
  remote) _user_color="$MAGENTA" ;;
  *)      _user_color="$GREEN" ;;
esac

# Set hostname segment only if remote
if [[ "$PROMPT_USER_STATE" == "remote" ]]; then
  _hostname_segment="@\h"
else
  _hostname_segment=""
fi

# Set the prompt symbol based on user privilege
_prompt_symbol='$'
[[ $EUID -eq 0 ]] && _prompt_symbol='#'

# --- PROMPT_COMMAND: Runs before each prompt is displayed ---
# This function builds the PS1 variable dynamically.
build_prompt() {
    local exit_code=$?

    # 1. Exit Code (only if non-zero)
    if [[ $exit_code -ne 0 ]]; then
        PS1="\[$RED\]exit: ${exit_code}\n\[$RESET\]"
    else
        PS1=""
    fi

    # 2. User and Host
    PS1+="\[$_user_color\]\u${_hostname_segment}\[$RESET\]"

    # 3. Directory
    PS1+="\[$BLUE\]:\w\[$RESET\]"

    # 4. Git Branch (if in a git repo)
    # The __git_ps1 function is provided by git's bash-completion script.
    if command -v __git_ps1 >/dev/null; then
        PS1+="\$(__git_ps1 ' \[$RED\](%s)\[$RESET\]')"
    fi

    # 5. Final prompt symbol
    PS1+=" ${_prompt_symbol} "
}

# Register the function to be run before each prompt.
# Preserve any existing PROMPT_COMMAND (e.g., history -a from 002.history.bash)
PROMPT_COMMAND="build_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
