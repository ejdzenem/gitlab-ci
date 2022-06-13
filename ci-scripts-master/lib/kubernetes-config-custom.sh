#!/bin/bash
#
# kubernetes-config-custom.sh
#   --app APP
#   --destination-dir DESTINATION_DIR
#   [--env-file ENV_FILE]
#   [--no-configmap]
#   [--no-validate]
#   [--help]
#
# Generate kubernetes yaml config files from templates.
#
# Kubernetes templates must be located in "./kubernetes/" directory.
# Configuration is taken from ENV_FILEs (you can pass --env-file multiple times)
# file and is stored in ConfigMap named "${APP}-configmap.yaml"
# If `--no-configmap` is set, ConfigMap is not created.
#
# Result is stored in ./$DESTINATION_DIR/ directory.
# Generated manifests are validated using kubeconform
# (unless `--no-validate` is set).
#
# example:
#   kubernetes-config-custom.sh --env-file conf/production.env --app frontend-api --destination-dir kubernetes/production/
#


set -eo pipefail

[ -n "$TRACE" ] && set -x

# sourcing the lib
dir=$(dirname $(readlink -f $0))
source $dir/common.sh

GOENVTEMPLATOR_EXE=${GOENVTEMPLATOR_EXE:-goenvtemplator2}

APP=

# parsing command-line options
pargs=$(getopt -o "h," -l "env-file:,help,app:,destination-dir:,debug,no-configmap,no-validate" -n "$0" -- "$@")
eval set -- "$pargs"

NO_CONFIGMAP=
NO_VALIDATE=
GOENVTEMPLATOR_ARGS=
ENV_FILES=()

while true; do
  case "$1" in
    -h|--help)
        help_display $0
        exit 0
        ;;
    --app)
        APP="$2"
        shift 2
        ;;
    --env-file)
        if [ -r "$2" ]; then
            GOENVTEMPLATOR_ARGS="$GOENVTEMPLATOR_ARGS -env-file $2"
            ENV_FILES+=("$2")
        else
            echo "WARN file $2 cannot be read, ignoring it..."
        fi
        shift 2
        ;;
    --destination-dir)
        DEST_DIR=$2
        shift 2
        ;;
    --debug)
        set -x
        shift
        ;;
    --no-configmap)
        NO_CONFIGMAP="1"
        shift
        ;;
    --no-validate)
        NO_VALIDATE="1"
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

[ -n "$APP" ] || myexit --help 1 "APP is required. Use parametr '--app'"
[ -n "$DEST_DIR" ] || myexit --help 1 "DESTINATION_DIR is required. Use parametr '--destination-dir'"
# if DEST_DIR is not absolute, than make it absolute
[ "${DEST_DIR:0:1}" == "/" ] || DEST_DIR=$PWD/$DEST_DIR
# kubectl --from-env-file was added in kubectl 1.7
dpkg --compare-versions "$(get_kubectl_version)" "ge" "1.7" || myexit "2" "You need kubectl in version newer or equal 1.7"

SRC_DIR="$PWD/kubernetes"

K8S_CM_NAME="$APP"

mkdir -p $DEST_DIR

# create kubernetes application environment variables configmap
if [ "${#ENV_FILES[@]}" -gt 0 -a "${NO_CONFIGMAP}" != "1" ]; then
  $KUBECTL_BIN create cm $K8S_CM_NAME --dry-run -o yaml --from-env-file=<(cat_files_secure "${ENV_FILES[@]}") > $DEST_DIR/$APP-configmap.yaml
fi

# copy kubernetes configs to $SRC_DIR -> $DEST_DIR
[ "$SRC_DIR" != "$DEST_DIR" -a "$(ls $SRC_DIR/*.yaml 2>/dev/null | wc -l)" -gt "0" ] && \
  cp -f $SRC_DIR/*.yaml $DEST_DIR

# template kubernetes configs
for kubernetes_manifest_file in "$SRC_DIR"/*.yaml.tmpl; do
  [ -e "$kubernetes_manifest_file" ] || continue
  manifest_basename_orig=$(basename $kubernetes_manifest_file)
  manifest_basename_modified=$(echo "$manifest_basename_orig" | sed "s/\.tmpl//g")
  $GOENVTEMPLATOR_EXE $GOENVTEMPLATOR_ARGS -template $kubernetes_manifest_file:$DEST_DIR/$manifest_basename_modified
  split_yaml "$DEST_DIR/$manifest_basename_modified"
done

echo "K8S $APP ${ENV_FILES[*]} config generated (in $DEST_DIR)."
ls -la $DEST_DIR/*.yaml

echo "Removing empty files from ${DEST_DIR}:"
sed -i '/^$/d' ${DEST_DIR}/*
find ${DEST_DIR} -size 0 -print -delete

# validate generated manifests with kubeconform
if [ "${NO_VALIDATE}" != "1" ]; then
  # since we're doing the validation locally, we can't know what kubernetes version to validate against - so kubectl
  # client version is used (hopefully it's close)
  kubeconform -kubernetes-version "$(get_kubectl_version)" -ignore-missing-schemas -summary $DEST_DIR/*.yaml
fi

set +eo pipefail

# temporary added upload manifest to kube-launcher storage
if [[ "${KL_UPLOAD_THROUGH_CI_SCRIPTS_KUBERNETES_DEPLOY}" =~ ^[Tt]rue$ ]]; then
    CI_PIPELINE_URL="${CI_PROJECT_URL}/pipelines/${CI_PIPELINE_ID}"
    VERSION=${CI_COMMIT_TAG:-${CI_COMMIT_REF_SLUG}}
    ENVIRONMENT=$( echo $DEST_DIR | sed "s|${PWD}\/||" | sed 's/kubernetes\///' | sed 's/\/$//' | sed 's/-(web|api)$//')
    # kubernetes don't support CRD file with kind "KubeLauncherComponent", we must use temporary folder
    TEMPORARY_DEST_DIR="$(echo ${DEST_DIR} | sed 's/\/$//')_KL_TEMPORARY"
    cp -rf $DEST_DIR $TEMPORARY_DEST_DIR
    $dir/kl-upload-component.sh --environment $ENVIRONMENT --ci-pipeline-url $CI_PIPELINE_URL --ci-project-url $CI_PROJECT_URL --version $VERSION --resource-dir $TEMPORARY_DEST_DIR
    rm -rf $TEMPORARY_DEST_DIR
fi

# eof
