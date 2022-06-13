#!/usr/bin/env bats

[ -n "$TRACE" ] && set -x

# test valid semantic versions
function test_semver() {
  input="$1"
  all="${2:-$input}"
  major="$3"
  minor="$4"
  patch="$5"
  args="$6"

  result="$(echo $input | ./lib/semver-cut.sh $6)"
  echo "none:  got '$result', expected: '$all'"
  [[ "$result" == "$all" ]]

  result="$(echo $input | ./lib/semver-cut.sh $6 all)"
  echo "all:   got '$result', expected: '$all'"
  [[ "$result" == "$all" ]]

  result="$(echo $input | ./lib/semver-cut.sh $6 full)"
  echo "full:  got '$result', expected: '$all'"
  [[ "$result" == "$all" ]]

  result="$(echo $input | ./lib/semver-cut.sh $6 major)"
  echo "major: got '$result', expected: '$major'"
  [[ "$result" == "$major" ]]

  result="$(echo $input | ./lib/semver-cut.sh $6 minor)"
  echo "minor: got '$result', expected: '$minor'"
  [[ "$result" == "$minor" ]]

  result="$(echo $input | ./lib/semver-cut.sh $6 patch)"
  echo "patch: got '$result', expected: '$patch'"
  [[ "$result" == "$patch" ]]
}

@test "valid version: 1.0.0" {
    test_semver "1.0.0" "" 1 1.0 1.0.0
}
@test "valid version: 0.9.2" {
    test_semver "0.9.2" "" 0 0.9 0.9.2
}
@test "valid version: 10.9.2" {
    test_semver "10.9.2" "" 10 10.9 10.9.2
}
@test "valid version: 10.9.20" {
    test_semver "10.9.20" "" 10 10.9 10.9.20
}
@test "valid version: 1.10.0" {
    test_semver "1.10.0" "" 1 1.10 1.10.0
}
@test "valid version: 1.101.0" {
    test_semver "1.101.0" "" 1 1.101 1.101.0
}
@test "valid version: 1.0.0-alpha" {
    test_semver "1.0.0-alpha" "" 1 1.0 1.0.0
}
@test "valid version: 1.0.0-alpha.1" {
    test_semver "1.0.0-alpha.1" "" 1 1.0 1.0.0
}
@test "valid version: 1.0.0-alpha1" {
    test_semver "1.0.0-alpha1" "" 1 1.0 1.0.0
}
@test "valid version: 1.0.0-1" {
    test_semver "1.0.0-1" "" 1 1.0 1.0.0
}
@test "valid version: 1.0.0-0.3.7" {
    test_semver "1.0.0-0.3.7" "" 1 1.0 1.0.0
}
@test "valid version: 1.0.0-x.7.z.92" {
    test_semver "1.0.0-x.7.z.92" "" 1 1.0 1.0.0
}
@test "valid version: 1.0.0-alpha+001" {
    test_semver "1.0.0-alpha+001" "" 1 1.0 1.0.0
}
@test "valid version: 1.0.0+2013031314470" {
    test_semver "1.0.0+2013031314470" "" 1 1.0 1.0.0
}
@test "valid version: 1.0.0-beta+exp.sha.5114f85" {
    test_semver "1.0.0-beta+exp.sha.5114f85" "" 1 1.0 1.0.0
}

# test invalid semantic versions
function test_semver_invalid() {
    run ./lib/semver-cut.sh <<< "$1"
    echo "got status '$status', expected '2'"
    [ "$status" -eq 2 ]
}

@test "invalid version: 1.0.0-" {
    test_semver_invalid "1.0.0-"
}
@test "invalid version: 1.0" {
    test_semver_invalid "1.0"
}
@test "invalid version: v1.0.0" {
    test_semver_invalid "v1.0.0"
}
@test "invalid version: 1.0." {
    test_semver_invalid "1.0."
}
@test "invalid version: 1.0.0-ab,d" {
    test_semver_invalid "1.0.0-ab,d"
}
@test "invalid version: 1.01.0" {
    test_semver_invalid "1.01.0"
}
@test "invalid version: 01.1.0" {
    test_semver_invalid "01.1.0"
}
@test "invalid version: 1.1.01" {
    test_semver_invalid "1.1.01"
}
@test "invalid version: 1.0.0-ab.d+" {
    test_semver_invalid "1.0.0-ab.d+"
}
@test "invalid version: 1.0.0-1." {
    test_semver_invalid "1.0.0-1."
}
@test "invalid version: 1.0.0~1" {
    test_semver_invalid "1.0.0~1"
}

# version prefix
@test "prefixed version: v1.0.0" {
    test_semver "v1.0.0" "1.0.0" 1 1.0 1.0.0 "--version-prefix=v"
}
@test "prefixed version: v1.0.0-v1" {
    test_semver "v1.0.0-v1" "1.0.0-v1" 1 1.0 1.0.0 "--version-prefix=v"
}
@test "prefixed version: partnerserver-1.0.0" {
    test_semver "partnerserver-1.0.0" "1.0.0" 1 1.0 1.0.0 "--version-prefix=partnerserver-"
}

# sorting
function test_sorting {
    version_newer="$1"
    version_older="$2"

    run bash -c "echo \"$version_newer
$version_older\" | ./lib/semver-cut.sh"
    echo "status code: got '$status'"
    [ "$status" -eq 0 ]
    echo "older version: got '${lines[0]}', expected '$version_older'"
    [ "${lines[0]}" == "$version_older" ]
    echo "newer version: got '${lines[1]}', expected '$version_newer'"
    [ "${lines[1]}" == "$version_newer" ]

    run bash -c "echo \"$version_older
$version_newer\" | ./lib/semver-cut.sh"
    echo "status code: got '$status'"
    [ "$status" -eq 0 ]
    echo "older version: got '${lines[0]}', expected '$version_older'"
    [ "${lines[0]}" == "$version_older" ]
    echo "newer version: got '${lines[1]}', expected '$version_newer'"
    [ "${lines[1]}" == "$version_newer" ]

}

@test "sort: 2.0.0 > 1.0.0" {
    test_sorting "2.0.0" "1.0.0"
}
@test "sort: 10.0.0 > 1.0.0" {
    test_sorting "2.0.0" "1.0.0"
}
@test "sort: 1.0.0 > 1.0.0-alpha" {
    test_sorting "1.0.0" "1.0.0-alpha"
}
@test "sort: 1.0.0 > 1.0.0+alpha" {
    test_sorting "1.0.0" "1.0.0+alpha"
}
@test "sort: complex1" {
    input="1.0.0-alpha
1.0.0-alpha.1
1.0.0-beta
1.0.0-beta.2
1.0.0-beta.11
1.0.0-rc.1
1.0.0"
    result=$(echo "$input" | ./lib/semver-cut.sh)
    echo "expected: '$input'"
    echo "got: '$result'"
    [ "$result" == "$input" ]
}
