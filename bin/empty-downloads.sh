#!/usr/bin/env bash
#
# Empties the user's Downloads directory.
#
# This script is designed to be run non-interactively by a systemd service or
# other automated process on login or reboot. It safely removes all files and
# subdirectories from the Downloads folder without removing the folder itself.

# Exit immediately if a command exits with a non-zero status.
set -e
# Treat unset variables as an error when substituting.
set -u

# Determine the target directory using the XDG standard variable if it's set,
# otherwise fall back to the traditional default location.
DOWNLOAD_DIR="${XDG_DOWNLOAD_DIR:-${HOME}/Downloads}"

# --- Safety Checks ---
# 1. Ensure the path is not empty.
# 2. Ensure it is not the HOME directory itself.
# 3. Ensure it is located *within* the HOME directory (starts with "$HOME/").
if [[ -z "$DOWNLOAD_DIR" || "$DOWNLOAD_DIR" == "$HOME" || "$DOWNLOAD_DIR" != "$HOME/"* ]]; then
    echo "Error: Unsafe DOWNLOAD_DIR detected: '${DOWNLOAD_DIR}'. Aborting." >&2
    exit 1
fi

# If the directory doesn't exist for some reason, there's nothing to do.
if [[ ! -d "$DOWNLOAD_DIR" ]]; then
    echo "Downloads directory not found at '${DOWNLOAD_DIR}', exiting."
    exit 0
fi

echo "Clearing contents of '${DOWNLOAD_DIR}'..."

# Use 'find' to delete all contents within the directory.
# -mindepth 1 is crucial; it tells find to start looking at the items *inside*
#   the directory, not the directory itself.
# -delete is an efficient, built-in find action for removing matched files.
find "${DOWNLOAD_DIR}" -mindepth 1 -delete

echo "Successfully cleared '${DOWNLOAD_DIR}'."

# Create a reminder file so the user knows why the directory is empty.
cat > "${DOWNLOAD_DIR}/README_folder_is_cleared_on_login.txt" << EOF
The contents of this directory are automatically deleted on every user login.
This behavior is managed by a systemd/launchd service defined in your dotfiles.
See bin/empty-downloads.sh for the script that performs this action.
EOF
