#!/usr/bin/env bats

load test_helper

@test "move single file" {
    touch "$TEST_TEMP/doc.pdf"
    run_script jd-move.sh "$TEST_TEMP/doc.pdf" 21.10 --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21.10 Alliant Credit Union/doc.pdf" ]]
    [[ -f "$JD_ROOT/20-29 Finances/21 Banks/21.10 Alliant Credit Union/doc.pdf" ]]
    [[ ! -e "$TEST_TEMP/doc.pdf" ]]
}

@test "move multiple files (glob)" {
    touch "$TEST_TEMP/a.pdf" "$TEST_TEMP/b.pdf" "$TEST_TEMP/c.pdf"
    run_script jd-move.sh "$TEST_TEMP/a.pdf" "$TEST_TEMP/b.pdf" "$TEST_TEMP/c.pdf" 00.01 --porcelain
    [[ "$status" -eq 0 ]]
    local dest="$JD_ROOT/00-09 System/00 System/00.01 Inbox for System"
    [[ -f "$dest/a.pdf" ]]
    [[ -f "$dest/b.pdf" ]]
    [[ -f "$dest/c.pdf" ]]
}

@test "move with --name renames" {
    touch "$TEST_TEMP/scan.pdf"
    run_script jd-move.sh "$TEST_TEMP/scan.pdf" 21.10 --name statement.pdf --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"statement.pdf" ]]
    [[ -f "$JD_ROOT/20-29 Finances/21 Banks/21.10 Alliant Credit Union/statement.pdf" ]]
}

@test "--name with multiple sources fails" {
    touch "$TEST_TEMP/a.pdf" "$TEST_TEMP/b.pdf"
    run_script jd-move.sh "$TEST_TEMP/a.pdf" "$TEST_TEMP/b.pdf" 21.10 --name foo.pdf
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"single source"* ]]
}

@test "move into --subdir" {
    touch "$TEST_TEMP/cover.jpg"
    run_script jd-move.sh "$TEST_TEMP/cover.jpg" 91.10 --subdir Bolos/covers --porcelain
    [[ "$status" -eq 0 ]]
    [[ -f "$JD_ROOT/90-99 Reference/91 Library/91.10 Books/Bolos/covers/cover.jpg" ]]
}

@test "refuses to overwrite without --force" {
    touch "$TEST_TEMP/doc.pdf"
    touch "$JD_ROOT/20-29 Finances/21 Banks/21.10 Alliant Credit Union/doc.pdf"
    run_script jd-move.sh "$TEST_TEMP/doc.pdf" 21.10
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"already exists"* ]]
}

@test "overwrites with --force" {
    echo "new" > "$TEST_TEMP/doc.pdf"
    echo "old" > "$JD_ROOT/20-29 Finances/21 Banks/21.10 Alliant Credit Union/doc.pdf"
    run_script jd-move.sh --force "$TEST_TEMP/doc.pdf" 21.10 --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$(cat "$JD_ROOT/20-29 Finances/21 Banks/21.10 Alliant Credit Union/doc.pdf")" == "new" ]]
}

@test "dry-run does not move" {
    touch "$TEST_TEMP/doc.pdf"
    run_script jd-move.sh --dry-run "$TEST_TEMP/doc.pdf" 21.10
    [[ "$status" -eq 0 ]]
    [[ -f "$TEST_TEMP/doc.pdf" ]]
    [[ "$output" == *"Would move"* ]]
}

@test "missing source fails" {
    run_script jd-move.sh "$TEST_TEMP/nope.pdf" 21.10
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"not found"* ]]
}

@test "invalid ID fails" {
    touch "$TEST_TEMP/doc.pdf"
    run_script jd-move.sh "$TEST_TEMP/doc.pdf" "bad"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Invalid ID"* ]]
}
