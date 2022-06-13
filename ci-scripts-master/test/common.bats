#!/usr/bin/env bats

[ -n "$TRACE" ] && set -x

TS_NAME=$(basename ${BATS_TEST_FILENAME})
common_sh_file="$BATS_TEST_DIRNAME/../lib/common.sh"


@test "${TS_NAME}: common.sh may be sourced with KUBECTL_BIN default" {
    run source "${common_sh_file}"
    [ "$status" -eq 0 ]
}

@test "${TS_NAME}: common.sh may be sourced with KUBECTL_BIN with no credentials" {
    export KUBECTL_BIN='/my/custom/path/kubectl --namespace XYZ'
    run source "${common_sh_file}"
    [ "$status" -eq 0 ]
}

@test "${TS_NAME}: common.sh cannot be sourced with kubectl credentials in KUBECTL_BIN (--token)" {
    export KUBECTL_BIN='/my/custom/path/kubectl --token XYZ'
    run source "${common_sh_file}"
    [ "$status" -eq 1 ]
}

@test "${TS_NAME}: common.sh cannot be sourced with kubectl credentials in KUBECTL_BIN (--password)" {
    export KUBECTL_BIN='/my/custom/path/kubectl --password XYZ'
    run source "${common_sh_file}"
    [ "$status" -eq 1 ]
}

@test "${TS_NAME}: common.sh cannot be sourced with kubectl credentials in KUBECTL_BIN (--token + --password)" {
    export KUBECTL_BIN='/my/custom/path/kubectl --password XYZ --token ZYX'
    run source "${common_sh_file}"
    [ "$status" -eq 1 ]
}
