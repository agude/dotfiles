#!/usr/bin/env bats
#
# Guards llm/opencode/opencode.json against shapes OpenCode rejects at startup.
#
# The `lint-opencode` recipe defers to the installed OpenCode, so the config
# checks skip when it is absent. The skip path itself is always exercised.

setup() {
    REPOSITORY_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_ROOT="$(mktemp -d)"
    command -v just > /dev/null || skip "just is not installed"
    cd "$REPOSITORY_ROOT" || return 1
}

teardown() {
    [[ -n "${TEST_ROOT:-}" ]] && rm -rf "$TEST_ROOT"
}

require_opencode() {
    if ! command -v opencode > /dev/null && [[ ! -x "${HOME}/.opencode/bin/opencode" ]]; then
        skip "opencode is not installed"
    fi
}

# Writes a copy of the tracked config with permission.KEY replaced, and prints
# the path.
config_with_permission() {
    local key="$1" value="$2" out="${TEST_ROOT}/candidate.json"
    python3 - "$key" "$value" "$out" <<'PY'
import json, pathlib, sys

key, value, out = sys.argv[1], sys.argv[2], sys.argv[3]
config = json.loads(pathlib.Path("llm/opencode/opencode.json").read_text())
config["permission"][key] = json.loads(value)
pathlib.Path(out).write_text(json.dumps(config, indent=2))
PY
    echo "$out"
}

@test "the tracked OpenCode config is accepted by the installed OpenCode" {
    require_opencode
    run just lint-opencode
    [[ "$status" -eq 0 ]]
}

@test "a webfetch pattern map is rejected" {
    require_opencode
    candidate="$(config_with_permission webfetch '{"*": "ask", "https://example.com*": "allow"}')"

    run just lint-opencode "$candidate"

    [[ "$status" -ne 0 ]]
    [[ "$output" == *"permission.webfetch"* ]]
}

@test "a bash pattern map is still accepted" {
    require_opencode
    candidate="$(config_with_permission bash '{"*": "ask", "ls *": "allow"}')"

    run just lint-opencode "$candidate"

    [[ "$status" -eq 0 ]]
}

@test "an unknown permission action is rejected" {
    require_opencode
    candidate="$(config_with_permission edit '"maybe"')"

    run just lint-opencode "$candidate"

    [[ "$status" -ne 0 ]]
}

@test "the lint skips instead of failing when OpenCode is absent" {
    mkdir -p "${TEST_ROOT}/home"
    # A bare PATH that still reaches just, bash and python3, but not the
    # OpenCode installed under ~/.opencode.
    just_dir="$(dirname "$(command -v just)")"
    run env -i PATH="${just_dir}:/usr/bin:/bin" HOME="${TEST_ROOT}/home" \
        just lint-opencode

    [[ "$status" -eq 0 ]]
    [[ "$output" == *"opencode not installed, skipping"* ]]
}
