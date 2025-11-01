# shellcheck shell=bash
# ------------------------------------------------------------------------------
# Git Bash Completion
# ------------------------------------------------------------------------------

# Source the git completion script if it exists.
# It's usually installed by package managers like apt or homebrew.
if [[ -f /etc/bash_completion.d/git-completion.bash ]]; then
    # shellcheck disable=SC1091
    source /etc/bash_completion.d/git-completion.bash
elif [[ -f "$(brew --prefix)/etc/bash_completion.d/git-completion.bash" ]]; then
    # shellcheck disable=SC1090,SC1091
    source "$(brew --prefix)/etc/bash_completion.d/git-completion.bash"
fi
