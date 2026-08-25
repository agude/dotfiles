#!/usr/bin/env bats

load test_helper

@test "scripts resolve through symlinks without readlink -f" {
    local bin_dir="$TEST_TEMP/bin"
    local linked_script="$bin_dir/jd-read"
    local system_readlink

    system_readlink="$(command -v readlink)"
    mkdir -p "$bin_dir"
    ln -s "$SCRIPT_DIR/jd-read.sh" "$linked_script"
    printf '%s\n' '# 21.10 Alliant Credit Union' > "$JDEX_PATH/21.10.md"
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'if [[ "$1" == "-f" ]]; then exit 99; fi' \
        "exec \"$system_readlink\" \"\$@\"" > "$bin_dir/readlink"
    chmod +x "$bin_dir/readlink"

    run env \
        PATH="$bin_dir:$PATH" \
        JD_ROOT="$JD_ROOT" \
        JDEX_PATH="$JDEX_PATH" \
        "$linked_script" 21.10 --porcelain

    [[ "$status" -eq 0 ]]
    [[ "$output" == "$JDEX_PATH/21.10.md" ]]
}
