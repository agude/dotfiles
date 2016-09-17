# Set editor, but only if we find neovim, fall back to vim if not
hash vim &>/dev/null && export EDITOR=vim && export VISUAL=vim
hash nvim &>/dev/null && export EDITOR=nvim && export VISUAL=nvim

# Alias vi and vim to nvim if it exists
hash nvim &>/dev/null && alias vi="nvim" && alias vim="nvim"
