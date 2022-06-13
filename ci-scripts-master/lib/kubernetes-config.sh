#!/bin/bash
#
# kubernetes-config.sh [--component COMPONENT]
#                      [--env KUBERNETES_ENV]
#                      [--no-configmap]
#                      [--no-validate]
#                      [--help]
#
# Generate kubernetes yaml config files from templates.
#
# Kubernetes templates must be located in "./kubernetes/" directory.
# Configuration is taken from "./conf/${KUBERNETES_ENV}.env" file and is
# stored in ConfigMap named  "${COMPONENT}-configmap.yaml".
# If `--no-configmap` is set, ConfigMap is not created.
#
# Result is stored in ./kubernetes/$KUBERNETES_ENV/ directory.
# Generated manifests are validated using kubeconform
# (unless `--no-validate` is set).
#
# example:
#   kubernetes-config.sh --env production --component frontend-api
#


set -eo pipefail

[ -n "$TRACE" ] && set -x

# sourcing the lib
dir=$(dirname $(readlink -f $0))
source $dir/common.sh

GOENVTEMPLATOR_EXE=${GOENVTEMPLATOR_EXE:-goenvtemplator2}

COMPONENT=""
NO_CONFIGMAP=""
NO_VALIDATE=""

# parsing command-line options
pargs=$(getopt -o "h," -l "env:,help,component:,debug,no-configmap,no-validate" -n "$0" -- "$@")
eval set -- "$pargs"

while true; do
  case "$1" in
    -h|--help)
        help_display $0
        exit 0
        ;;
    --component)
        COMPONENT="$2"
        shift 2
        ;;
    --env)
        KUBERNETES_ENV=$2
        shift 2
        ;;
    --debug)
        set -x
        shift
        ;;
    --no-configmap)
        NO_CONFIGMAP="--no-configmap"
        shift
        ;;
    --no-validate)
        NO_VALIDATE="--no-validate"
        shift
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

COMPONENT=${COMPONENT:-$(get_component)}
KUBERNETES_ENV=${KUBERNETES_ENV:-development}

[ -n "${COMPONENT}" ] || \
    myexit --help 1 "COMPONENT is required. Either user parametr '--component' or check 'get_component' function in /ci/common.sh."

CONF_DIR="${PWD}/conf"
ENV_FILE="${CONF_DIR}/${KUBERNETES_ENV}.env"
DEST_DIR="${PWD}/kubernetes/${KUBERNETES_ENV}"

$dir/kubernetes-config-custom.sh \
    --app $COMPONENT \
    --env-file $ENV_FILE \
    --destination-dir $DEST_DIR \
    ${NO_CONFIGMAP} \
    ${NO_VALIDATE}

# eof
