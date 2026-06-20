#!/usr/bin/env bats

load test_helper

@test "create new note file" {
    run_script jd-note.sh 21.10 "Opened savings account" --porcelain
    [[ "$status" -eq 0 ]]
    [[ -f "$JDEX_PATH/21.10.md" ]]
    grep -q "Opened savings account" "$JDEX_PATH/21.10.md"
    grep -q "# 21.10 Alliant Credit Union" "$JDEX_PATH/21.10.md"
}

@test "append to existing note" {
    run_script jd-note.sh 21.10 "First note" --porcelain
    run_script jd-note.sh 21.10 "Second note" --porcelain
    [[ "$status" -eq 0 ]]
    grep -q "First note" "$JDEX_PATH/21.10.md"
    grep -q "Second note" "$JDEX_PATH/21.10.md"
}

@test "date header added" {
    run_script jd-note.sh 21.10 "Test" --porcelain
    today=$(date +%Y-%m-%d)
    grep -q "## ${today}" "$JDEX_PATH/21.10.md"
}

@test "invalid ID fails" {
    run_script jd-note.sh "bad" "text"
    [[ "$status" -ne 0 ]]
}

@test "no text in non-interactive mode fails" {
    run_script jd-note.sh 21.10
    [[ "$status" -ne 0 ]]
}
