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
# Set the format and add a space at the beginning for padding
zstyle ':vcs_info:git:*' formats       ' %F{red}(%b%u%c)%f'
zstyle ':vcs_info:git:*' actionformats ' %F{red}(%b|%a%u%c)%f'

# --- Pyenv Prompt Setup ---
export PYENV_VIRTUALENV_DISABLE_PROMPT=1
prompt_pyenv_segment() {
  # This function populates the global $pyenv_prompt_segment variable
  if [[ -n "$PYENV_VERSION" ]]; then
    pyenv_prompt_segment="($PYENV_VERSION) "
  else
    pyenv_prompt_segment=""
  fi
}

# --- precmd: Runs before each prompt is displayed ---
precmd() {
  # Update git status. The result is stored in $vcs_info_msg_0_.
  vcs_info

  # Update pyenv status.
  prompt_pyenv_segment

  # --- Build the PROMPT variable ---

  # 1. Exit Code (only shown on error)
  PROMPT='%(?..%F{red}exit: %?%f )'

  # 2. Pyenv Segment
  PROMPT+="${pyenv_prompt_segment}"

  # 3. Username (green for normal, yellow for sudo, red for root)
  PROMPT+='%F{%(?.green.%(?.yellow.red))}%n%f'

  # 4. Directory
  PROMPT+=':%F{blue}%~%f'

  # 5. Git Segment
  PROMPT+="${vcs_info_msg_0_}"

  # 6. Final prompt symbol
  PROMPT+=' ' # Use a space instead of '$ ' to avoid a double space if there's no git info
  PROMPT+='%(!.#.$) ' # Show '#' for root, '$' for normal users
}
