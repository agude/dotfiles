#!/usr/bin/env bash
# Shared setup/teardown for Johnny Decimal bats tests.
#
# Sources jd-lib.sh with JD_ROOT pointing at a disposable temp tree.
# Every test gets a fresh tree via setup/teardown.

SCRIPT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../scripts" && pwd)"

# --- Fixture: minimal JD directory tree ---

create_jd_tree() {
    local root="$1"
    mkdir -p "$root/00-09 System/00 System/00.00 JDex for System"
    mkdir -p "$root/00-09 System/00 System/00.01 Inbox for System"
    mkdir -p "$root/10-19 Personal/11 Alex/11.50 Health and Wellness"
    mkdir -p "$root/10-19 Personal/11 Alex/11.70 Legal and Records"
    mkdir -p "$root/20-29 Finances/21 Banks/21.10 Alliant Credit Union"
    mkdir -p "$root/20-29 Finances/21 Banks/21.11 Wells Fargo"
    mkdir -p "$root/20-29 Finances/24 Taxes/24.10 Inbox for Tax"
    mkdir -p "$root/60-69 Hobbies and Recreation/61 Games/61.10 DnD"
    mkdir -p "$root/90-99 Reference/91 Library/91.10 Books"
    mkdir -p "$root/90-99 Reference/91 Library/91.10 Books/Bolos/covers"
}

setup() {
    TEST_TEMP="$(mktemp -d)"
    export JD_ROOT="$TEST_TEMP/Documents"
    create_jd_tree "$JD_ROOT"
    export JDEX_PATH="$JD_ROOT/00-09 System/00 System/00.00 JDex for System"
}

teardown() {
    rm -rf "$TEST_TEMP"
}

# --- Helpers ---

# Run a jd-* script by basename (e.g., run_script jd-list.sh 21)
run_script() {
    local name="$1"; shift
    run "$SCRIPT_DIR/$name" "$@"
}
