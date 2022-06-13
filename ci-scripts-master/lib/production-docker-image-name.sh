#!/bin/bash
#
# production-docker-image-name.sh <development-docker-image-name> [development-docker-image-convert-if-regexp] [production-registry-name]
#                                 [-h]|[--help]
#
# Defaults:
# - <development-docker-image-convert-if-regexp>: "^docker[.]ops[.]iszn[.]cz/"
# - <production-registry-name>: $CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY, "docker.ops.iszn.cz"
#
# If <development-docker-image-name> matches <development-docker-image-convert-if-regexp>,
# it is transformed into production one:
#   1. If env var CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_NAMESPACE is non-empty:
#      replacesregistry with <production-registry-name> and namespace
#      with $CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_NAMESPACE
#   2. otherwise
#      replaces registry with [production-registry-name], keeping the namespace
# When no transformation happens, the <development-docker-image-name> is
# returned unchanged.
#
# Production docker image name is provided on stdout.
#
# Examples:
#    # conversion from docker.ops.iszn.cz/generic-dev/* -> docker.ops.iszn.cz/generic-prod/*
#    $ CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY=docker.ops.iszn.cz \
#      CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_NAMESPACE=generic-prod \
#      ./production-docker-image-name.sh docker.ops.iszn.cz/generic-dev/ci-scripts:1.13.2
#    docker.ops.iszn.cz/generic-prod/ci-scripts:1.13.2
#
#    # conversion from docker.dev.dszn.cz
#    $ ./production-docker-image-name.sh docker.dev.dszn.cz/generic/ci-scripts:1.13.2 docker.dev
#    docker.ops.iszn.cz/generic/ci-scripts:1.13.2
#
#    # conversion from docker.ops.iszn.cz to custom docker production registry
#    $ ./production-docker-image-name.sh docker.ops.iszn.cz/generic/ci-scripts:1.13.2 "" myproductionregistry
#    myproductionregistry/generic/ci-scripts:1.13.2
#
#    # help
#    $ ./production-docker-image-name.sh --help
#    <help message>
#

set -eo pipefail

[ -n "$TRACE" ] && set -x

SCRIPT_FN=$(readlink -f $0)
SCRIPT_DIR=$(dirname ${SCRIPT_FN})

source ${SCRIPT_DIR}/common.sh

development_docker_image_name="$1"
development_docker_image_regexp="${2:-"^docker[.]ops[.]iszn[.]cz/"}"
production_registry_name="${3:-"${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY:-"docker.ops.iszn.cz"}"}"

function remove_leading_tailing_slashes() {
  echo "$1" | sed 's#^/*##;s#/*$##'
}

if [ "$1" == "-h" -o "$1" == "--help" -o \
     "$#" == "0"  -o -z "${development_docker_image_name}" ]; then
    help_display ${SCRIPT_FN}
    [ "$#" == "0" -o -z "${development_docker_image_name}" ] && \
      exit 1 || \
      exit 0
fi

if [[ "${development_docker_image_name}" =~ ${development_docker_image_regexp} ]]; then
    if [ -n "${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_NAMESPACE}" ]; then
        prod_docker_registry="$(remove_leading_tailing_slashes "${production_registry_name}")"
        prod_docker_registry_namespace="$(remove_leading_tailing_slashes "${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_NAMESPACE}")"
        component_and_tag="$(basename "${development_docker_image_name}")"
        echo -n "${prod_docker_registry}/${prod_docker_registry_namespace}/${component_and_tag}"
    else
        echo -n "${development_docker_image_name}" | sed -r "s#^[^/]+/#${production_registry_name}/#"
    fi
else
    echo -n "${development_docker_image_name}"
fi

# eof
