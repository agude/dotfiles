#!/usr/bin/env bats

load test_helper

@test "inbox single file" {
    touch "$TEST_TEMP/doc.pdf"
    run_script jd-inbox.sh "$TEST_TEMP/doc.pdf" --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"00.01 Inbox for System/doc.pdf" ]]
    [[ -f "$JD_ROOT/00-09 System/00 System/00.01 Inbox for System/doc.pdf" ]]
    [[ ! -e "$TEST_TEMP/doc.pdf" ]]
}

@test "inbox multiple files" {
    touch "$TEST_TEMP/a.pdf" "$TEST_TEMP/b.pdf"
    run_script jd-inbox.sh "$TEST_TEMP/a.pdf" "$TEST_TEMP/b.pdf" --porcelain
    [[ "$status" -eq 0 ]]
    local dest="$JD_ROOT/00-09 System/00 System/00.01 Inbox for System"
    [[ -f "$dest/a.pdf" ]]
    [[ -f "$dest/b.pdf" ]]
}

@test "inbox with --force overwrites" {
    echo "new" > "$TEST_TEMP/doc.pdf"
    echo "old" > "$JD_ROOT/00-09 System/00 System/00.01 Inbox for System/doc.pdf"
    run_script jd-inbox.sh --force "$TEST_TEMP/doc.pdf" --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$(cat "$JD_ROOT/00-09 System/00 System/00.01 Inbox for System/doc.pdf")" == "new" ]]
}

@test "inbox dry-run does not move" {
    touch "$TEST_TEMP/doc.pdf"
    run_script jd-inbox.sh --dry-run "$TEST_TEMP/doc.pdf"
    [[ "$status" -eq 0 ]]
    [[ -f "$TEST_TEMP/doc.pdf" ]]
    [[ "$output" == *"Would move"* ]]
}

@test "inbox no args shows usage" {
    run_script jd-inbox.sh
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Usage"* ]]
}

@test "inbox missing source fails" {
    run_script jd-inbox.sh "$TEST_TEMP/nope.pdf"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"not found"* ]]
}
