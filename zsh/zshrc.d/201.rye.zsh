# ------------------------------------------------------------------------------
# Rye (Python Environment Manager) Setup
#
# This sources the Rye environment script, which adds its shims to the PATH.
# This is the modern replacement for the old pyenv setup.
# ------------------------------------------------------------------------------

RYE_ENV_FILE="$HOME/.rye/env"

# Load Rye into the shell session if its env file exists.
if [[ -s "$RYE_ENV_FILE" ]]; then
    source "$RYE_ENV_FILE"
fi

unset -v RYE_ENV_FILE
