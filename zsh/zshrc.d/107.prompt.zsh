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

# --- Pyenv/Rye Prompt Segment ---
export PYENV_VIRTUALENV_DISABLE_PROMPT=1
prompt_pyenv_segment() {
  if [[ -n "$PYENV_VERSION" ]]; then
    pyenv_prompt_segment="($PYENV_VERSION) "
  else
    pyenv_prompt_segment=""
  fi
}

# --- precmd: Runs before each prompt is displayed ---
precmd() {
  # Store the exit code of the last command first.
  local exit_code=$?

  # --- Set user color based on privilege ---
  # This logic now lives here, independent of the exit code.
  if [[ $EUID -eq 0 ]]; then
    _prompt_user_color='red'
  elif [[ -n "$SUDO_USER" ]]; then
    _prompt_user_color='yellow'
  else
    _prompt_user_color='green'
  fi

  # Update other dynamic prompt segments
  vcs_info
  prompt_pyenv_segment

  # --- Print the exit code on a separate line, ONLY if it's an error ---
  if [[ $exit_code -ne 0 ]]; then
    print -P "%F{red}exit: ${exit_code}%f"
  fi
}

# --- Build the Main PROMPT variable ---
# This is now set once and uses variables that precmd updates.

# 1. Pyenv Segment
PROMPT='${pyenv_prompt_segment}'

# 2. Username (using the color calculated in precmd)
PROMPT+='%F{${_prompt_user_color}}%n%f'

# 3. Directory
PROMPT+=':%F{blue}%~%f'

# 4. Git Segment
PROMPT+='${vcs_info_msg_0_}'

# 5. Final prompt symbol
PROMPT+=' %(!.#.$) ' # Show '#' for root, '$' for normal users
