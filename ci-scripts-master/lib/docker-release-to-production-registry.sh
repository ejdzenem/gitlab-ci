#!/bin/bash
#
# docker-release-to-production-registry.sh OPTIONS
#
# Release development docker image to the production registry
#
# Possible OPTIONS are:
#   -h|--help                                Show this message and exists
#   -f|--docker-image-name-file         FILE Define source docker image name from existing text file (default: docker-release.uri)
#   -F|--docker-image-digest-file       FILE Define source docker image digest from existing text file (default: docker-release.digest)
#   -n|--docker-image-name              NAME Define source docker image name (default: "", takes preference over --docker-image-name-file)
#   -d|--docker-image-digest          DIGEST Define source docker image digest (default: "", takes preference over --docker-image-digest-file)
#   -N|--destination-docker-image-name  NAME Define destination docker image name (autodetected using production-docker-image-name.sh if not specified)
#
# The script is sensitive to the following env variables:
#     DOCKER_RELEASE_PRODUCTION_DIGEST_FILE                 - default: docker-release-production.digest
#     DOCKER_RELEASE_PRODUCTION_URI_FILE                    - default: docker-release-production.uri
#
# Execution examples:
# a] default execution release docker image from file docker-release.uri (digest in docker-release.digest file) to SCIF docker registry
#    $ /ci/docker-release-to-production-registry.sh
# b] non-default specify docker image and digest directly from commandline
#    $ /ci/docker-release-to-production-registry.sh
#        --docker-image-name docker.dev.dszn.cz/sklik-devops/kubelogmon-server:2.1.0-rc1
#        --docker-image-digest sha256:3e5ae89edebe2c0d57d5f3a87d299ea6a2b4f5ba5396b56eee4ddfffd1ff3389
#        --destination-docker-image-name "$(production-docker-image-name.sh docker.dev.dszn.cz/sklik-devops/kubelogmon-server:2.1.0-rc1)"

set -eo pipefail

[ -n "$TRACE" ] && set -x

SCRIPT_FILE=$(readlink -f $0)
SCRIPT_DIR=$(dirname ${SCRIPT_FILE})

source ${SCRIPT_DIR}/common.sh

# constants
# ---------------------------------------------------------------------------
DOCKER_IMAGE_NAME_FILE=${DOCKER_IMAGE_NAME_FILE:-docker-release.uri}
DOCKER_IMAGE_DIGEST_FILE=${DOCKER_IMAGE_DIGEST_FILE:-docker-release.digest}
DESTINATION_DOCKER_IMAGE_OVERWRITE_ENABLED=${DESTINATION_DOCKER_IMAGE_OVERWRITE_ENABLED:-false}
RETCODE=254
DOCKER_RELEASE_PRODUCTION_URI_FILE=${DOCKER_RELEASE_PRODUCTION_URI_FILE:-docker-release-production.uri}
DOCKER_RELEASE_PRODUCTION_DIGEST_FILE=${DOCKER_RELEASE_PRODUCTION_DIGEST_FILE:-docker-release-production.digest}

# local functions
# ---------------------------------------------------------------------------
function cleanup() {
    if [ ${RETCODE} == 0 ]; then
        echo -e "\nINFO: All steps succeeded"
    elif [ ${RETCODE} == 254 ]; then
        echo -e "\nERROR: An unhandled issue occurred"
    fi
}

# parse arguments
# ---------------------------------------------------------------------------
pargs=$(getopt -o "h,f:,F:,n:,d:,N:" -l "help,docker-image-name-file:,docker-image-digest-file:,docker-image-name:,docker-image-digest:,destination-docker-image-name:" -n "$0" -- "$@")
eval set -- "$pargs"
while true; do
  case "$1" in
    -h|--help)
        help_display ${SCRIPT_FILE}
        exit 0
        ;;
    -f|--docker-image-name-file)
        DOCKER_IMAGE_NAME_FILE="$2"
        shift 2
        ;;
    -F|--docker-image-digest-file)
        DOCKER_IMAGE_DIGEST_FILE="$2"
        shift 2
        ;;
    -n|--docker-image-name)
        DOCKER_IMAGE_NAME="$2"
        shift 2
        ;;
    -d|--docker-image-digest)
        DOCKER_IMAGE_DIGEST="$2"
        shift 2
        ;;
    -N|--destination-docker-image-name)
        DESTINATION_DOCKER_IMAGE_NAME="$2"
        shift 2
        ;;
    --)
        shift
        break
        ;;
    *)
        help_display ${SCRIPT_FILE}
        RETCODE=1
        myexit ${RETCODE} "Not implemented: $1"
        ;;
  esac
