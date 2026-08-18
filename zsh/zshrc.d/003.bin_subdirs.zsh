# shellcheck shell=zsh
# Add visible subdirectories of ~/bin to PATH. The N qualifier makes an empty
# glob expand to nothing instead of raising a nomatch error.

if [[ -d "${HOME}/bin" ]]; then
    for _bin_subdir in "${HOME}/bin"/*(/N); do
        if [[ ":${PATH}:" != *":${_bin_subdir}:"* ]]; then
            PATH="${_bin_subdir}:${PATH}"
        fi
    done
    unset _bin_subdir
fi
