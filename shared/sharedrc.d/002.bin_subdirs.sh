# shellcheck shell=bash
#
# Add subdirectories of ~/bin to PATH
#
# This allows organizing scripts into subdirectories like:
#   ~/bin/johnny-decimal/jd-note
#   ~/bin/some-other-tool/script
#
# Each subdirectory is added to PATH so scripts are directly callable.

if [[ -d "${HOME}/bin" ]]; then
    # Add subdirectories to PATH, handling empty glob safely:
    # - Bash: nullglob makes empty glob expand to nothing
    # - Zsh: (N) glob qualifier does the same
    if [[ -n "$BASH_VERSION" ]]; then
        shopt -s nullglob
        for dir in "${HOME}/bin"/*/; do
            PATH="${dir%/}:${PATH}"
        done
        shopt -u nullglob
    elif [[ -n "$ZSH_VERSION" ]]; then
        for dir in "${HOME}/bin"/*(/N); do
            PATH="${dir}:${PATH}"
        done
    fi
fi
