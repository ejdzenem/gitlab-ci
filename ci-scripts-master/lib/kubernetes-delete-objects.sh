#!/bin/bash

# kubernetes-delete-objects.sh 
#   -n|--namespace <kubernetes-namespace>               (required)
#     alternatively using env.variable KUBERNETES_NAMESPACE
#   -k|--kind <kubernetes-object-kind[s]>               (required)
#   -l|--label <kubernetes-object-label>                (required)
#   --sort-ascending-by <sort-object-key-go-template>   (optional)
#   --keep-n-recent <keep-N-most-recent-objects>        (optional)
#
#   deletes kubernetes objects according following rules:
#     * in kubernetes namespace <kubernetes-namespace>
#     * only kubernetes object kind[s] <kubernetes-object-kind[s]> with defined label <kubernetes-object-label>
#     * sorts objects ascending way by object key defined by go-template [sort-object-key-go-template]
#     * deletion:
#       * all if --keep-n-recent not specified
#       * [keep-N-most-recent-objects] most recent objects are not deleted if --keep-n-recent specified
# 

# Example:
#   # deletes all except the 5 most recent configmaps in sklik-pre-production labeled app=slo-exporter-userproxy
#   # sorting done on custom object key .metadata.labels.ci-pipeline-id
#   $ kubernetes-delete-objects-custom.sh --namespace sklik-pre-production
#                                         --kind configmap
#                                         --label app=slo-exporter-userproxy
#                                         --sort-ascending-by 'index .metadata "labels" "ci-pipeline-id"'
#                                         --keep-n-recent 5

# TODO: push metrics to Prometheus PushGateway

set -eo pipefail

[ -n "$TRACE" ] && set -x

# sourcing the lib
dir=$(dirname $(readlink -f $0))
source $dir/common.sh

# parsing command-line options
KUBERNETES_OBJECT_KIND=
KUBERNETES_OBJECT_LABEL=
SORT_KEY_GO_TEMPLATE=".metadata.resourceVersion"
KEEP_OBJECT_CNT=0
pargs=$(getopt -o "h,n:,k:,l:" -l "help,namespace:,kind:,label:,sort-ascending-by:,keep-n-recent:,debug" -n "$0" -- "$@")
eval set -- "$pargs"

while true; do
  case "$1" in
    -h|--help)
        help_display $0
        exit 0
        ;;
    -n|--namespace)
        KUBERNETES_NAMESPACE="$2"
        shift 2
        ;;
    -k|--kind)
        KUBERNETES_OBJECT_KIND="$2"
        shift 2
        ;;
    -l|--label)
        KUBERNETES_OBJECT_LABEL="$2"
        shift 2
        ;;
    --sort-ascending-by)
        SORT_KEY_GO_TEMPLATE="$2"
        shift 2
        ;;
    --keep-n-recent)
        KEEP_OBJECT_CNT="$2"
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

[ -n "${KUBERNETES_NAMESPACE}" ] || myexit --help 1 "argument --namespace <kubernetes-namespace> is required"
[ -n "${KUBERNETES_OBJECT_KIND}" ] || myexit --help 1 "argument --kind <kubernetes-object-kind[s]> is required"
[ -n "${KUBERNETES_OBJECT_LABEL}" ] || myexit --help 1 "argument --label <kubernetes-object-label> is required"

KUBECTL="${KUBECTL_BIN} --namespace=${KUBERNETES_NAMESPACE}"

echo "Cleaning-up ${KUBERNETES_OBJECT_KIND} objects in namespace '${KUBERNETES_NAMESPACE}', cluster:"
${KUBECTL_BIN} cluster-info | grep Kubernetes

template_str=$(printf '{{range .items}}{{.kind}}/{{.metadata.name}} {{%s}}{{"\\n"}}{{end}}' "${SORT_KEY_GO_TEMPLATE}")
object_list=$(${KUBECTL} get ${KUBERNETES_OBJECT_KIND} -l "${KUBERNETES_OBJECT_LABEL}" -o go-template --template "${template_str}" | \
              sort -n -k2 | head -n -${KEEP_OBJECT_CNT} | awk '{print $1}')

manifest_cnt=0
for i_object in ${object_list}; do
    echo "Processing kubernetes object '${i_object}'"
    ${KUBECTL} delete "${i_object}"
    echo "..deleted."
    manifest_cnt=$(( ${manifest_cnt} + 1 ))
done
echo "Completed in ${SECONDS} sec[s], deleted ${manifest_cnt} objects"

