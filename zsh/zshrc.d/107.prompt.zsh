# ------------------------------------------------------------------------------
# Zsh Prompt Configuration
# ------------------------------------------------------------------------------

# Allow for prompt expansion and substitution.
setopt prompt_subst

# --- VCS (Git) Prompt Setup ---
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' unstagedstr ' *'
zstyle ':vcs_info:*' stagedstr ' +'
zstyle ':vcs_info:git:*' formats       ' %F{red}(%b%u%c)%f'
zstyle ':vcs_info:git:*' actionformats ' %F{red}(%b|%a%u%c)%f'

# --- precmd: Runs before each prompt is displayed ---
precmd() {
  local exit_code=$?

  # Set user color based on shared prompt state
  case "$PROMPT_USER_STATE" in
    root)   _prompt_user_color='red' ;;
    sudo)   _prompt_user_color='yellow' ;;
    remote) _prompt_user_color='magenta' ;;
    *)      _prompt_user_color='green' ;;
  esac

  # Set hostname segment only if remote
  if [[ "$PROMPT_USER_STATE" == "remote" ]]; then
    _prompt_hostname_segment="%F{magenta}@%m%f"
  else
    _prompt_hostname_segment=""
  fi

  # Update VCS status
  vcs_info

  # Print the exit code on a separate line, ONLY if it's an error
  if [[ $exit_code -ne 0 ]]; then
    print -P "%F{red}exit: ${exit_code}%f"
  fi
}

# --- Build the Main PROMPT variable ---

# 1. Username and Hostname
PROMPT='%F{${_prompt_user_color}}%n%f' # Username
PROMPT+='${_prompt_hostname_segment}'   # @hostname (only when remote)

# 2. Directory
PROMPT+=':%F{blue}%~%f'

# 3. Git Segment
PROMPT+='${vcs_info_msg_0_}'

# 4. Final prompt symbol
PROMPT+=' %(!.#.$) '
