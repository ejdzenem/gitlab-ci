#!/bin/bash
#
# kl-upload-component.sh --component-namespace $NAMESPACE --ci-pipeline-url $CI_PIPELINE_URL --ci-project-url $CI_PROJECT_URL --version $VERSION --resource-dir $RESOURCES_DIR [--storage-url STORAGE_URL] [--component-name NAME]
#
# Upload all yaml files as .tgz archive.
# Everything is uploaded to kube-launcher storage.
#
# Environment variable:
#   KL_STORAGE_URL - minio storage url
#   KL_STORAGE_TOKEN  - minio access key
#   KL_STORAGE_KEY - minio secret key
#   KL_STORAGE_BUCKET_NAME - minio bucket name
#
# example:
#   kl-upload-component.sh --component-namespace sklik-master --ci-pipeline-url http://some-url.com/pipeline/5 --ci-project-url http://some-url.com --version v1.0.0 --resource-dir /tmp
#

GOENVTEMPLATOR_EXE=${GOENVTEMPLATOR_EXE:-goenvtemplator2}
KL_STORAGE_CLIENT_BIN=${KL_STORAGE_CLIENT_BIN:-mc}

dir=$(dirname $(readlink -f $0))
source $dir/common.sh

# parsing command-line options
pargs=$(getopt -o "h," -l "environment:,component-name:,storage-url:,storage-bucket-name:,ci-pipeline-url:,ci-project-url:,version:,description:,resource-dir:" -n "$0" -- "$@")
eval set -- "$pargs"

ENVIRONMENT=
COMPONENT_NAME=
PIPELINE_URL=
PROJECT_URL=
DESCRIPTION=
RESOURCE_DIR=
VERSION=
while true; do
  case "$1" in
    --environment)
        ENVIRONMENT="$2"
        shift 2
        ;;
    --component-name)
        COMPONENT_NAME="$2"
        shift 2
        ;;
    --storage-url)
        STORAGE_URL=$2
        shift 2
        ;;
    --storage-bucket-name)
        STORAGE_BUCKET_NAME=$2
        shift 2
        ;;
    --ci-pipeline-url)
        PIPELINE_URL=$2
        shift 2
        ;;
    --ci-project-url)
        PROJECT_URL=$2
        shift 2
        ;;
    --description)
        DESCRIPTION=$2
        shift 2
        ;;
    --resource-dir)
        RESOURCE_DIR=$2
        shift 2
        ;;
    --version)
        VERSION=$2
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

[ -n "${ENVIRONMENT}" ] || myexit --help 1 "Parameter --environment is required!"
[ -n "${VERSION}" ] || myexit --help 1 "Parameter --version is required!"
[ -n "${PIPELINE_URL}" ] || myexit --help 1 "Parameter --ci-pipeline-url is required!"
[ -n "${PROJECT_URL}" ] || myexit --help 1 "Parameter --ci-project-url is required!"
[ -n "${RESOURCE_DIR}" ] || myexit --help 1 "Parameter --resource-dir is required!"

STORAGE_URL=${STORAGE_URL:-${KL_STORAGE_URL}}
STORAGE_BUCKET_NAME=${STORAGE_BUCKET_NAME:-${KL_STORAGE_BUCKET_NAME}}
CREATED=$(date --iso-8601=seconds)

# find out if CRD source "KubeLauncherComponent" exists
component_yaml_full_path=""
for kubernetes_manifest_file in "${RESOURCE_DIR}"/*.yaml; do
    [ -e "$kubernetes_manifest_file" ] || continue
    python3 -c 'import sys; from ruamel import yaml; y=yaml.safe_load(sys.stdin.read()); assert y.get("kind")=="KubeLauncherComponent"' 2>/dev/null < $kubernetes_manifest_file
    if [ $? -eq 0 ]; then
        component_yaml_full_path=$kubernetes_manifest_file
        break
    fi
done

# Search component name
if [[ -z $COMPONENT_NAME ]]; then
    if [ -z $component_yaml_full_path ]; then
        component_name=""
        for kubernetes_manifest_file in "${RESOURCE_DIR}"/*.yaml; do
            [ -e "$kubernetes_manifest_file" ] || continue
            component_name="$(python3 -c 'import sys; from ruamel import yaml; y=yaml.safe_load(sys.stdin.read()); print(y.get("metadata", {}).get("labels", {}).get("app", ""))' < $kubernetes_manifest_file)"
            if [[ -n "$component_name" ]]; then
                COMPONENT_NAME=$component_name
                break
            fi
        done
    else
        COMPONENT_NAME="$(python3 -c 'import sys; from ruamel import yaml; y=yaml.safe_load(sys.stdin.read()); print(y.get("spec", {}).get("descriptor", {}).get("name", ""))' < $component_yaml_full_path)"
    fi
fi

if [[ -z $COMPONENT_NAME ]]; then
    component_name=""
    for kubernetes_manifest_file in "${RESOURCE_DIR}"/*.yaml; do
        [ -e "$kubernetes_manifest_file" ] || continue
        component_name="$(python3 -c 'import sys; from ruamel import yaml; y=yaml.safe_load(sys.stdin.read()); print(y.get("spec", {}).get("template", {}).get("metadata", {}).get("labels", {}).get("app", "") if y.get("kind")=="Deployment" else "")' < $kubernetes_manifest_file)"
        if [[ -n "$component_name" ]]; then
            COMPONENT_NAME=$component_name
            break
        fi
    done
fi

[ -n "${COMPONENT_NAME}" ] || myexit --help 1 "Default app name not found in kubernetes manifests, please set parameter --component-name!"

mkdir -p ${COMPONENT_NAME}
tmpdir=$(mktemp -d)
mkdir -p ${tmpdir}/${ENVIRONMENT}/${COMPONENT_NAME}


# if CRD source "KubeLauncherComponent" not exists, generate component.yaml
if [ -z $component_yaml_full_path ]; then
    component_yaml_full_path=${RESOURCE_DIR}/"component.yaml"
    ENVIRONMENT=$ENVIRONMENT COMPONENT_NAME=$COMPONENT_NAME PIPELINE_URL=$PIPELINE_URL \
    PROJECT_URL=$PROJECT_URL VERSION=$VERSION DESCRIPTION=$DESCRIPTION CREATED=$CREATED \
    ${GOENVTEMPLATOR_EXE} -template ${dir}/template/component.yaml.tmpl:${component_yaml_full_path}
fi

# prepare data structure and create archive
cp -f ${RESOURCE_DIR}/*.yaml ${COMPONENT_NAME}
python3 -c 'import sys; from ruamel import yaml; print(yaml.safe_dump([{key: value if value is not None else "" for key,value in yaml.safe_load(sys.stdin)["spec"]["descriptor"].items()}], default_flow_style=False), end="")' < ${component_yaml_full_path}
tar -czvf ${tmpdir}/${ENVIRONMENT}/${COMPONENT_NAME}/${VERSION}.tgz ${COMPONENT_NAME}/*.yaml
rm -rf ${COMPONENT_NAME}/

# Initialize KL_STORAGE_CLIENT configuration
repeat_for_ecode 0 5 1 ${KL_STORAGE_CLIENT_BIN} config host add kube-launcher $STORAGE_URL $KL_STORAGE_TOKEN $KL_STORAGE_KEY S3v4 || exit 1
# Upload archive to the storage
repeat_for_ecode 0 5 1 ${KL_STORAGE_CLIENT_BIN} cp ${tmpdir}/* kube-launcher/${KL_STORAGE_BUCKET_NAME} --recursive || exit 1
rm -rf ${tmpdir}/
