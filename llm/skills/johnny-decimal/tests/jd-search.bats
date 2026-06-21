#!/usr/bin/env bats

load test_helper

@test "search by name" {
    run_script jd-search.sh bank --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21 Banks"* ]]
}

@test "search by name is case-insensitive" {
    run_script jd-search.sh BANK --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21 Banks"* ]]
}

@test "search by ID fragment" {
    run_script jd-search.sh 21.1 --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21.10 Alliant Credit Union"* ]]
    [[ "$output" == *"21.11 Wells Fargo"* ]]
}

@test "search by exact ID" {
    run_script jd-search.sh 21.10 --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21.10 Alliant Credit Union"* ]]
}

@test "search by category" {
    run_script jd-search.sh "21 " --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"21 Banks"* ]]
}

@test "search by area" {
    run_script jd-search.sh 20- --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"20-29 Finances"* ]]
}

@test "porcelain outputs full paths" {
    run_script jd-search.sh 21.10 --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == "$JD_ROOT/20-29 Finances/21 Banks/21.10 Alliant Credit Union" ]]
}

@test "no matches exits 1" {
    run_script jd-search.sh zzzznothing
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"No matches"* ]]
}

@test "no args shows usage" {
    run_script jd-search.sh
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Usage"* ]]
}
