#!/usr/bin/env bats

[ -n "$TRACE" ] && set -x

echo "$BATS_SOURCE"
source "$BATS_TEST_DIRNAME/../lib/common.sh"

TS_NAME="$(basename "$BATS_TEST_FILENAME")"

function setup() {
    TEST_DIR="$(mktemp -d "$BATS_TMPDIR/split_yaml_XXXXXX")"
}

function teardown() {
    rm -rf "$TEST_DIR"
}

# internal reused testing wrapper over split_yaml() function
function test_split_yaml() {
    cp "$1" "$TEST_DIR/test.yaml"
    run split_yaml "$TEST_DIR/test.yaml"
    echo "status: $status"
    [ "$status" -eq 0 ]
}

# checks if TEST_DIR contains only expected number of files
function check_file_count() {
    [ "$(ls "$TEST_DIR"/* | wc -l)" -eq "$1" ]
}

# checks if the actual output file exists and if its contents match the expected value
function check_content() {
    actual_file="$1"
    expected_file="$2"
    [ "$(md5sum < "$actual_file")" = "$(md5sum < "$expected_file")" ]
    [ -f "$actual_file" ]
}

@test "$TS_NAME: empty file" {
    test_split_yaml <(echo)
    check_file_count 1
    check_content "$TEST_DIR/test.yaml" <(echo)
}

@test "$TS_NAME: singledoc yaml" {
    test_split_yaml test/test_files/kubernetes_deployment.yaml
    check_file_count 1
    check_content "$TEST_DIR/test.yaml" test/test_files/kubernetes_deployment.yaml
}

@test "$TS_NAME: multidoc yaml" {
    test_split_yaml test/test_files/split_yaml_test.yaml
    check_file_count 5
    check_content "$TEST_DIR/test.yaml.orig" test/test_files/split_yaml_test.yaml
    check_content "$TEST_DIR/test-00.yaml" <(sed -n '1,10p' test/test_files/split_yaml_test.yaml)
    check_content "$TEST_DIR/test-01.yaml" <(sed -n '12,21p' test/test_files/split_yaml_test.yaml)
    check_content "$TEST_DIR/test-02.yaml" <(sed -n '23,32p' test/test_files/split_yaml_test.yaml)
    check_content "$TEST_DIR/test-03.yaml" <(sed -n '34,43p' test/test_files/split_yaml_test.yaml)
}

