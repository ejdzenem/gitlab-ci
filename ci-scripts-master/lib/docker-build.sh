#!/bin/bash
#
# docker-build.sh [OPTIONS] [-- DOCKER_BUILD_ARGS]
#
# Build docker image. Image name is one of the following form:
#   * $DOCKER_IMAGE_NAME if --docker-image-name is present
#   * $CI_SCRIPTS_DOCKER_CI_REGISTRY/$NAMESPACE/$COMPONENT:${VERSION}_${GIT_REV}_${CI_PIPELINE} for Gitlab CI
#   * $CI_SCRIPTS_DOCKER_CI_REGISTRY/$NAMESPACE/$COMPONENT:${VERSION}_${GIT_REV}_`hostname` for local builds
#
# Possible OPTIONS are:
#   -h|--help                         Show this message and exists
#   -c|--component         COMPONENT  Redefine component name (of docker image registry/namespace/component:tag)
#   -n|--namespace         NAMESPACE  Redefine namespace name (of docker image registry/namespace/component:tag)
#   -d|--docker-image-name NAME       Redefine whole docker image name
#
# Examples:
#   ## Typical usage:
#   $ docker-build.sh --namespace foo --component bar
#   ## Use a Dockerfile from a different directory (pass arguments through to docker build):
#   $ docker-build.sh --namespace foo --component bar -- -f baz/Dockerfile

set -eo pipefail

[ -n "$TRACE" ] && set -x

self=$(readlink -f $0)
dir=$(dirname $self)

# initialize global variables
COMPONENT=
DOCKER_IMAGE_NAME=

source $dir/common.sh

pargs=$(getopt -o "h,c:,d:,b:,n:" -l "help,component:,docker-build-args:,docker-image-name:,namespace:" -n "$0" -- "$@")
eval set -- "$pargs"
while true; do
  case "$1" in
    -h|--help)
        help_display $self
        exit 0
        ;;
    -n|--namespace)
        CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_NAMESPACE="$2"
        shift 2
        ;;
    -c|--component)
        COMPONENT="$2"
        shift 2
        ;;
    -d|--docker-image-name)
        DOCKER_IMAGE_NAME="$2"
        shift 2
        ;;
    --)
        shift
        break
        ;;
    *)
        myexit --help 1 "Not implemented: $1"
        ;;
  esac
done

if [ -z "${DOCKER_IMAGE_NAME}" ]; then
    COMPONENT=${COMPONENT:-$(get_component)}
fi

if [ -n "$COMPONENT" -a -n "$DOCKER_IMAGE_NAME" ]; then
    myexit --help 2 "Both COMPONENT and DOCKER_IMAGE_NAME cannot be defined at once!"
elif [ -z "$COMPONENT" -a -z "$DOCKER_IMAGE_NAME" ]; then
    myexit --help 2 "One of COMPONENT and DOCKER_IMAGE_NAME name must be defined"
fi

DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME:-$(get_ci_docker_image_name)}

ensure_docker_env

if in_ci; then
    BUILD_TYPE="automated"
else
    BUILD_TYPE="manual"
fi

docker_build_command=("${DOCKER_BIN:-docker}" build)

if [ -x "$PWD/ci/docker-build.sh" ]; then
    docker_build_command=("$PWD/ci/docker-build.sh")
fi

docker_build_command+=(
    --build-arg BUILD_DATE="$(date --iso-8601=seconds)"
    --build-arg BUILD_HOSTNAME="$(hostname)"
    --build-arg BUILD_JOB_NAME="${CI_JOB_NAME:-$CI_BUILD_NAME}"
    --build-arg BUILD_NUMBER="${CI_JOB_ID:-$CI_BUILD_ID}"
    --build-arg CI_COMMIT_TAG="${CI_COMMIT_TAG}"
    --build-arg VCS_REF="$(get_git_revision)"
    --build-arg VCS_BRANCH="$(get_git_branch)"
    --build-arg VCS_TAG="$(get_git_tag)"
    --build-arg VERSION="$(get_version)"
    --build-arg BUILD_TYPE="$BUILD_TYPE"
    --pull=true
    --no-cache=true
    "$@"
    -t "$DOCKER_IMAGE_NAME"
    .
)
mylog "Running docker build: ${docker_build_command[*]}"
"${docker_build_command[@]}"
mylog "Created docker image: $DOCKER_IMAGE_NAME"
