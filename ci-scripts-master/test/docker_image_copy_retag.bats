#!/usr/bin/env bats

[ -n "$TRACE" ] && set -x

TS_NAME=$(basename ${BATS_TEST_FILENAME})
LIB_DIR=${BATS_TEST_DIRNAME}/../lib
DOCKER_REGISTRY_REPOSITORY=docker.ops.iszn.cz/sklik-devops-dev/ci-scripts-test
DOCKER_REGISTRY_PREV_TAG=0.0.41
DOCKER_REGISTRY_CURR_TAG=0.0.42
DOCKER_REGISTRY_PREV_IMAGE_DIGEST=sha256:72eb6732ceea9e2c6a060ea7a6875cfce0d166f0452dfc7ffc5389122bdb01ee
DOCKER_REGISTRY_CURR_IMAGE_DIGEST=sha256:1bccdc11361de58656803665efe42808a5f97a1f39f0dbd367b79ef25dc1ae94
[ -s "${BATS_TEST_DIRNAME}/${TS_NAME}.push_tag.txt" ] || echo -n "0.0.42_$(date +%Y%m%d_%H%M%S)" > "${BATS_TEST_DIRNAME}/${TS_NAME}.push_tag.txt"
DOCKER_REGISTRY_PUSH_TAG="$(head -1 "${BATS_TEST_DIRNAME}/${TS_NAME}.push_tag.txt")"

CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY=$(echo "${DOCKER_REGISTRY_REPOSITORY}" | awk -F/ '{printf $1}')
CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_NAMESPACE=$(echo ${DOCKER_REGISTRY_REPOSITORY} | sed -r 's#[^/]+/##')
CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY=${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY}
CI_SCRIPTS_PRODUCTION_DOCKER_NAMESPACE=${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_NAMESPACE}
CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_USER="${CI_SCRIPTS_DOCKER_REGISTRY_TEST_USER}"
CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_USER="${CI_SCRIPTS_DOCKER_REGISTRY_TEST_USER}"
CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_PASSWORD_FILE="${CI_SCRIPTS_DOCKER_REGISTRY_TEST_PASSWORD_FILE}"
CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_PASSWORD_FILE="${CI_SCRIPTS_DOCKER_REGISTRY_TEST_PASSWORD_FILE}"

@test "${TS_NAME}: invalid use (no arguments)" {
    source ${LIB_DIR}/common.sh
    run docker_image_copy_retag
    [ "$status" == "1" ]
}

@test "${TS_NAME}: invalid use (invalid arguments - source docker image given only)" {
    source ${LIB_DIR}/common.sh
    run docker_image_copy_retag ${DOCKER_REGISTRY_REPOSITORY}:latest
    [ "$status" == "1" ]
}

# Support for v2 harbor API is yet to be added:
# https://youtrack.seznam.net/issue/DOSERE-165
# 
# @test "${TS_NAME}: ${DOCKER_REGISTRY_REPOSITORY}:non-existing-tag -> ${DOCKER_REGISTRY_REPOSITORY}:X non-existing image" {
#     source ${LIB_DIR}/common.sh
#     run docker_image_copy_retag ${DOCKER_REGISTRY_REPOSITORY}:non-existing-tag ${DOCKER_REGISTRY_REPOSITORY}:X sha256:non-existing
#     [ "$status" == "3" ]
# }

# @test "${TS_NAME}: ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_CURR_TAG} -> ${DOCKER_REGISTRY_REPOSITORY}:X invalid digest" {
#     source ${LIB_DIR}/common.sh
#     run docker_image_copy_retag ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_CURR_TAG} ${DOCKER_REGISTRY_REPOSITORY}:X ABC
#     [ "$status" == "4" ]
# }

# @test "${TS_NAME}: ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_CURR_TAG} -> ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_PUSH_TAG} valid digest" {
#     source ${LIB_DIR}/common.sh
#     run docker_image_copy_retag ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_CURR_TAG} ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_PUSH_TAG} ${DOCKER_REGISTRY_CURR_IMAGE_DIGEST}
#     [ "$status" == "0" ]
# }

# @test "${TS_NAME}: ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_CURR_TAG} -> ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_PUSH_TAG} valid digest (identical image already there)" {
#     source ${LIB_DIR}/common.sh
#     run docker_image_copy_retag ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_CURR_TAG} ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_PUSH_TAG} ${DOCKER_REGISTRY_CURR_IMAGE_DIGEST}
#     [ "$status" == "0" ]
# }


# @test "${TS_NAME}: ${DOCKER_REGISTRY_REPOSITORY}:0.0.41 -> ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_PUSH_TAG} valid digest (unable to overwrite)" {
#     source ${LIB_DIR}/common.sh
#     run docker_image_copy_retag ${DOCKER_REGISTRY_REPOSITORY}:0.0.41 ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_PUSH_TAG} ${DOCKER_REGISTRY_PREV_IMAGE_DIGEST}
#     [ "$status" == "5" ]
# }


# @test "${TS_NAME}: ${DOCKER_REGISTRY_REPOSITORY}:0.0.41 -> ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_PUSH_TAG} valid digest (with overwrite)" {
#     source ${LIB_DIR}/common.sh
#     run docker_image_copy_retag ${DOCKER_REGISTRY_REPOSITORY}:0.0.41 ${DOCKER_REGISTRY_REPOSITORY}:${DOCKER_REGISTRY_PUSH_TAG} ${DOCKER_REGISTRY_PREV_IMAGE_DIGEST} true
#     [ "$status" == "0" ]
# }

