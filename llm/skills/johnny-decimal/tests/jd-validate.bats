#!/usr/bin/env bats

load test_helper

@test "clean filename passes" {
    run_script jd-validate.sh "20241227_statement.pdf"
    [[ "$status" -eq 0 ]]
}

@test "spaces trigger warning" {
    run_script jd-validate.sh "my document.pdf"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"spaces"* ]]
}

@test "transient file without date warns" {
    run_script jd-validate.sh "statement.pdf"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"date"* ]]
}

@test "special characters fail" {
    run_script jd-validate.sh 'file$name.pdf'
    [[ "$status" -ne 0 ]]
}

@test "porcelain OK output" {
    run_script jd-validate.sh "clean_file.pdf" --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == "OK:clean_file.pdf" ]]
}

@test "multiple files validated" {
    run_script jd-validate.sh "good.pdf" "also_good.pdf" --porcelain
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"OK:good.pdf"* ]]
    [[ "$output" == *"OK:also_good.pdf"* ]]
}