done

# register cleanup function
# ---------------------------------------------------------------------------
trap cleanup EXIT


# read the docker image name and digest from specified files
# ---------------------------------------------------------------------------
[ -z "${DOCKER_IMAGE_NAME}" -a -s "${DOCKER_IMAGE_NAME_FILE}" ] && \
  DOCKER_IMAGE_NAME=$(head -1 "${DOCKER_IMAGE_NAME_FILE}")
[ -z "${DOCKER_IMAGE_DIGEST}" -a -s "${DOCKER_IMAGE_DIGEST_FILE}" ] && \
  DOCKER_IMAGE_DIGEST=$(head -1 "${DOCKER_IMAGE_DIGEST_FILE}")


# detect destination docker image name
# ---------------------------------------------------------------------------
DESTINATION_DOCKER_IMAGE_NAME="${DESTINATION_DOCKER_IMAGE_NAME:-"$(${SCRIPT_DIR}/production-docker-image-name.sh "${DOCKER_IMAGE_NAME}")"}"

# evaluate parsed arguments
# ---------------------------------------------------------------------------
if [ -z "${DOCKER_IMAGE_NAME}" -o -z "${DOCKER_IMAGE_DIGEST}" ]; then
    RETCODE=2
    myexit --help ${RETCODE} "ERROR: Docker image and/or digest are not specified correctly, make sure to doublecheck --docker-image-* arguments. Cannot continue."
fi

if [ -z "${DESTINATION_DOCKER_IMAGE_NAME}" ]; then
    RETCODE=3
    myexit --help ${RETCODE} "ERROR: Destination docker image is neither specified (as --destination-docker-image-name) nor auto-detected."
fi

if [ "${DOCKER_IMAGE_NAME}" == "${DESTINATION_DOCKER_IMAGE_NAME}" ]; then
    RETCODE=5
    myexit --help ${RETCODE} "ERROR: Destination docker image is same as source."
fi

echo "INFO: Script configuration is:"
set | grep -E "^((DESTINATION_)?DOCKER_IMAGE_.+|CI_SCRIPTS_.+_DOCKER_REGISTRY.*)=" | sort | awk '{print "  " $0}'

ensure_docker_env
ensure_docker_login "${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY}" "${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_USER}" "${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_PASSWORD_FILE}"

if docker_image_copy "${DOCKER_IMAGE_NAME}" "${DESTINATION_DOCKER_IMAGE_NAME}" \
                     "${DOCKER_IMAGE_DIGEST}" "${DESTINATION_DOCKER_IMAGE_OVERWRITE_ENABLED}" ; then

    echo $DESTINATION_DOCKER_IMAGE_NAME > ${DOCKER_RELEASE_PRODUCTION_URI_FILE}
    get_docker_image_digest "$DESTINATION_DOCKER_IMAGE_NAME" > ${DOCKER_RELEASE_PRODUCTION_DIGEST_FILE}

    echo "INFO: docker image ${DOCKER_IMAGE_NAME} copied to ${DESTINATION_DOCKER_IMAGE_NAME}"
else
    ecode=$?
    RETCODE=4
    myexit --help ${RETCODE} "ERROR: docker image transfer failed (docker_image_copy(${DOCKER_IMAGE_NAME} ${DESTINATION_DOCKER_IMAGE_NAME} ${DOCKER_IMAGE_DIGEST}) -> ${ecode})."
fi

RETCODE=0
