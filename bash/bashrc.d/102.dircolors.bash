# Set directory and file colors in bash
if [[ -x $(command -v dircolors) ]]; then
    eval "$(dircolors -b)"
# gdircolors is the version installed by homebrew on MacOS
elif [[ -x $(command -v gdircolors) ]]; then
    eval "$(gdircolors -b)"
fi
