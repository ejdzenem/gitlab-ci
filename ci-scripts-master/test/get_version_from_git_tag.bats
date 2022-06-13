#!/usr/bin/env bats

[ -n "$TRACE" ] && set -x

echo "${BATS_SOURCE}"
source "${BATS_TEST_DIRNAME}/../lib/common.sh"

TS_NAME="$(basename "${BATS_TEST_FILENAME}")"

function test_get_version_from_git_tag() {
	[ "$(get_version_from_git_tag)" == "$1" ]
}

@test "${TS_NAME}: valid - basic semver tag '11.22.33'" {
    CI_COMMIT_TAG="11.22.33"
	test_get_version_from_git_tag "11.22.33"
}

@test "${TS_NAME}: valid - basic semver tag with prefix 'component-name-11.22.33'" {
    CI_COMMIT_TAG="component-name-11.22.33"
	test_get_version_from_git_tag "11.22.33"
}

@test "${TS_NAME}: valid - version with `v` prefix 'component-name-v1.2.3'" {
    CI_COMMIT_TAG="component-name-v11.22.33"
	test_get_version_from_git_tag "11.22.33"
}

@test "${TS_NAME}: valid - component name with number 'component1-name1-11.22.33'" {
    CI_COMMIT_TAG="component1-name1-11.22.33"
	test_get_version_from_git_tag "11.22.33"
}

@test "${TS_NAME}: valid - version with postfix 'component-name-11.22.33-flag'" {
    CI_COMMIT_TAG="component-name-11.22.33-flag"
	test_get_version_from_git_tag "11.22.33-flag"
}

@test "${TS_NAME}: valid - version with numeric postfix 'component-name-11.22.33-1'" {
    CI_COMMIT_TAG="component-name-11.22.33-1"
	test_get_version_from_git_tag "11.22.33-1"
}

@test "${TS_NAME}: valid - version with tylda postfix 'component-name-11.22.33~flag'" {
    CI_COMMIT_TAG="component-name-11.22.33~flag"
	test_get_version_from_git_tag "11.22.33~flag"
}

@test "${TS_NAME}: valid - version with uppercase 'COMPONENT-NAME-11.22.33'" {
    CI_COMMIT_TAG="COMPONENT-NAME-11.22.33"
	test_get_version_from_git_tag "11.22.33"
}

@test "${TS_NAME}: invalid - not semver tag 'component-name'" {
    CI_COMMIT_TAG="component-name"
	test_get_version_from_git_tag ""
}
