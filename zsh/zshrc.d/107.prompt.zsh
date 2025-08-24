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

# --- Virtual Env Prompt Segment ---
# This function checks for the standard VIRTUAL_ENV variable.
prompt_venv_segment() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    # Use basename to get just the directory name (e.g., ".venv")
    venv_prompt_segment="%F{cyan}($(basename "$VIRTUAL_ENV"))%f "
  else
    venv_prompt_segment=""
  fi
}

# --- precmd: Runs before each prompt is displayed ---
precmd() {
  local exit_code=$?

  # Set user color based on privilege
  if [[ $EUID -eq 0 ]]; then
    _prompt_user_color='red'
  elif [[ -n "$SUDO_USER" ]]; then
    _prompt_user_color='yellow'
  else
    _prompt_user_color='green'
  fi

  # Update all dynamic prompt segments
  vcs_info
  prompt_venv_segment # <-- ADD THIS LINE

  # Print the exit code on a separate line, ONLY if it's an error
  if [[ $exit_code -ne 0 ]]; then
    print -P "%F{red}exit: ${exit_code}%f"
  fi
}

# --- Build the Main PROMPT variable ---

# 1. Virtual Env Segment (updated by precmd)
PROMPT='${venv_prompt_segment}' # <-- ADD THIS LINE

# 2. Username
PROMPT+='%F{${_prompt_user_color}}%n%f'

# 3. Directory
PROMPT+=':%F{blue}%~%f'

# 4. Git Segment
PROMPT+='${vcs_info_msg_0_}'

# 5. Final prompt symbol
PROMPT+=' %(!.#.$) '
