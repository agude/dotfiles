#!/usr/bin/env bash
# shellcheck shell=bash
#
# Rename files, replacing spaces with underscores and collapsing _-_ to -.
# Usage: rmspace FILE ...

set -e
set -u

if [[ $# -eq 0 ]]; then
    echo "Usage: rmspace FILE ..." >&2
    exit 1
fi

for file in "$@"; do
    dir=$(dirname -- "$file")
    base=$(basename -- "$file")

    new_base="${base// /_}"
    new_base="${new_base//_-_/-}"

    if [[ "${base}" == "${new_base}" ]]; then
        continue
    fi

    new_path="${dir}/${new_base}"

    if [[ -e "${new_path}" ]]; then
        echo "skip: '${new_path}' already exists" >&2
        continue
    fi

    mv -- "${file}" "${new_path}"
done
