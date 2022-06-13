#!/bin/bash
#
# Script for generating kubectl configuration into ~/.kube/config. Used in gitlab-ci.
# Following environment variables are required:
# * KUBE_CA_PEM     kubernetes API server PEM formatted CA certificate
# * KUBE_URL        kubernetes API server URL
# * KUBE_TOKEN      kubernetes user token
# * KUBE_NAMESPACE  kubernetes default namespace
#
# Note:
# Content of SZN_CA_PEM_FILENAME (defaults to '/usr/share/ca-certificates/seznam-ca/seznamca-root.crt') is concatenated do what is provided within KUBE_CA_PEM.
#  Set SZN_CA_PEM_FILENAME="" to avoid this.

set -eo pipefail

[ -n "$TRACE" ] && set -x

SZN_CA_PEM_FILENAME="/usr/share/ca-certificates/seznam-ca/seznamca-root.crt"

# sourcing the lib
dir=$(dirname $(readlink -f $0))
source $dir/common.sh

if [[ \
      -z "$KUBE_CA_PEM" || \
      -z "$KUBE_URL" || \
      -z "$KUBE_TOKEN" || \
      -z "$KUBE_NAMESPACE" \
   ]] && ${KUBECTL_BIN} version > /dev/null; then
    echo "It seems that your kubectl is already configured. If you need reconfigure it"
    echo "set all of following variables:"
    echo "  KUBE_CA_PEM=${KUBE_CA_PEM}"
    echo "  KUBE_URL=${KUBE_URL}"
    echo "  KUBE_TOKEN=${KUBE_TOKEN//?/*}"
    echo "  KUBE_NAMESPACE=${KUBE_NAMESPACE}"
    exit 0
fi

echo "Generating kubeconfig..."
echo "$KUBE_CA_PEM" > kube.ca.pem
if [ -n "${SZN_CA_PEM_FILENAME}" -a -r "${SZN_CA_PEM_FILENAME}" ];then
    echo " Concatenating content of '${SZN_CA_PEM_FILENAME}' to what has been provided in \$KUBE_CA_PEM. Kubectl will be configured to trust certificates from any of those providede CAs."
    cat "${SZN_CA_PEM_FILENAME}" >> kube.ca.pem
fi
${KUBECTL_BIN} config set-cluster gitlab-deploy --server="$KUBE_URL" --certificate-authority=kube.ca.pem
${KUBECTL_BIN} config set-credentials gitlab-deploy --token="$KUBE_TOKEN" --certificate-authority=kube.ca.pem
${KUBECTL_BIN} config set-context gitlab-deploy --cluster=gitlab-deploy --user=gitlab-deploy --namespace="$KUBE_NAMESPACE"
${KUBECTL_BIN} config use-context gitlab-deploy
${KUBECTL_BIN} config view | hide_secret 'token:[ \t]*(.+)$' '*'

# test the kubernetes configuration
${KUBECTL_BIN} version >/dev/null
