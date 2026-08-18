#!/usr/bin/env bats

setup() {
    REPOSITORY_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_ROOT="$(mktemp -d)"
    FIXTURE_REPOSITORY="${TEST_ROOT}/dotfiles"
    TEST_HOME="${TEST_ROOT}/home"

    mkdir -p "${FIXTURE_REPOSITORY}/profiles" \
             "${FIXTURE_REPOSITORY}/fixture" \
             "$TEST_HOME"
    cp "${REPOSITORY_ROOT}/install.sh" "${FIXTURE_REPOSITORY}/install.sh"
    chmod +x "${FIXTURE_REPOSITORY}/install.sh"

    create_default_profile
    create_disabled_profile
    create_link_map
    printf 'fixture\n' > "${FIXTURE_REPOSITORY}/fixture/source"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

create_default_profile() {
    cat > "${FIXTURE_REPOSITORY}/profiles/default.sh" <<'EOF'
INSTALL_SHELL=false
INSTALL_VIM=false
INSTALL_GIT=false
INSTALL_SCRIPTS=false
INSTALL_GUI=false
INSTALL_LLM=false
INSTALL_CLEANUP=false
INSTALL_FIXTURE=true

CLAUDE_SETTINGS_REL=""
CLAUDE_AGENTS_REL=""
GEMINI_SETTINGS_REL=""
GEMINI_AGENTS_REL=""
CODEX_SETTINGS_REL=""
CODEX_AGENTS_REL=""
EOF
}

create_disabled_profile() {
    cat > "${FIXTURE_REPOSITORY}/profiles/disabled.sh" <<'EOF'
INSTALL_FIXTURE=false
EOF
}

create_link_map() {
    cat > "${FIXTURE_REPOSITORY}/links.conf" <<'EOF'
${HOME}/.fixture-link | fixture/source  | fixture
${HOME}/.fixture-dir/config | fixture/source | fixture
${HOME}/.missing-link | fixture/missing | fixture
EOF
}

run_installer() {
    run env HOME="$TEST_HOME" \
        XDG_CONFIG_HOME="${TEST_HOME}/.config" \
        bash "${FIXTURE_REPOSITORY}/install.sh" "$@"
}

@test "installer creates the expected link and manifest" {
    run_installer --profile default

    [[ "$status" -eq 0 ]]
    [[ -L "${TEST_HOME}/.fixture-link" ]]
    [[ "$(readlink "${TEST_HOME}/.fixture-link")" == "${FIXTURE_REPOSITORY}/fixture/source" ]]
    grep -Fxq "${TEST_HOME}/.fixture-link" "${FIXTURE_REPOSITORY}/.link-manifest"
}

@test "installer is idempotent" {
    run_installer --profile default
    [[ "$status" -eq 0 ]]

    run_installer
    [[ "$status" -eq 0 ]]
    [[ "$output" != *"Backing up"* ]]
    [[ "$output" != *"Updating"* ]]
}

@test "installer backs up a real file" {
    printf 'local\n' > "${TEST_HOME}/.fixture-link"

    run_installer --profile default

    [[ "$status" -eq 0 ]]
    [[ -L "${TEST_HOME}/.fixture-link" ]]
    run find "$TEST_HOME" -maxdepth 1 -type f -name '.fixture-link.dotfiles-backup.*'
    [[ "$status" -eq 0 ]]
    [[ -n "$output" ]]
    grep -Fxq 'local' "$output"
}

@test "installer backs up a real directory" {
    mkdir "${TEST_HOME}/.fixture-link"
    printf 'local\n' > "${TEST_HOME}/.fixture-link/marker"

    run_installer --profile default

    [[ "$status" -eq 0 ]]
    [[ -L "${TEST_HOME}/.fixture-link" ]]
    run find "$TEST_HOME" -maxdepth 1 -type d -name '.fixture-link.dotfiles-backup.*'
    [[ "$status" -eq 0 ]]
    [[ -n "$output" ]]
    grep -Fxq 'local' "${output}/marker"
}

@test "installer backs up a foreign parent symlink" {
    foreign_directory="${TEST_ROOT}/foreign"
    mkdir "$foreign_directory"
    printf 'foreign\n' > "${foreign_directory}/marker"
    ln -s "$foreign_directory" "${TEST_HOME}/.fixture-dir"

    run_installer --profile default

    [[ "$status" -eq 0 ]]
    [[ -d "${TEST_HOME}/.fixture-dir" ]]
    [[ ! -L "${TEST_HOME}/.fixture-dir" ]]
    grep -Fxq 'foreign' "${foreign_directory}/marker"
    run find "$TEST_HOME" -maxdepth 1 -type l -name '.fixture-dir.dotfiles-backup.*'
    [[ "$status" -eq 0 ]]
    [[ -n "$output" ]]
    [[ "$(readlink "$output")" == "$foreign_directory" ]]
}

@test "installer replaces a managed parent symlink" {
    managed_directory="${FIXTURE_REPOSITORY}/fixture/old-parent"
    mkdir "$managed_directory"
    ln -s "$managed_directory" "${TEST_HOME}/.fixture-dir"

    run_installer --profile default

    [[ "$status" -eq 0 ]]
    [[ -d "${TEST_HOME}/.fixture-dir" ]]
    [[ ! -L "${TEST_HOME}/.fixture-dir" ]]
    run find "$TEST_HOME" -maxdepth 1 -name '.fixture-dir.dotfiles-backup.*'
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "installer excludes missing sources from the manifest" {
    run_installer --profile default

    [[ "$status" -eq 0 ]]
    [[ ! -e "${TEST_HOME}/.missing-link" ]]
    run grep -Fq "${TEST_HOME}/.missing-link" "${FIXTURE_REPOSITORY}/.link-manifest"
    [[ "$status" -eq 1 ]]
}

@test "dry run does not change the filesystem" {
    run_installer --dry-run --profile default

    [[ "$status" -eq 0 ]]
    [[ ! -e "${TEST_HOME}/.fixture-link" ]]
    [[ ! -e "${FIXTURE_REPOSITORY}/.active-profile" ]]
    [[ ! -e "${FIXTURE_REPOSITORY}/.link-manifest" ]]
}

@test "profile switch removes only the managed link" {
    run_installer --profile default
    [[ "$status" -eq 0 ]]
    [[ -L "${TEST_HOME}/.fixture-link" ]]

    run_installer --profile disabled

    [[ "$status" -eq 0 ]]
    [[ ! -e "${TEST_HOME}/.fixture-link" ]]
    [[ "$(<"${FIXTURE_REPOSITORY}/.active-profile")" == "disabled" ]]
}
