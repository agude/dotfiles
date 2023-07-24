# Functions to generate prompt segments

# username
prompt_username() {
  if [[ $EUID -eq 0 ]]; then
    color='red'
  elif [[ -n $SUDO_USER ]]; then
    color='yellow'
  elif [[ -n $SSH_CLIENT ]]; then
    color='magenta'
  else
    color='green'
  fi

  echo -n "%F{$color}%n%f"
}

# directory
prompt_dir() {
  echo -n '%F{blue}%~%f'
}

# pyenv
export PYENV_VIRTUALENV_DISABLE_PROMPT=1
prompt_pyenv() {
  if [[ -n "$PYENV_VERSION" ]]; then
    echo -n "($PYENV_VERSION) "
  fi
}

# git

# From: https://salferrarello.com/zsh-git-status-prompt/
autoload -Uz vcs_info
setopt prompt_subst

# Enable checking for (un)staged changes, enabling use of %u and %c
zstyle ':vcs_info:*' check-for-changes true
# Set custom strings for an unstaged vcs repo changes (*) and staged changes (+)
zstyle ':vcs_info:*' unstagedstr ' *'
zstyle ':vcs_info:*' stagedstr ' +'
# Set the format of the Git information for vcs_info
zstyle ':vcs_info:git:*' formats       '(%b%u%c)'
zstyle ':vcs_info:git:*' actionformats '(%b|%a%u%c)'

prompt_git() {
  vcs_info
  echo -n "%F{red}${vcs_info_msg_0_}%f"
}

# Build prompt
build_prompt() {
    local prompt
    prompt+="$(prompt_pyenv)"
    prompt+=$(prompt_username)
    prompt+=':'
    prompt+=$(prompt_dir)
    prompt+=" "$(prompt_git)
    prompt+='$ '

    echo -n $prompt
}
# Set prompt
PROMPT="$(build_prompt)"
