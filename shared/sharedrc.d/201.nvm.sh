# shellcheck shell=sh
# ------------------------------------------------------------------------------
# NVM (Node Version Manager) Configuration
# Loads NVM and its bash completion for managing Node.js versions.
# Only runs if NVM is installed.
# ------------------------------------------------------------------------------

# Only configure NVM if it's installed
if [ -d "$HOME/.config/nvm" ]; then
    export NVM_DIR="$HOME/.config/nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi
