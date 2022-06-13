#!/bin/bash
#
# docker-release.sh OPTIONS
#
# Push an image to a registry.
#
# The first defined form in the following list is used as the image name:
#   * $DOCKER_IMAGE_NAME
#   * $CI_SCRIPTS_DOCKER_REGISTRY/$NAMESPACE/$COMPONENT:$TAG
#   * $CI_SCRIPTS_DOCKER_REGISTRY/$NAMESPACE/$COMPONENT:$GIT_TAGGED_COMMIT for Gitlab CI with taged commit
#   * $CI_SCRIPTS_DOCKER_REGISTRY/$NAMESPACE/$COMPONENT:$VERSION
# Notes:
#   * $DOCKER_IMAGE_NAME can be set via --docker-image-name only, is is NOT read from the environment
#   * $NAMESPACE, $COMPONENT, $TAG are read from the environment but are individually overridable using OPTIONS
#
# Possible OPTIONS are:
#   -h|--help                         Show this message and exists
#   -c|--component         COMPONENT  Redefine $COMPONENT
#   -n|--namespace         NAMESPACE  Redefine $NAMESPACE
#   -t|--tag               TAG        Redefine $TAG
#   -i|--input-docker-image-name NAME Redefine whole input docker image name, overrides COMPONENT and NAMESPACE
#   -d|--docker-image-name NAME       Redefine whole output docker image name, overrides COMPONENT and NAMESPACE
#   --extra-tags EXTRA_TAGS           Tag the release with additional tags. Default: Read from the environment.
#                                     A comma-separated list (e.g. "2,latest"),
#   --dry-run                         Just prints resulting image name
#   -o|--overwrite                    Overwrite existing docker image in the registry.
#                                     When not given, this script checks that the image does not exist in the
#                                     registry. Note: There is a race condition between the check and the push.
#
# The script is sensitive to the following env variables:
#     DOCKER_BIN                               - default: docker
#     DOCKER_RELEASE_DIGEST_FN                 - default: docker-release.digest
#     DOCKER_RELEASE_URI_FN                    - default: docker-release.uri
#     CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY                - default: docker.ops.iszn.cz
#     CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_NAMESPACE      - default: None
#     CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_USER           - default: empty (no login will be performed)
#     CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_PASSWORD_FILE  - default: empty (no login will be performed)
#

set -eo pipefail

[ -n "$TRACE" ] && set -x


self=$(readlink -f $0)
dir=$(dirname $self)

OVERWRITE=false
DRY_RUN=false
COMPONENT=
DOCKER_IMAGE_NAME=
INPUT_DOCKER_IMAGE_NAME=
DOCKER_BIN=${DOCKER_BIN:-docker}

DOCKER_RELEASE_DIGEST_FN=${DOCKER_RELEASE_DIGEST_FN:-docker-release.digest}
DOCKER_RELEASE_URI_FN=${DOCKER_RELEASE_URI_FN:-docker-release.uri}

source $dir/common.sh

pargs=$(getopt -o "h,o,c:,d:,i:,n:,t:" -l "help,component:,overwrite,docker-image-name:,input-docker-image-name:,namespace:,tag:,dry-run,extra-tags:" -n "$0" -- "$@")
eval set -- "$pargs"
while true; do
  case "$1" in
    -h|--help)
        help_display $self
        exit 0
        ;;
    -o|--overwrite)
        OVERWRITE=true
        shift
        ;;
    -c|--component)
        COMPONENT="$2"
        shift 2
        ;;
    -n|--namespace)
        DOCKER_REGISTRY_NAMESPACE_EXPLICIT="$2"
        shift 2
        ;;
    -t|--tag)
        TAG="$2"
        shift 2
        ;;
    -d|--docker-image-name)
        DOCKER_IMAGE_NAME="$2"
        shift 2
        ;;
    -i|--input-docker-image-name)
        INPUT_DOCKER_IMAGE_NAME="$2"
        shift 2
        ;;
    --extra-tags)
        EXTRA_TAGS="$2"
        shift 2
        ;;
    --dry-run)
        DRY_RUN=true
        shift
        ;;
    --)
        shift
        break
        ;;
    *)
        help_display $self
        myexit 1 "Not implemented: $1"
        ;;
  esac
done

if [ -z "${DOCKER_IMAGE_NAME}" ]; then
    COMPONENT=${COMPONENT:-$(get_component)}
fi

if [ -z "$COMPONENT" -a -z "$DOCKER_IMAGE_NAME" ]; then
    myexit --help 2 "One of COMPONENT and DOCKER_IMAGE_NAME name must be defined!"
elif [ -n "$TAG" -a -n "$DOCKER_IMAGE_NAME" ]; then
    myexit --help 2 "Both TAG and DOCKER_IMAGE_NAME cannot be defined at once!"
fi


INPUT_DOCKER_IMAGE_NAME=${INPUT_DOCKER_IMAGE_NAME:-$(get_ci_docker_image_name)}
DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME:-$(get_docker_image_name)}

if $DRY_RUN; then
    echo $DOCKER_IMAGE_NAME
    exit 0
fi

ensure_docker_env
ensure_docker_login "${DOCKER_REGISTRY}" "${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_USER}" "${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_PASSWORD_FILE}"

if ! $OVERWRITE; then
    docker_image_exists || myexit $? "Cannot push to docker registry, image ($DOCKER_IMAGE_NAME) probably exists?"
fi

set -x
${DOCKER_BIN} pull $INPUT_DOCKER_IMAGE_NAME
${DOCKER_BIN} tag $INPUT_DOCKER_IMAGE_NAME $DOCKER_IMAGE_NAME
${DOCKER_BIN} push $DOCKER_IMAGE_NAME
[ -z "$TRACE" ] && set +x

echo $DOCKER_IMAGE_NAME > ${DOCKER_RELEASE_URI_FN}
get_docker_image_digest "$DOCKER_IMAGE_NAME" > ${DOCKER_RELEASE_DIGEST_FN}

if [ -n "$EXTRA_TAGS" ]; then
    for extra_tag in $(echo "$EXTRA_TAGS" | tr ',' ' '); do
        set -x
        DOCKER_IMAGE_NAME="$(get_docker_image_name "" "" "" $extra_tag)"
        ${DOCKER_BIN} tag $INPUT_DOCKER_IMAGE_NAME $DOCKER_IMAGE_NAME
        ${DOCKER_BIN} push $DOCKER_IMAGE_NAME
        [ -z "$TRACE" ] && set +x
        echo $DOCKER_IMAGE_NAME >> ${DOCKER_RELEASE_URI_FN}
        get_docker_image_digest "$DOCKER_IMAGE_NAME" >> ${DOCKER_RELEASE_DIGEST_FN}
    done
fi
