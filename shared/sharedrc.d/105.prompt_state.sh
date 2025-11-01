# shellcheck shell=bash
# ------------------------------------------------------------------------------
# Prompt State Detection - Sets environment variables for shell-specific prompts
# ------------------------------------------------------------------------------

# Detect user privilege level and remote status
# Sets PROMPT_USER_STATE for shell-specific prompt files to use.
# The `${VAR-}` syntax is used to prevent "unbound variable" errors if `set -u` is active.
if [[ $EUID -eq 0 ]]; then
    export PROMPT_USER_STATE="root"
elif [[ -n "${SUDO_USER-}" ]]; then
    export PROMPT_USER_STATE="sudo"
elif [[ -n "${SSH_CLIENT-}" || -n "${SSH_TTY-}" || -n "${SSH_CONNECTION-}" ]]; then
    export PROMPT_USER_STATE="remote"
else
    export PROMPT_USER_STATE="local"
fi
