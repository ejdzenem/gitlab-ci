#!/usr/bin/env bats

[ -n "$TRACE" ] && set -x

echo ${BATS_SOURCE}
source ${BATS_TEST_DIRNAME}/../lib/common.sh

TS_NAME=$(basename ${BATS_TEST_FILENAME})

function test_get_version_from_changelog_md() {
	[ `get_version_from_changelog_md "${BATS_TEST_DIRNAME}/test_files/$1"` == $2 ]
}

@test "${TS_NAME}: nice version ## [1.2.3]" {
	test_get_version_from_changelog_md "changelog-md_good-version1.md" "1.2.3"
}

@test "${TS_NAME}: version with spaces ##       [   11.22.33   ]" {
	test_get_version_from_changelog_md "changelog-md_good-version2.md" "11.22.33"
}

@test "${TS_NAME}: bad version with spaces ## [1. 2.3  ]" {
	test_get_version_from_changelog_md "changelog-md_bad-version1.md" "4.5.6"
}

@test "${TS_NAME}: [Unreleased] exists only on the top of changelog, otherwise turns exit code 1" {
    run get_version_from_changelog_md "${BATS_TEST_DIRNAME}/test_files/changelog-md_unreleased2.md"
    [ "$status" -eq 1 ]
}

@test "${TS_NAME}: Text between [Unreleased] and [Version.tag] returns exit code 1" {
    run get_version_from_changelog_md "${BATS_TEST_DIRNAME}/test_files/changelog-md_unreleased1.md"
    [ "$status" -eq 1 ]
}
