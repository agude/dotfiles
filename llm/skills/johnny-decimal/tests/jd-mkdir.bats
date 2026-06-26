#!/usr/bin/env bats

load test_helper

@test "create subcategory with auto ID" {
    run_script jd-mkdir.sh 21 "Chase Bank" --porcelain
    [[ "$status" -eq 0 ]]
    # 21.10 and 21.11 exist, so next is 21.12
    [[ "$output" == *"21.12 Chase Bank" ]]
    [[ -d "$JD_ROOT/20-29 Finances/21 Banks/21.12 Chase Bank" ]]
}

@test "create subcategory with explicit --id" {
    run_script jd-mkdir.sh 21 "Chase Bank" --id 20 --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21.20 Chase Bank" ]]
    [[ -d "$JD_ROOT/20-29 Finances/21 Banks/21.20 Chase Bank" ]]
}

@test "refuses duplicate folder" {
    run_script jd-mkdir.sh 21 "Alliant Credit Union" --id 10
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"already exists"* ]]
}

@test "dry-run does not create" {
    run_script jd-mkdir.sh 21 "Chase Bank" --dry-run --porcelain
    [[ "$status" -eq 0 ]]
    [[ ! -d "$JD_ROOT/20-29 Finances/21 Banks/21.12 Chase Bank" ]]
}

@test "invalid category format fails" {
    run_script jd-mkdir.sh 2 "Bad"
    [[ "$status" -ne 0 ]]
}

@test "create subdirectory inside existing ID" {
    run_script jd-mkdir.sh 21.10 "statements" --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21.10 Alliant Credit Union/statements" ]]
    [[ -d "$JD_ROOT/20-29 Finances/21 Banks/21.10 Alliant Credit Union/statements" ]]
}

@test "refuses duplicate subdirectory inside ID" {
    mkdir "$JD_ROOT/20-29 Finances/21 Banks/21.10 Alliant Credit Union/statements"
    run_script jd-mkdir.sh 21.10 "statements"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"already exists"* ]]
}

@test "subdir inside ID rejects --id flag" {
    run_script jd-mkdir.sh 21.10 "statements" --id 5
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"not supported"* ]]
}

@test "subdir inside nonexistent ID fails" {
    run_script jd-mkdir.sh 21.99 "statements"
    [[ "$status" -ne 0 ]]
}

@test "dry-run with subdir inside ID does not create" {
    run_script jd-mkdir.sh 21.10 "statements" --dry-run --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21.10 Alliant Credit Union/statements" ]]
    [[ ! -d "$JD_ROOT/20-29 Finances/21 Banks/21.10 Alliant Credit Union/statements" ]]
}

@test "subdir name containing slash is rejected" {
    run_script jd-mkdir.sh 21.10 "a/b"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Invalid name"* ]]
}

@test "subdir name dot is rejected" {
    run_script jd-mkdir.sh 21.10 "."
    [[ "$status" -ne 0 ]]
}

@test "subdir name dotdot is rejected" {
    run_script jd-mkdir.sh 21.10 ".."
    [[ "$status" -ne 0 ]]
}
