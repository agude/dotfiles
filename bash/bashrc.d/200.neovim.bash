# Set neovim as editor, but only if it exists, fall back to vim if not
hash vim &>/dev/null &&\
    export EDITOR=vim &&\
    export VISUAL=vim

hash nvim &>/dev/null &&\
    export EDITOR=nvim &&\
    export VISUAL=nvim &&\
    alias vi="nvim" &&\
    alias vim="nvim"
