#!/usr/bin/env bats

load test_helper

@test "list areas (no args, porcelain)" {
    run_script jd-list.sh --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"00-09 System"* ]]
    [[ "$output" == *"20-29 Finances"* ]]
    [[ "$output" == *"90-99 Reference"* ]]
}

@test "list categories in area" {
    run_script jd-list.sh 20 --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21 Banks"* ]]
    [[ "$output" == *"24 Taxes"* ]]
}

@test "list subcategories in category" {
    run_script jd-list.sh 21 --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21.10 Alliant"* ]]
    [[ "$output" == *"21.11 Wells Fargo"* ]]
}

@test "list files in ID" {
    touch "$JD_ROOT/20-29 Finances/21 Banks/21.10 Alliant Credit Union/statement.pdf"
    run_script jd-list.sh 21.10 --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21.10 Alliant Credit Union"* ]]
}

@test "invalid query fails" {
    run_script jd-list.sh "not-valid"
    [[ "$status" -ne 0 ]]
}
