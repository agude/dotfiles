# Set neovim as editor, but only if it exists, fall back to vim if not
if [[ -x $(command -v nvim) ]]; then
    export EDITOR=nvim
    export VISUAL=nvim
    alias vi="nvim"
    alias vim="nvim"
elif [[ -x $(command -v vim) ]]; then
    export EDITOR=vim
    export VISUAL=vim
fi
