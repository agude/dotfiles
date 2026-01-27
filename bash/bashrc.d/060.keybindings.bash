# shellcheck shell=bash
# ~/.bashrc.d/060.keybindings.bash
# ------------------------------------------------------------------------------
# Custom Bash Keybindings
# ------------------------------------------------------------------------------

# Only set up keybindings for interactive shells, as they are meaningless otherwise.
if [[ $- == *i* ]]; then
    # --- Arrow Key History Search ---
    # Search history based on what's already typed on the command line.
    # Type "git" then press Up to find previous "git" commands.

    # Up Arrow: search backward through history
    bind '"\e[A": history-search-backward'

    # Down Arrow: search forward through history
    bind '"\e[B": history-search-forward'
fi
