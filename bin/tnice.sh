#!/usr/bin/env bash
# shellcheck shell=bash

# Exit if any errors or if any needed variables are unset
set -e
set -u

# Wrap the command in nice
nice -n 19 ionice -c 2 -n 7 "$@"

# Return exit code
exit $?
