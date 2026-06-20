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
