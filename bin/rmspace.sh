#!/usr/bin/env bash
# shellcheck shell=bash

# Exit if any errors or if any needed variables are unset
set -e
set -u

# Replace every file, but only if it doesn't already conform to our naming
# scheme, and if it would not overwrite an already existent file
for file in *; do
    # s/  */_/g replaces spaces with _
    # s/_-_/-/g replaces _-_ with -
    new_name=$(echo "${file}" | sed -e 's/  */_/g' -e 's/_-_/-/g')
    # Only move if it doesn't already exist, and isn't already the right name
    if [[ ! -f ${new_name} && "${file}" != "${new_name}" ]]; then
        mv "${file}" "${new_name}"
    fi
done

# Return exit code
exit $?
