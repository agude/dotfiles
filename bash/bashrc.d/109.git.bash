# shellcheck shell=bash
if [[ -x $(command -v brew) ]]; then
    SCRIPT_FILE="$(brew --prefix)"/etc/bash_completion.d/git-completion.bash

    if [[ -f ${SCRIPT_FILE} ]]; then
        source ${SCRIPT_FILE}
    fi

    unset SCRIPT_FILE
fi
