#!/usr/bin/env bats

load test_helper

@test "tree shows areas" {
    run_script jd-tree.sh --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"00-09 System"* ]]
    [[ "$output" == *"20-29 Finances"* ]]
}

@test "tree with area query" {
    run_script jd-tree.sh 20 --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21 Banks"* ]]
}

@test "tree with category query" {
    run_script jd-tree.sh 21 -L2 --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21.10 Alliant"* ]]
}

@test "tree with ID query" {
    run_script jd-tree.sh 21.10 --porcelain
    [[ "$status" -eq 0 ]]
}

@test "invalid query fails" {
    run_script jd-tree.sh "not.valid.query"
    [[ "$status" -ne 0 ]]
}
