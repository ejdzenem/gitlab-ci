#!/usr/bin/env bats

[ -n "$TRACE" ] && set -x

TS_NAME=$(basename ${BATS_TEST_FILENAME})
LIB_DIR=${BATS_TEST_DIRNAME}/../lib
LOCAL_REGISTRY="local-testing-registry:5000"
export CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY=${LOCAL_REGISTRY}

@test "${TS_NAME}: invalid use (no arguments)" {
    git checkout ${BATS_TEST_DIRNAME}/docker-mock-state.yaml
    source ${LIB_DIR}/common.sh
    run docker_image_copy
    [ "$status" == "1" ]
}

@test "${TS_NAME}: invalid use (invalid arguments - source docker image given only)" {
    source ${LIB_DIR}/common.sh
    run docker_image_copy docker.dev.dszn.cz/generic/ci-scripts:1
    [ "$status" == "1" ]
}

@test "${TS_NAME}: docker.dev.dszn.cz/sklik-devops/envoy:v1.6.5 -> ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.6.5 non-existing image" {
    export DOCKER_BIN="${BATS_TEST_DIRNAME}/docker-mock.py"
    source ${LIB_DIR}/common.sh
    run docker_image_copy docker.dev.dszn.cz/sklik-devops/envoy:v1.6.5 ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.6.5 sha256:non-existing
    [ "$status" == "2" ]
}

@test "${TS_NAME}: docker.dev.dszn.cz/sklik-devops/envoy:v1.7.0 -> ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0 invalid digest" {
    export DOCKER_BIN="${BATS_TEST_DIRNAME}/docker-mock.py"
    source ${LIB_DIR}/common.sh
    run docker_image_copy docker.dev.dszn.cz/sklik-devops/envoy:v1.7.0 ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0 ABC
    [ "$status" == "4" ]
}

@test "${TS_NAME}: docker.dev.dszn.cz/sklik-devops/envoy:v1.7.0 -> ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0 valid digest" {
    export DOCKER_BIN="${BATS_TEST_DIRNAME}/docker-mock.py"
    source ${LIB_DIR}/common.sh
    run docker_image_copy docker.dev.dszn.cz/sklik-devops/envoy:v1.7.0 ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0 sha256:e4ae8982a8a62496bc94b871dd8409cb7585e3e12b72dde1046c3d6973510c1a
    [ "$status" == "0" ]
}

@test "${TS_NAME}: docker.dev.dszn.cz/sklik-devops/envoy:v1.7.0 -> ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0 valid digest (identical image already there)" {
    export DOCKER_BIN="${BATS_TEST_DIRNAME}/docker-mock.py"
    source ${LIB_DIR}/common.sh
    run docker_image_copy docker.dev.dszn.cz/sklik-devops/envoy:v1.7.0 ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0 sha256:e4ae8982a8a62496bc94b871dd8409cb7585e3e12b72dde1046c3d6973510c1a
    [ "$status" == "0" ]
}

@test "${TS_NAME}: docker.dev.dszn.cz/sklik-devops/envoy:v1.6.8 -> ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0 valid digest (unable to overwrite)" {
    export DOCKER_BIN="${BATS_TEST_DIRNAME}/docker-mock.py"
    source ${LIB_DIR}/common.sh
    run docker_image_copy docker.dev.dszn.cz/sklik-devops/envoy:v1.6.8 ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0 sha256:e4ae8982a8a6249efefefef4556547374878655efefefffffaaaa89778867567
    [ "$status" == "5" ]
}

@test "${TS_NAME}: docker.dev.dszn.cz/sklik-devops/envoy:v1.6.8 -> ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0 valid digest (with overwrite)" {
    export DOCKER_BIN="${BATS_TEST_DIRNAME}/docker-mock.py"
    source ${LIB_DIR}/common.sh
    run docker_image_copy docker.dev.dszn.cz/sklik-devops/envoy:v1.6.8 ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0  sha256:e4ae8982a8a6249efefefef4556547374878655efefefffffaaaa89778867567 true
    [ "$status" == "0" ]
}

