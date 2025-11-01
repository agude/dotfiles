# shellcheck shell=bash
RVM_BIN_PATH="${HOME}/.rvm/bin"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
if [[ -d ${RVM_BIN_PATH} ]]; then
    export PATH="${PATH}:${RVM_BIN_PATH}"
fi

# Load RVM into a shell session *as a function*
if [[ -s "${HOME}/.rvm/scripts/rvm" ]]; then
    source "${HOME}/.rvm/scripts/rvm"
fi

unset -v RVM_BIN_PATH
