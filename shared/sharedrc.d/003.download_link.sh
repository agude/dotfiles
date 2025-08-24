# ------------------------------------------------------------------------------
# Creates a downloads directory in /tmp and symlinks it to ~/Downloads.
#
# This is useful for keeping temporary downloads off the main drive or out of
# backups. The directory in /tmp is ephemeral and may be cleared on reboot.
# ------------------------------------------------------------------------------

# We wrap the logic in a function to keep variables local and avoid polluting
# the global shell environment.
setup_tmp_downloads() {
  # Use local variables that disappear after the function runs.
  local target_dir="/tmp/${USER}/downloads"
  local link_path="$HOME/Downloads"

  # 1. Create the target directory in /tmp.
  # The '-p' flag ensures parent directories are created and no error occurs
  # if the directory already exists.
  mkdir -p "$target_dir"

  # 2. Check if ~/Downloads already exists as a file or directory.
  # We only create the symlink if the path is clear, to avoid errors or
  # overwriting user data. This also handles the case of a broken symlink.
  if [[ ! -e "$link_path" ]]; then
    echo "Linking $link_path -> $target_dir"
    ln -s "$target_dir" "$link_path"
  fi
}

# Run the setup function.
setup_tmp_downloads

# The function's local variables are now gone, so no 'unset' is needed.
