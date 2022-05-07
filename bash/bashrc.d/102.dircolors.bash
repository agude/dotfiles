# Set directory and file colors in bash
if [[ -x $(command -v dircolors) ]]; then
    eval "$(dircolors -b)"
fi
