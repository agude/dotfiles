#!/usr/bin/env bash
# Read the deliberately small TOML policy without adding a parser dependency.

policy_value() {
    local policy_file="$1" section="$2" key="$3"
    awk -F= -v wanted_section="$section" -v wanted_key="$key" '
        $0 ~ /^[[:space:]]*\[/ {
            current = $0
            gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", current)
        }
        current == wanted_section && $1 ~ "^[[:space:]]*" wanted_key "[[:space:]]*$" {
            value = $2
            sub(/[[:space:]]+#.*$/, "", value)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            gsub(/^"|"$/, "", value)
            print value
            exit
        }
    ' "$policy_file"
}

policy_array() {
    local policy_file="$1" section="$2" key="$3"
    policy_value "$policy_file" "$section" "$key" |
        tr -d '[]"' |
        tr ',' '\n' |
        sed 's/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d'
}

policy_action() {
    policy_value "$1" "actions.$2" ref
}
