#!/usr/bin/env bash
# shellcheck shell=bash
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
# Reject a leaf symlink rather than deleting through an indirect target.
if [[ -L "$DOWNLOAD_DIR" ]]; then
    echo "Error: Unsafe DOWNLOAD_DIR detected: '${DOWNLOAD_DIR}'. Aborting." >&2
    exit 1
fi

# A missing directory has no contents to clear.
if [[ ! -d "$DOWNLOAD_DIR" ]]; then
    echo "Downloads directory not found at '${DOWNLOAD_DIR}', exiting."
    exit 0
fi

# Resolve both paths before comparing them. A textual "$HOME/" prefix is not
# sufficient because `..` and intermediate symlinks can escape the home tree.
home_physical=""
download_physical=""
if ! home_physical="$(cd "$HOME" 2>/dev/null && pwd -P)"; then
    echo "Error: Cannot resolve HOME: '${HOME}'. Aborting." >&2
    exit 1
fi
if ! download_physical="$(cd "$DOWNLOAD_DIR" 2>/dev/null && pwd -P)"; then
    echo "Error: Cannot resolve DOWNLOAD_DIR: '${DOWNLOAD_DIR}'. Aborting." >&2
    exit 1
fi

if [[ -z "$download_physical" || \
      "$download_physical" == "$home_physical" || \
      "$download_physical" != "$home_physical/"* ]]; then
    echo "Error: Unsafe DOWNLOAD_DIR detected: '${DOWNLOAD_DIR}'. Aborting." >&2
    exit 1
fi

DOWNLOAD_DIR="$download_physical"
echo "Clearing contents of '${DOWNLOAD_DIR}'..."

# Do not cross into filesystems mounted beneath Downloads.
find "${DOWNLOAD_DIR}" -xdev -mindepth 1 -delete

echo "Successfully cleared '${DOWNLOAD_DIR}'."

# Create a reminder file so the user knows why the directory is empty.
cat > "${DOWNLOAD_DIR}/README_folder_is_cleared_on_login.txt" << EOF
The contents of this directory are automatically deleted on every user login.
This behavior is managed by a systemd/launchd service defined in your dotfiles.
See bin/empty-downloads.sh for the script that performs this action.
EOF
