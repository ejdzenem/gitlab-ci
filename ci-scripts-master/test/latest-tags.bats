#!/usr/bin/env bats
#

[ -n "$TRACE" ] && set -x

WARNING_MESSAGE="WARN: Releasing old version!"

function test_latest_tags {
    release_tags="$1"
    export VERSION="$2"
    expected_latest_tags="$3"
    expected_status=${4:-0}
    additional_args=${5:-""}

    export RELEASE_TAGS=$(echo "$release_tags" | tr " " "\n")

    run ./lib/latest-tags.sh "$additional_args"
    unset RELEASE_TAGS
    unset VERSION

    echo "got: $status, expected $expected_status"
    echo "output:          '$output'"
    echo "expected output: '$expected_latest_tags'"
    [ "$status" -eq "$expected_status" ]
    if [ "$status" -eq 0 ]; then
        # compare stdout only when we are interested in the output
        [ "$output" == "$expected_latest_tags" ]
    fi
}

@test "basic test on latest" {
    test_latest_tags "1.0.0 1.0.1 1.0.2" "1.0.2" "1,1.0,latest" 0 ""
}
@test "basic test on non-latest" {
    test_latest_tags "1.0.0 1.0.1 1.0.2" "1.0.1" "$WARNING_MESSAGE" 0 ""
}
@test "non existing tag" {
    test_latest_tags "1.0.0 1.0.1 1.0.2" "1.0.10" "" 1
}
@test "prefixed versions" {
    test_latest_tags "v1.0.0 v1.1.1 v1.2.2" "1.1.1" "1.1" 0 "v"
}
@test "pre-release release before regular release (-)" {
    test_latest_tags "1.2.0 1.3.0-alpha" "1.3.0-alpha" "" 0 ""
}
# this test-case simulates the situation when:
# * version comes from debian package and is pre-release (contains ~ char)
# * git repo tag is correctly semver (contains - char)
@test "pre-release release before regular release (~)" {
    test_latest_tags "1.2.0 1.3.0-alpha" "1.3.0~alpha" "" 0 ""
}
@test "pre-release release before regular release (+)" {
    test_latest_tags "1.2.0 1.3.0+alpha" "1.3.0+alpha" "" 0 ""
}
@test "pre-release release after regular release (-)" {
    test_latest_tags "1.2.0 1.3.0 1.3.0-alpha" "1.3.0-alpha" "" 0 ""
}
@test "pre-release release after regular release (+)" {
    test_latest_tags "1.2.0 1.3.0 1.3.0-alpha" "1.3.0-alpha" "" 0 ""
}
