#!/usr/bin/env bats

load test_helper

@test "read existing note" {
    echo "# 21.10 Alliant" > "$JDEX_PATH/21.10.md"
    echo "" >> "$JDEX_PATH/21.10.md"
    echo "Some content" >> "$JDEX_PATH/21.10.md"
    run_script jd-read.sh 21.10
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Some content"* ]]
}

@test "porcelain outputs file path" {
    echo "content" > "$JDEX_PATH/21.10.md"
    run_script jd-read.sh 21.10 --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$JDEX_PATH/21.10.md" ]]
}

@test "missing note warns but succeeds" {
    run_script jd-read.sh 21.10
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"No notes found"* ]]
}

@test "invalid ID fails" {
    run_script jd-read.sh "bad"
    [[ "$status" -ne 0 ]]
}
