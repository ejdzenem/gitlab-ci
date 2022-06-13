#!/usr/bin/env bats

[ -n "$TRACE" ] && set -x

TS_NAME=$(basename ${BATS_TEST_FILENAME})
LIB_DIR=${BATS_TEST_DIRNAME}/../lib
LOCAL_REGISTRY="local-testing-registry:5000"
export CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY=${LOCAL_REGISTRY}

@test "${TS_NAME}: requested help page (-h)" {
    git checkout ${BATS_TEST_DIRNAME}/docker-mock-state.yaml
    run ${LIB_DIR}/docker-release-to-production-registry.sh -h
    [ "$status" == "0" ]
    [[ "${lines[*]}" =~ Execution.examples ]]
}

@test "${TS_NAME}: requested help page (--help)" {
    run ${LIB_DIR}/docker-release-to-production-registry.sh --help
    [ "$status" == "0" ]
    [[ "${lines[*]}" =~ Execution.examples ]]
}

@test "${TS_NAME}: invalid use (no arguments)" {
    run ${LIB_DIR}/docker-release-to-production-registry.sh
    [ "$status" == "1" ]
}

@test "${TS_NAME}: invalid use (invalid arguments - source docker image given only)" {
    run ${LIB_DIR}/docker-release-to-production-registry.sh --docker-image-name docker.dev.dszn.cz/generic/ci-scripts:1
    [ "$status" == "2" ]
}

@test "${TS_NAME}: invalid use (source and destination is the same image)" {
    export DOCKER_BIN="${BATS_TEST_DIRNAME}/docker-mock.py"
    image=docker.dev.dszn.cz/sklik-devops/envoy:v1.7.0
    run ${LIB_DIR}/docker-release-to-production-registry.sh --docker-image-name $image \
                                                            --docker-image-digest sha256:e4ae8982a8a62496bc94b871dd8409cb7585e3e12b72dde1046c3d6973510c1a \
                                                            --destination-docker-image-name $image \
    [ "$status" == "5" ]
}

@test "${TS_NAME}: docker.dev.dszn.cz/sklik-devops/envoy:v1.6.5 -> ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.6.5 non-existing image" {
    export DOCKER_BIN="${BATS_TEST_DIRNAME}/docker-mock.py"
    run ${LIB_DIR}/docker-release-to-production-registry.sh --docker-image-name docker.dev.dszn.cz/sklik-devops/envoy:v1.6.5 \
                                                            --docker-image-digest sha256:non-existing \
                                                            --destination-docker-image-name ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.6.5
    [ "$status" == "4" ]
}

@test "${TS_NAME}: docker.dev.dszn.cz/sklik-devops/envoy:v1.7.0 -> ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0 invalid digest" {
    export DOCKER_BIN="${BATS_TEST_DIRNAME}/docker-mock.py"
    run ${LIB_DIR}/docker-release-to-production-registry.sh --docker-image-name docker.dev.dszn.cz/sklik-devops/envoy:v1.7.0 \
                                                            --docker-image-digest ABC \
                                                            --destination-docker-image-name ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0
    [ "$status" == "4" ]
}

@test "${TS_NAME}: docker.dev.dszn.cz/sklik-devops/envoy:v1.7.0 -> ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0 valid digest" {
    export DOCKER_BIN="${BATS_TEST_DIRNAME}/docker-mock.py"
    run ${LIB_DIR}/docker-release-to-production-registry.sh --docker-image-name docker.dev.dszn.cz/sklik-devops/envoy:v1.7.0 \
                                                            --docker-image-digest sha256:e4ae8982a8a62496bc94b871dd8409cb7585e3e12b72dde1046c3d6973510c1a \
                                                            --destination-docker-image-name ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0
    [ "$status" == "0" ]
}

@test "${TS_NAME}: docker.dev.dszn.cz/sklik-devops/envoy:v1.7.0 -> ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0 valid digest (identical image already there)" {
    export DOCKER_BIN="${BATS_TEST_DIRNAME}/docker-mock.py"
    run ${LIB_DIR}/docker-release-to-production-registry.sh --docker-image-name docker.dev.dszn.cz/sklik-devops/envoy:v1.7.0 \
                                                            --docker-image-digest sha256:e4ae8982a8a62496bc94b871dd8409cb7585e3e12b72dde1046c3d6973510c1a \
                                                            --destination-docker-image-name ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0
    [ "$status" == "0" ]
}

@test "${TS_NAME}: docker.dev.dszn.cz/sklik-devops/envoy:v1.6.8 -> ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0 valid digest (unable to overwrite)" {
    export DOCKER_BIN="${BATS_TEST_DIRNAME}/docker-mock.py"
    run ${LIB_DIR}/docker-release-to-production-registry.sh --docker-image-name docker.dev.dszn.cz/sklik-devops/envoy:v1.6.8 \
                                                            --docker-image-digest sha256:e4ae8982a8a6249efefefef4556547374878655efefefffffaaaa89778867567 \
                                                            --destination-docker-image-name ${LOCAL_REGISTRY}/sklik-devops/envoy:v1.7.0
    [ "$status" == "4" ]
}


