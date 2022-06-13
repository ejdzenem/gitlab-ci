#!/usr/bin/env bats

[ -n "$TRACE" ] && set -x

echo "${BATS_SOURCE}"
source "${BATS_TEST_DIRNAME}/../lib/common.sh"

TS_NAME="$(basename "${BATS_TEST_FILENAME}")"

function test_get_cargo_version() {
	[ "$(get_cargo_version "${BATS_TEST_DIRNAME}/test_files/$1")" == "$2" ]
}

@test "${TS_NAME}: valid - basic semver '1.2.3'" {
	test_get_cargo_version "Cargo-valid-semver.toml" "1.2.3"
}

@test "${TS_NAME}: valid - pre-release semver '1.2.3-alpha.beta'" {
	test_get_cargo_version "Cargo-valid-semver-prerelease.toml" "1.2.3-alpha.beta"
}

@test "${TS_NAME}: invalid - extra-space '1.2.3 '" {
	test_get_cargo_version "Cargo-invalid-extraspace.toml" ""
}
