#!/usr/bin/env bash
# shellcheck shell=bash
#
# Full system update and cleanup for Debian/Ubuntu.
# Usage: apt-full

set -e
set -u

if ! command -v apt &>/dev/null; then
    echo "Error: apt not found. This script requires a Debian-based system." >&2
    exit 1
fi

# Update package index
apt update

# Check for broken dependencies
apt-get check

# Upgrade packages, handling changed dependencies
apt full-upgrade -y

# Remove unneeded dependencies and their config files
apt autoremove --purge -y

# Clean stale packages from the local cache
apt-get autoclean -y
