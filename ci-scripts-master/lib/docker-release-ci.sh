#!/bin/bash
# usage: docker-release-ci.sh OPTIONS
#
# Releases image to CI registry
#
# Possible OPTIONS are:
#   -h|--help                         Show this message and exists
#   -c|--component         COMPONENT  Redefine component name (of docker image registry/namespace/component:tag)
#   -n|--namespace         NAMESPACE  Redefine namespace name (of docker image registry/namespace/component:tag)
#   -d|--docker-image-name NAME       Redefine whole docker image name, overrides NAMESPACE and COMPONENT
#   --extra-tags TAGS                 Tag the release with additional tags,
#                                     It is comma separated list (e.g. "2,latest")
#   --dry-run                         Just prints resulting image name
#   -o|--overwrite                    Overwrite existing docker image in registry
#                                     Note, that check for docker image existence is
#                                     race condition not aware!
#
# The script is sensitive to the following env variables:
#     DOCKER_BIN                                  - default: docker
#     DOCKER_CI_RELEASE_URI_FN                    - default: docker-release-ci.uri
#     CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY               - default: cid.dev.dszn.cz
#     CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_NAMESPACE     - default: None
#     CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_USER          - default: empty (no login will be performed)
#     CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_PASSWORD_FILE - default: empty (no login will be performed)
#

set -eo pipefail

[ -n "$TRACE" ] && set -x

self=$(readlink -f $0)
dir=$(dirname $self)

OVERWRITE=false
DRY_RUN=false
COMPONENT=
DOCKER_IMAGE_NAME=
DOCKER_BIN=${DOCKER_BIN:-docker}
DOCKER_CI_RELEASE_URI_FN=${DOCKER_CI_RELEASE_URI_FN:-docker-release-ci.uri}


source $dir/common.sh

pargs=$(getopt -o "h,o,c:,d:,n:" -l "help,component:,overwrite,docker-image-name:,namespace:,dry-run,extra-tags:" -n "$0" -- "$@")
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
    -d|--docker-image-name)
        DOCKER_IMAGE_NAME="$2"
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
    myexit --help 2 "One of COMPONENT and DOCKER_IMAGE_NAME name must be defined"
fi

DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME:-$(get_ci_docker_image_name)}

if $DRY_RUN; then
    echo $DOCKER_IMAGE_NAME
    exit 0
fi

ensure_docker_env
ensure_docker_login "${DOCKER_CI_REGISTRY}" "${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_USER}" "${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_PASSWORD_FILE}"


if ! $OVERWRITE; then
    docker_ci_image_exists || myexit $? "Cannot push to docker registry, image ($DOCKER_IMAGE_NAME) probably exists?"
fi

set -x
${DOCKER_BIN} push $DOCKER_IMAGE_NAME
[ -z "$TRACE" ] && set +x

echo $DOCKER_IMAGE_NAME > ${DOCKER_CI_RELEASE_URI_FN}
INPUT_DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME}

if [ -n "$EXTRA_TAGS" ]; then
    for extra_tag in $(echo "$EXTRA_TAGS" | tr ',' ' '); do
        set -x
        DOCKER_IMAGE_NAME="$(get_ci_docker_image_name "" "" "" $extra_tag)"
        ${DOCKER_BIN} tag $INPUT_DOCKER_IMAGE_NAME $DOCKER_IMAGE_NAME
        ${DOCKER_BIN} push $DOCKER_IMAGE_NAME
        [ -z "$TRACE" ] && set +x
        echo $DOCKER_IMAGE_NAME >> ${DOCKER_CI_RELEASE_URI_FN}
    done
fi
