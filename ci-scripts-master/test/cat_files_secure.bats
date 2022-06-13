#!/usr/bin/env bats

[ -n "$TRACE" ] && set -x

echo ${BATS_SOURCE}
source ${BATS_TEST_DIRNAME}/../lib/common.sh

TS_NAME=$(basename ${BATS_TEST_FILENAME})

# internal reused testing wrapper over cat_files_secure() function
function test_cat_files_secure() {
    expected_output=$1
    shift
    run cat_files_secure "$@"
    echo "status: $status"
    echo "output: '$output'"
    echo "expected_output: '$expected_output'"
    [ "$status" -eq 0 ]
    [ "$output" == "$expected_output" ]
}


@test "$TS_NAME: empty files" {
    test_cat_files_secure "" <(echo) <(echo)
}

@test "$TS_NAME: single lines" {
    test_cat_files_secure "$(echo -en 'a=1\nb=2')" <(echo a=1) <(echo b=2)
}

@test "$TS_NAME: single lines without newline" {
    test_cat_files_secure "$(echo -en 'a=1\nb=2')" <(echo -n a=1) <(echo -n b=2)
}
