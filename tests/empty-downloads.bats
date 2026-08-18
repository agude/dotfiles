#!/usr/bin/env bats

setup() {
    REPOSITORY_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    EMPTY_DOWNLOADS="${REPOSITORY_ROOT}/bin/empty-downloads.sh"
    TEST_ROOT="$(mktemp -d)"
    TEST_HOME="${TEST_ROOT}/home"
    mkdir "$TEST_HOME"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

run_cleanup() {
    run env HOME="$TEST_HOME" XDG_DOWNLOAD_DIR="$1" bash "$EMPTY_DOWNLOADS"
}

@test "cleanup removes contents but preserves Downloads" {
    downloads="${TEST_HOME}/Downloads"
    mkdir -p "${downloads}/nested"
    printf 'temporary\n' > "${downloads}/nested/file"

    run_cleanup "$downloads"

    [[ "$status" -eq 0 ]]
    [[ -d "$downloads" ]]
    [[ ! -e "${downloads}/nested" ]]
    [[ -f "${downloads}/README_folder_is_cleared_on_login.txt" ]]
}

@test "cleanup rejects the home directory" {
    printf 'keep\n' > "${TEST_HOME}/marker"

    run_cleanup "$TEST_HOME"

    [[ "$status" -eq 1 ]]
    [[ -f "${TEST_HOME}/marker" ]]
}

@test "cleanup rejects a path that escapes through dotdot" {
    outside="${TEST_ROOT}/outside"
    mkdir -p "${TEST_HOME}/inside" "$outside"
    printf 'keep\n' > "${outside}/marker"

    run_cleanup "${TEST_HOME}/inside/../../outside"

    [[ "$status" -eq 1 ]]
    [[ -f "${outside}/marker" ]]
}

@test "cleanup rejects a path with an external symlink ancestor" {
    outside="${TEST_ROOT}/outside"
    mkdir -p "${outside}/Downloads"
    printf 'keep\n' > "${outside}/Downloads/marker"
    ln -s "$outside" "${TEST_HOME}/external"

    run_cleanup "${TEST_HOME}/external/Downloads"

    [[ "$status" -eq 1 ]]
    [[ -f "${outside}/Downloads/marker" ]]
}

@test "cleanup rejects a leaf symlink" {
    actual_downloads="${TEST_HOME}/ActualDownloads"
    mkdir "$actual_downloads"
    printf 'keep\n' > "${actual_downloads}/marker"
    ln -s "$actual_downloads" "${TEST_HOME}/Downloads"

    run_cleanup "${TEST_HOME}/Downloads"

    [[ "$status" -eq 1 ]]
    [[ -f "${actual_downloads}/marker" ]]
}

@test "cleanup succeeds when Downloads is absent" {
    run_cleanup "${TEST_HOME}/Downloads"

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Downloads directory not found"* ]]
}

@test "cleanup prevents mounted-filesystem traversal" {
    downloads="${TEST_HOME}/Downloads"
    test_bin="${TEST_ROOT}/bin"
    find_arguments="${TEST_ROOT}/find-arguments"
    mkdir "$downloads" "$test_bin"
    cat > "${test_bin}/find" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$FIND_ARGUMENTS"
EOF
    chmod +x "${test_bin}/find"

    run env HOME="$TEST_HOME" \
        XDG_DOWNLOAD_DIR="$downloads" \
        PATH="${test_bin}:${PATH}" \
        FIND_ARGUMENTS="$find_arguments" \
        bash "$EMPTY_DOWNLOADS"

    [[ "$status" -eq 0 ]]
    grep -Fxq -- '-xdev' "$find_arguments"
}
