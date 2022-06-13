#!/usr/bin/env bats

[ -n "$TRACE" ] && set -x

TS_NAME=$(basename ${BATS_TEST_FILENAME})
LIB_DIR=${BATS_TEST_DIRNAME}/../lib

@test "${TS_NAME}: requested help page (-h)" {
    run ${LIB_DIR}/production-docker-image-name.sh -h
    [ "$status" == "0" ]
    [[ "${lines[*]}" =~ Examples: ]]
}

@test "${TS_NAME}: requested help page (--help)" {
    run ${LIB_DIR}/production-docker-image-name.sh --help
    [ "$status" == "0" ]
    [[ "${lines[*]}" =~ Examples: ]]
}

@test "${TS_NAME}: invalid use (no arguments)" {
    run ${LIB_DIR}/production-docker-image-name.sh
    [ "$status" == "1" ]
}

@test "${TS_NAME}: invalid use (invalid argument)" {
    run ${LIB_DIR}/production-docker-image-name.sh ""
    [ "$status" == "1" ]
}

@test "${TS_NAME}: LEGACY-ENVIRONMENT: docker.dev to default production registry (by default rejected)" {
    run ${LIB_DIR}/production-docker-image-name.sh "docker.dev/generic/ci-scripts:1"
    [ "$status" == "0" ]
    [ ${lines[0]} == "docker.dev/generic/ci-scripts:1" ]
}

@test "${TS_NAME}: LEGACY-ENVIRONMENT: docker.dev to default production registry (forced)" {
    run ${LIB_DIR}/production-docker-image-name.sh "docker.dev/generic/ci-scripts:1" ".+"
    [ "$status" == "0" ]
    [ ${lines[0]} == "docker.ops.iszn.cz/generic/ci-scripts:1" ]
}

@test "${TS_NAME}: LEGACY-ENVIRONMENT: docker.dev to custom production registry (by default rejected)" {
    run ${LIB_DIR}/production-docker-image-name.sh "docker.dev/generic/ci-scripts:1" "" "my.prod.registry"
    [ "$status" == "0" ]
    [ ${lines[0]} == "docker.dev/generic/ci-scripts:1" ]
}

@test "${TS_NAME}: LEGACY-ENVIRONMENT: docker.dev to custom production registry (forced)" {
    run ${LIB_DIR}/production-docker-image-name.sh "docker.dev/generic/ci-scripts:1" ".+" "my.prod.registry"
    [ "$status" == "0" ]
    [ ${lines[0]} == "my.prod.registry/generic/ci-scripts:1" ]
}

setup() {
    unset CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY
    unset CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_NAMESPACE
    unset CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY
    unset CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_NAMESPACE
}

teardown() {
    setup
}

_setup_prod_ns() {
  export CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_NAMESPACE="$1"
  shift
}

@test "${TS_NAME}: SCIF-REGISTRY-ENVIRONMENT: cid.dev.dszn.cz to specific SCIF production registry (not matching so not translated)" {
    _setup_prod_ns generic
    run ${LIB_DIR}/production-docker-image-name.sh "cid.dev.dszn.cz/generic/ci-scripts:latest"
    [ "$status" == "0" ]
    [ ${lines[0]} == "cid.dev.dszn.cz/generic/ci-scripts:latest" ]
}

@test "${TS_NAME}: SCIF-REGISTRY-ENVIRONMENT: translate to different project in SCIF production registry (not nested, 1st level)" {
    _setup_prod_ns generic-prod
    run ${LIB_DIR}/production-docker-image-name.sh "docker.ops.iszn.cz/generic-dev/ci-scripts:latest"
    [ "$status" == "0" ]
    [ ${lines[0]} == "docker.ops.iszn.cz/generic-prod/ci-scripts:latest" ]
}

@test "${TS_NAME}: SCIF-REGISTRY-ENVIRONMENT: translate to different project in SCIF production registry (nested, 2nd level both)" {
    _setup_prod_ns generic-prod/subproject
    run ${LIB_DIR}/production-docker-image-name.sh "docker.ops.iszn.cz/generic-dev/subproject/ci-scripts:15.2.2_sem"
    [ "$status" == "0" ]
    [ ${lines[0]} == "docker.ops.iszn.cz/generic-prod/subproject/ci-scripts:15.2.2_sem" ]
}

@test "${TS_NAME}: SCIF-REGISTRY-ENVIRONMENT: translate to different project in SCIF production registry (nested, 2nd to 1st levels)" {
    _setup_prod_ns generic-prod
    run ${LIB_DIR}/production-docker-image-name.sh "docker.ops.iszn.cz/generic-dev/subproject/ci-scripts:7.7.8#dssfr(d)"
    [ "$status" == "0" ]
    [ ${lines[0]} == "docker.ops.iszn.cz/generic-prod/ci-scripts:7.7.8#dssfr(d)" ]
}

@test "${TS_NAME}: SCIF-REGISTRY-ENVIRONMENT: translate to same project in the same SCIF production registry" {
    _setup_prod_ns generic
    run ${LIB_DIR}/production-docker-image-name.sh "docker.ops.iszn.cz/generic/ci-scripts:1.4.5-rc1"
    [ "$status" == "0" ]
    [ ${lines[0]} == "docker.ops.iszn.cz/generic/ci-scripts:1.4.5-rc1" ]
}

@test "${TS_NAME}: example from helptext #2" {
    run ${LIB_DIR}/production-docker-image-name.sh docker.dev.dszn.cz/generic/ci-scripts:1.13.2 docker.dev
    [ "$status" == "0" ]
    [ ${lines[0]} == "docker.ops.iszn.cz/generic/ci-scripts:1.13.2" ]
}

@test "${TS_NAME}: example from helptext #3" {
    run ${LIB_DIR}/production-docker-image-name.sh docker.ops.iszn.cz/generic/ci-scripts:1.13.2 "" myproductionregistry
    [ "$status" == "0" ]
    [ ${lines[0]} == "myproductionregistry/generic/ci-scripts:1.13.2" ]
}
