#!/usr/bin/env bats

setup() {
    REPOSITORY_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_ROOT="$(mktemp -d)"
    FIXTURE_REPOSITORY="${TEST_ROOT}/dotfiles"
    TEST_HOME="${TEST_ROOT}/home"
    TEST_BIN="${TEST_ROOT}/bin"

    mkdir -p "${FIXTURE_REPOSITORY}/config/firefox" \
             "${FIXTURE_REPOSITORY}/config/systemd/user" \
             "${FIXTURE_REPOSITORY}/llm/codex" \
             "${FIXTURE_REPOSITORY}/profiles" \
             "${FIXTURE_REPOSITORY}/shared/sharedrc.d" \
             "${FIXTURE_REPOSITORY}/bin" \
             "${FIXTURE_REPOSITORY}/fixture" \
             "$TEST_BIN" \
             "$TEST_HOME"
    cp "${REPOSITORY_ROOT}/install.sh" "${FIXTURE_REPOSITORY}/install.sh"
    chmod +x "${FIXTURE_REPOSITORY}/install.sh"

    create_default_profile
    create_disabled_profile
    create_shell_profile
    create_vim_profile
    create_scripts_profile
    create_codex_profile
    create_deployment_profile
    create_link_map
    printf 'fixture\n' > "${FIXTURE_REPOSITORY}/fixture/source"
    printf 'user prefs\n' > "${FIXTURE_REPOSITORY}/config/firefox/user.js"
    printf 'downloads service\n' > "${FIXTURE_REPOSITORY}/config/systemd/user/empty-downloads.service"
    printf 'firefox service\n' > "${FIXTURE_REPOSITORY}/config/systemd/user/firefox-quit.service"
    printf 'personality = "pragmatic"\n' > "${FIXTURE_REPOSITORY}/llm/codex/agude.config.toml"
    printf 'export PLATFORM=linux\n' > \
        "${FIXTURE_REPOSITORY}/shared/sharedrc.d/000.set_platform.sh"
    cp "${REPOSITORY_ROOT}/shared/sharedrc.d/001.xdg_base_directory.sh" \
        "${FIXTURE_REPOSITORY}/shared/sharedrc.d/001.xdg_base_directory.sh"
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

create_shell_profile() {
    cat > "${FIXTURE_REPOSITORY}/profiles/shell.sh" <<'EOF'
INSTALL_SHELL=true
EOF
}

create_vim_profile() {
    cat > "${FIXTURE_REPOSITORY}/profiles/vim.sh" <<'EOF'
INSTALL_VIM=true
EOF
}

create_scripts_profile() {
    cat > "${FIXTURE_REPOSITORY}/profiles/scripts.sh" <<'EOF'
INSTALL_SCRIPTS=true
EOF
}

create_codex_profile() {
    cat > "${FIXTURE_REPOSITORY}/profiles/codex.sh" <<'EOF'
INSTALL_LLM=true
EOF
}

create_deployment_profile() {
    cat > "${FIXTURE_REPOSITORY}/profiles/deployment.sh" <<'EOF'
INSTALL_GUI=true
INSTALL_CLEANUP=true
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
        PATH="${TEST_BIN}:${PATH}" \
        bash "${FIXTURE_REPOSITORY}/install.sh" "$@"
}

assert_single_result() {
    [[ -n "$output" ]]
    [[ "$output" != *$'\n'* ]]
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
    assert_single_result
    backup_path="$output"
    grep -Fxq 'local' "$backup_path"
}

@test "installer backs up a real directory" {
    mkdir "${TEST_HOME}/.fixture-link"
    printf 'local\n' > "${TEST_HOME}/.fixture-link/marker"

    run_installer --profile default

    [[ "$status" -eq 0 ]]
    [[ -L "${TEST_HOME}/.fixture-link" ]]
    run find "$TEST_HOME" -maxdepth 1 -type d -name '.fixture-link.dotfiles-backup.*'
    [[ "$status" -eq 0 ]]
    assert_single_result
    backup_path="$output"
    grep -Fxq 'local' "${backup_path}/marker"
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
    assert_single_result
    backup_path="$output"
    [[ "$(readlink "$backup_path")" == "$foreign_directory" ]]
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

@test "installer backs up and manages deployed configuration files" {
    firefox_root="${TEST_HOME}/.mozilla/firefox"
    first_profile="${firefox_root}/alpha.default-release"
    second_profile="${firefox_root}/beta.default-release"
    systemd_directory="${TEST_HOME}/.config/systemd/user"
    mkdir -p "$first_profile" "$second_profile" "$systemd_directory"
    printf 'local prefs\n' > "${first_profile}/user.js"
    printf 'local service\n' > "${systemd_directory}/empty-downloads.service"
    printf '#!/usr/bin/env bash\n' > "${TEST_BIN}/firefox"
    printf '#!/usr/bin/env bash\n' > "${TEST_BIN}/systemctl"
    chmod +x "${TEST_BIN}/firefox" "${TEST_BIN}/systemctl"

    run_installer --profile deployment

    [[ "$status" -eq 0 ]]
    [[ -L "${first_profile}/user.js" ]]
    [[ -L "${second_profile}/user.js" ]]
    [[ -L "${systemd_directory}/empty-downloads.service" ]]
    [[ -L "${systemd_directory}/firefox-quit.service" ]]
    run find "$first_profile" -maxdepth 1 -type f -name 'user.js.dotfiles-backup.*'
    [[ "$status" -eq 0 ]]
    assert_single_result
    backup_path="$output"
    grep -Fxq 'local prefs' "$backup_path"
    run find "$systemd_directory" -maxdepth 1 -type f \
        -name 'empty-downloads.service.dotfiles-backup.*'
    [[ "$status" -eq 0 ]]
    assert_single_result
    backup_path="$output"
    grep -Fxq 'local service' "$backup_path"
}

@test "profile switch removes deployed configuration links" {
    firefox_profile="${TEST_HOME}/.mozilla/firefox/alpha.default-release"
    mkdir -p "$firefox_profile"
    printf '#!/usr/bin/env bash\n' > "${TEST_BIN}/firefox"
    printf '#!/usr/bin/env bash\n' > "${TEST_BIN}/systemctl"
    chmod +x "${TEST_BIN}/firefox" "${TEST_BIN}/systemctl"

    run_installer --profile deployment
    [[ "$status" -eq 0 ]]

    run_installer --profile default

    [[ "$status" -eq 0 ]]
    [[ ! -e "${firefox_profile}/user.js" ]]
    [[ ! -e "${TEST_HOME}/.config/systemd/user/empty-downloads.service" ]]
    [[ ! -e "${TEST_HOME}/.config/systemd/user/firefox-quit.service" ]]
}

@test "installer rejects extensionless script name collisions before linking" {
    printf '#!/usr/bin/env bash\n' > "${FIXTURE_REPOSITORY}/bin/report.sh"
    printf '#!/usr/bin/env python3\n' > "${FIXTURE_REPOSITORY}/bin/report.py"

    run_installer --profile scripts

    [[ "$status" -ne 0 ]]
    [[ "$output" == *"bin command name collision for 'report'"* ]]
    [[ "$output" == *"report.sh"* ]]
    [[ "$output" == *"report.py"* ]]
    [[ ! -e "${TEST_HOME}/.fixture-link" ]]
    [[ ! -e "${TEST_HOME}/bin/report" ]]
}

@test "normal installation does not run plugin network commands" {
    export NETWORK_MARKER="${TEST_ROOT}/network-command-ran"
    cat > "${TEST_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
: > "$NETWORK_MARKER"
EOF
    cat > "${TEST_BIN}/nvim" <<'EOF'
#!/usr/bin/env bash
: > "$NETWORK_MARKER"
EOF
    chmod +x "${TEST_BIN}/curl" "${TEST_BIN}/nvim"

    run_installer --profile vim

    [[ "$status" -eq 0 ]]
    [[ ! -e "$NETWORK_MARKER" ]]

    run_installer

    [[ "$status" -eq 0 ]]
    [[ ! -e "$NETWORK_MARKER" ]]
}

@test "installer initializes XDG application directories" {
    run_installer --profile shell

    [[ "$status" -eq 0 ]]
    [[ -d "${TEST_HOME}/.config/jupyter" ]]
    [[ -d "${TEST_HOME}/.config/gimp" ]]
    [[ -d "${TEST_HOME}/.config/gnupg" ]]

    if stat -f '%Lp' "${TEST_HOME}/.config/gnupg" >/dev/null 2>&1; then
        run stat -f '%Lp' "${TEST_HOME}/.config/gnupg"
    else
        run stat -c '%a' "${TEST_HOME}/.config/gnupg"
    fi
    [[ "$status" -eq 0 ]]
    [[ "$output" == "700" ]]
}

@test "dry-run does not initialize XDG application directories" {
    run_installer --dry-run --profile shell

    [[ "$status" -eq 0 ]]
    [[ ! -e "${TEST_HOME}/.config/jupyter" ]]
    [[ ! -e "${TEST_HOME}/.config/gimp" ]]
    [[ ! -e "${TEST_HOME}/.config/gnupg" ]]
}

@test "installer creates a mutable local Codex profile" {
    run_installer --profile codex

    local_profile="${TEST_HOME}/.codex/agude.config.toml"
    [[ "$status" -eq 0 ]]
    [[ -f "$local_profile" ]]
    [[ ! -L "$local_profile" ]]
    grep -Fxq 'personality = "pragmatic"' "$local_profile"
}

@test "installer preserves existing local Codex state" {
    run_installer --profile codex
    [[ "$status" -eq 0 ]]
    local_profile="${TEST_HOME}/.codex/agude.config.toml"
    printf '\n[projects."/test"]\ntrust_level = "trusted"\n' >> "$local_profile"

    run_installer

    [[ "$status" -eq 0 ]]
    grep -Fxq '[projects."/test"]' "$local_profile"
}

@test "installer migrates a managed Codex profile symlink" {
    local_profile="${TEST_HOME}/.codex/agude.config.toml"
    mkdir -p "${TEST_HOME}/.codex"
    printf '\n[hooks.state]\n' >> "${FIXTURE_REPOSITORY}/llm/codex/agude.config.toml"
    ln -s "${FIXTURE_REPOSITORY}/llm/codex/agude.config.toml" "$local_profile"

    run_installer --profile codex

    [[ "$status" -eq 0 ]]
    [[ -f "$local_profile" ]]
    [[ ! -L "$local_profile" ]]
    grep -Fxq '[hooks.state]' "$local_profile"
    if stat -f '%Lp' "$local_profile" >/dev/null 2>&1; then
        run stat -f '%Lp' "$local_profile"
    else
        run stat -c '%a' "$local_profile"
    fi
    [[ "$status" -eq 0 ]]
    [[ "$output" == "600" ]]
}

@test "installer preserves a foreign Codex profile symlink" {
    foreign_profile="${TEST_ROOT}/foreign-codex-profile.toml"
    local_profile="${TEST_HOME}/.codex/agude.config.toml"
    mkdir -p "${TEST_HOME}/.codex"
    printf 'foreign = true\n' > "$foreign_profile"
    ln -s "$foreign_profile" "$local_profile"

    run_installer --profile codex

    [[ "$status" -eq 0 ]]
    [[ -L "$local_profile" ]]
    [[ "$(readlink "$local_profile")" == "$foreign_profile" ]]
    [[ "$output" == *"foreign config symlink exists, skipping"* ]]
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

@test "installer rejects unknown link groups before linking" {
    printf '${HOME}/.invalid-link | fixture/source | typo\n' >> \
        "${FIXTURE_REPOSITORY}/links.conf"

    run_installer --profile default

    [[ "$status" -eq 1 ]]
    [[ "$output" == *"links.conf:4: unknown group 'typo'"* ]]
    [[ ! -e "${TEST_HOME}/.fixture-link" ]]
    [[ ! -e "${TEST_HOME}/.invalid-link" ]]
}

@test "show reports an ephemeral profile without installing" {
    run_installer --show --profile shell

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Profile: shell"* ]]
    [[ "$output" == *"  + shell"* ]]
    [[ "$output" == *"  - vim  (disabled)"* ]]
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
