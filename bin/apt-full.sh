#!/usr/bin/env bash

# Exit if any errors or if any needed variables are unset
set -e
set -u

# Update the list of packages
apt-get update &&
# Check for broken dependencies
apt-get check &&
# Upgrade to new packages, with smart handling of changing dependencies
apt-get dist-upgrade -y &&
# Purge unneeded dependencies
apt-get autoremove --purge -y &&
# Clean up packages in the cache that are no longer in the repo
apt-get autoclean -y

# Return exit code
exit $?
