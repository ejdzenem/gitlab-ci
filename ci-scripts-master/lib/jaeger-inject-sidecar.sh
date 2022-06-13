#!/bin/bash
#
# ./jaeger-inject-sidecar.sh [OPTIONS]
#
# Injects jaeger sidecar to kubernetes deployment using kustomize.
#
# Possible OPTIONS are:
#   -h|--help                            Show this message and exists.
#   --env               ENVIRONMENT      Environment name. Default: production.
#   -f|--manifest-file  MANIFEST_FILE    Deployment manifest file.
#
# It assumes that directory "./kubernetes/<environment_name>" exists and
# contains "kustomization.yaml" file. kustomization.yaml example:
#       resources:
#         - <APP_NAME>-deployment.yaml
#
#       patches:
#       - path: jaeger-agent-sidecar.yaml
#         target:
#           kind: Deployment
#
# Jaeger-agent container will be added to a kubernetes deployment specified
# in "--manifest-file".
#
# Example:
#   jaeger-inject-sidecar.sh --env "production" --manifest-file "json-api-deployment.yaml"

set -eo pipefail

self=$(readlink -f $0)
dir=$(dirname $self)

source $dir/common.sh

pargs=$(getopt -o "h,f:," -l "env:,help,manifest-file:" -n "$0" -- "$@")
eval set -- "$pargs"

ENVIRONMENT=
MANIFEST_FILE=

while true; do
  case "$1" in
    -h|--help)
        help_display $0
        exit 0
        ;;
    --env)
        ENVIRONMENT="$2"
        shift 2
        ;;
    -f|--manifest-file)
        MANIFEST_FILE="$2"
        shift 2
        ;;
    --)
        shift
        break
        ;;
    *)
        help_display $0
        myexit 1 "Parameter $1 is not recognized."
        ;;
  esac
done

ENVIRONMENT="${ENVIRONMENT:-production}"
DEST_DIR="${PWD}/kubernetes/${ENVIRONMENT}"

[ -n "${MANIFEST_FILE}" ] || myexit --help 1 "MANIFEST_FILE is required. Use parameter '--manifest-file'"
[ -d "${DEST_DIR}" ] || myexit --help 1 "ENVIRONMENT is not defined. Directory 'production' doesn't exist."

tmp_dir=$(mktemp -d)
git clone https://gitlab-ci-token:${CI_JOB_TOKEN}@gitlab.seznam.net/Sklik-DevOps/tracing-specification.git "${tmp_dir}"

cp "${tmp_dir}/k8s-manifests/jaeger-agent-sidecar.yaml" "${DEST_DIR}"
pushd "${DEST_DIR}"
kustomize build . > "${MANIFEST_FILE/.yaml/-jaeger-sidecar.yaml}"

rm -rf "jaeger-agent-sidecar.yaml" "kustomization.yaml" "${MANIFEST_FILE}" "${tmp_dir}"
popd
