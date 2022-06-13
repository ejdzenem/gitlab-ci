#!/bin/bash
#
# kubernetes-deploy.sh [--namespace NAMESPACE] [--env KUBERNETES_ENV] [--resources-dir RESOURCES_DIR] [--deploy-timeout TIMEOUT]
#
# Deploy all yaml files located in:
#  * RESOURCES_DIR    if --resources-dir is present
#  * "kubernetes/$KUBERNETES_ENV/"    unless --resources_dir is present
#
# All namespaced resources are deployed to kubernetetes namespace $NAMESPACE.
# It applies kubernetes resources in order: global-scoped, ConfigMap, Service, Secret, (Cron)Job, other-non-workload, workloads
#
# example:
#   kubernetes-deploy.sh --env production --component frontend-api
#

# sourcing the lib
set -eo pipefail

DEPLOY_TIMEOUT=${DEPLOY_TIMEOUT:-180}

[ -n "$TRACE" ] && set -x

dir=$(dirname $(readlink -f $0))
source $dir/common.sh

# define specific kubectl deploy actions per resource
declare -A kubectl_deploy_actions
kubectl_deploy_actions[Job]='replace --force'

# parsing command-line options
pargs=$(getopt -o "h," -l "env:,help,namespace:,resources-dir:,deploy-timeout:,debug" -n "$0" -- "$@")
eval set -- "$pargs"


while true; do
  case "$1" in
    -h|--help)
        help_display $0
        exit 0
        ;;
    --namespace)
        NAMESPACE="$2"
        shift 2
        ;;
    --env)
        KUBERNETES_ENV=$2
        shift 2
        ;;
    --resources-dir)
        RESOURCES_DIR=$2
        shift 2
        ;;
    --deploy-timeout)
        DEPLOY_TIMEOUT=$2
        shift 2
        ;;
    --debug)
        set -x
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

[ -n "$KUBERNETES_ENV" -a -n "$RESOURCES_DIR" ] && \
    myexit --help 2 "KUBERNETES_ENV and RESOURCES_DIR cannot be defined at once!"

KUBERNETES_ENV=${KUBERNETES_ENV:-development}
RESOURCES_DIR=${RESOURCES_DIR:-"${PWD}/kubernetes/${KUBERNETES_ENV}"}
KUBECTL="${KUBECTL_BIN}"

GLOBAL_SCOPED_RESOURCES=
CONFIGMAPS=
SERVICES=
SECRETS=
OTHERS=
WORKLOADS=
JOBS=

declare -A manifest_kinds
for f in ${RESOURCES_DIR}/*.yaml; do
    kind="$(${KUBECTL_BIN} create -f $f --dry-run -o json | jq -r .kind | sort -u )"
    manifest_kinds[${f}]="${kind}"
    case $kind in
        Namespace|ClusterRoleBinding|ClusterRole|PodSecurityPolicy|ValidatingWebhookConfiguration|PriorityClass|StorageClass)
            GLOBAL_SCOPED_RESOURCES="${GLOBAL_SCOPED_RESOURCES} $f"
            ;;
        ConfigMap)
            CONFIGMAPS="${CONFIGMAPS} $f"
            ;;
        Secret)
            SECRETS="${SECRETS} $f"
            ;;
        Service)
            SERVICES="${SERVICES} $f"
            ;;
        Deployment|DaemonSet|StatefulSet)
            WORKLOADS="${WORKLOADS} $f"
            ;;
        Job|CronJob)
            JOBS="${JOBS} $f"
            ;;
        *)
            OTHERS="${OTHERS} $f"
            ;;
    esac

done

if [[ ! "$CONFIGMAPS $SERVICES $SECRETS $JOBS $OTHERS $WORKLOADS" =~ ^[[:space:]]+$ ]]; then

    if [[ -z "$NAMESPACE" ]]; then
        myexit --help 1 "Parameter --namespace is required when namespace-scoped resources are being deployed! ($CONFIGMAPS $SERVICES $SECRETS $JOBS $OTHERS $WORKLOADS)"
    else
        KUBECTL="${KUBECTL_BIN} --namespace=${NAMESPACE}"
    fi
fi

# make rest of the operations verbose (for better debugging)
set | grep -E '^(WORKLOADS|CONFIGMAPS|SERVICES|SECRETS|GLOBAL_SCOPED_RESOURCES|JOBS|OTHERS)='
set -x

for resource in $GLOBAL_SCOPED_RESOURCES $CONFIGMAPS $SERVICES $SECRETS $JOBS $OTHERS $WORKLOADS; do
    kind="${manifest_kinds[${resource}]}"
    ${KUBECTL} ${kubectl_deploy_actions[${kind}]:-apply --record} -f ${resource}
done

for resource in $WORKLOADS; do
    timeout --signal=KILL ${DEPLOY_TIMEOUT} ${KUBECTL} rollout status -f $resource
done
