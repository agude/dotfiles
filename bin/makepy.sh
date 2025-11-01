#!/usr/bin/env bash
# shellcheck shell=bash

# This script creates a temporary Python virtual environment using 'uv',
# drops the user into a new shell within that environment, and automatically
# cleans it up upon exit.

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if uv is installed.
if ! command -v uv >/dev/null 2>&1; then
    echo "Error: 'uv' is not installed or not in your PATH." >&2
    echo "Please install it: https://github.com/astral-sh/uv" >&2
    exit 1
fi

# Determine which Python interpreter to use.
# Use the first argument if provided (e.g., 'python3.11'), otherwise find the current python.
if [ -n "$1" ]; then
  python_interpreter="$1"
else
  python_interpreter=$(command -v python)
fi

# Create a secure temporary directory for the virtual environment.
venv_path=$(mktemp -d)

# Set up a trap to automatically remove the temporary directory when the script exits.
# This ensures cleanup happens even if the script is interrupted.
trap 'echo "Destroying temporary virtualenv..."; rm -rf "$venv_path"' EXIT

# Create the virtual environment with uv.
echo "Creating temporary virtualenv with '${python_interpreter}'..."
uv venv -p "${python_interpreter}" "${venv_path}" --seed

echo
echo "Entering a new shell session in a temporary virtualenv."
echo "It will be removed when you exit (ctrl+d or 'exit')."
echo "Path: ${venv_path}"

# Activate the environment by prepending its bin directory to the PATH,
# set the VIRTUAL_ENV variable for introspection, and launch a new shell.
export VIRTUAL_ENV="${venv_path}"
PATH="${venv_path}/bin:${PATH}" "$SHELL"
