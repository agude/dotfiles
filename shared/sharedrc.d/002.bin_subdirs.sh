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
    for dir in "${HOME}/bin"/*/; do
        if [[ -d "$dir" ]]; then
            PATH="${dir%/}:${PATH}"
        fi
    done
fi
