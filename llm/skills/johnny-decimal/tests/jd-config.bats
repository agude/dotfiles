#!/usr/bin/env bats

load test_helper

@test "loads root and JDex from the XDG config" {
    local configured_root="$TEST_TEMP/Configured Documents"
    local config_home="$TEST_TEMP/config"
    local config_path="$config_home/johnnydecimal/config.json"
    local configured_jdex="$configured_root/00-09 System/00 System/00.00 JDex for System"

    create_jd_tree "$configured_root"
    mkdir -p "$(dirname "$config_path")"
    printf '%s\n' \
        '{' \
        '  "version": 1,' \
        '  "root": "${XDG_DOCUMENTS_DIR}",' \
        '  "jdex": "${XDG_DOCUMENTS_DIR}/00-09 System/00 System/00.00 JDex for System"' \
        '}' > "$config_path"
    printf '%s\n' '# 21.10 Alliant Credit Union' > "$configured_jdex/21.10.md"

    run env -u JD_ROOT -u JDEX_PATH -u JD_CONFIG \
        XDG_CONFIG_HOME="$config_home" \
        XDG_DOCUMENTS_DIR="$configured_root" \
        "$SCRIPT_DIR/jd-read.sh" 21.10 --porcelain

    [[ "$status" -eq 0 ]]
    [[ "$output" == "$configured_jdex/21.10.md" ]]
}

@test "explicit root and JDex overrides beat the XDG config" {
    local configured_root="$TEST_TEMP/Configured Documents"
    local config_home="$TEST_TEMP/config"
    local config_path="$config_home/johnnydecimal/config.json"

    create_jd_tree "$configured_root"
    mkdir -p "$(dirname "$config_path")"
    printf '%s\n' \
        '{' \
        '  "version": 1,' \
        '  "root": "'"$configured_root"'",' \
        '  "jdex": "'"$configured_root"'/wrong-jdex"' \
        '}' > "$config_path"
    printf '%s\n' '# 21.10 Alliant Credit Union' > "$JDEX_PATH/21.10.md"

    run env \
        JD_ROOT="$JD_ROOT" \
        JDEX_PATH="$JDEX_PATH" \
        JD_CONFIG="$config_path" \
        "$SCRIPT_DIR/jd-read.sh" 21.10 --porcelain

    [[ "$status" -eq 0 ]]
    [[ "$output" == "$JDEX_PATH/21.10.md" ]]
}

@test "derived XDG defaults are not exported to child processes" {
    run env \
        -u XDG_CONFIG_HOME \
        -u XDG_DOCUMENTS_DIR \
        -u JD_ROOT \
        -u JDEX_PATH \
        JD_CONFIG="$TEST_TEMP/missing-config.json" \
        bash -c 'source "$1"; env | grep -E "^(XDG_CONFIG_HOME|XDG_DOCUMENTS_DIR)="' \
        bash "$SCRIPT_DIR/jd-lib.sh"

    [[ "$status" -eq 1 ]]
    [[ -z "$output" ]]
}
