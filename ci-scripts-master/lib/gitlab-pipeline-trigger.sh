#!/bin/bash
#
# gitlab-pipeline-trigger.sh [OPTIONS]
#
# Triggers specified gitlab pipeline.
#
# Possible OPTIONS are:
#   -h|--help                           Show this message and exists.
#   -p|--project-id        PROJECT      Gitlab's project ID. If not specified CI_PIPELINE_PROJECT_ID env variable is used.
#   -t|--trigger-token     TOKEN        Gitlab projects' trigger token. CI_PIPELINE_TRIGGER_TOKEN is used.
#   -o|--output-format     FMT          JQ query JSON GitLab's reply. (default ".id" to return pipeline ID).
#                                         * "." to see whole response
#                                         * ".id" to see pipeline ID
#                                         * "" for empty output
#   -r|--pipeline-git-ref  REF          Gitlab git reference (commit, branch, tag) name (default "master")
#   -e|--pipeline-env      ENV-VAR-NAME Pass additional env.variable when triggering the pipeline. Can be repeated.
#                                         specify just name of the env.variable (pair name=value will be passed)
#
# Example:
#   # trigger development-kubernetes-backup pipeline, branch my-branch, return the pipeline ID
#   ./gitlab-pipeline-trigger.sh --project-id 8379 --pipeline-git-ref my-branch --trigger-token <pipeline-trigger-token>
#   # trigger development-kubernetes-backup pipeline, passing arguments A=a and B=b, return whole reply
#   export A=a
#   export B=b
#   ./gitlab-pipeline-trigger.sh --project-id 8379 --pipeline-env A --pipeline-env B --output-format "." --trigger-token <pipeline-trigger-token>
#
# Exit codes:
#   0        Operation succeeded.
#   1        Failed to get arguments, or required argument is missing.
#   2        Failure causing pipeline not to be triggered, but GitLab requested.

set -eo pipefail

[ -n "$TRACE" ] && set -x

self=$(readlink -f $0)
dir=$(dirname $self)

# initialize global variables
JQ="jq -c -M"
GITLAB_URL=${GITLAB_URL:-"${CI_PROJECT_URL///${CI_PROJECT_PATH}}"}
PROJECT_ID=
TRIGGER_TOKEN=
PIPELINE_GIT_REF="master"
OUTPUT_FORMAT=".id"
PIPELINE_ARGUMENTS=()

source $dir/common.sh

pargs=$(getopt -o "h,p:,i:,t:,o:,r:,e:" -l "help,project-id:,pipeline-id:,trigger-token:,output-format:,pipeline-git-ref:,pipeline-env:" -n "$0" -- "$@")
eval set -- "$pargs"
while true; do
  case "$1" in
    -h|--help)
        help_display $self
        exit 0
        ;;
    -p|--project-id)
        PROJECT_ID="$2"
        shift 2
        ;;
    -t|--trigger-token)
        TRIGGER_TOKEN="$2"
        shift 2
        ;;
    -o|--output-format)
        OUTPUT_FORMAT="$2"
        shift 2
        ;;
    -r|--pipeline-git-ref)
        PIPELINE_GIT_REF="$2"
        shift 2
        ;;
    -e|--pipeline-env)
        PIPELINE_ARGUMENTS+=("--form")
        PIPELINE_ARGUMENTS+=("variables[${2}]=${!2}")
        shift 2
        ;;
    --)
        shift
        break
        ;;
    *)
        myexit --help 1 "Not implemented: $1"
        ;;
  esac
done

# fallback to GitLab CI environment variables / pipeline variables
read -r PROJECT_ID <<< "${PROJECT_ID:-$CI_PIPELINE_PROJECT_ID}"

# check whether input arguments are set properly
[ -z "$PROJECT_ID" ] && \
  myexit --help 1 'Project ID must be set!'

# store the token in file (make sure to drop suffixing \n)
temp_fn=$(mktemp)
trap "rm -f ${temp_fn}" EXIT
cat <<< "${TRIGGER_TOKEN:-$CI_PIPELINE_TRIGGER_TOKEN}" | tr -d '\n' > ${temp_fn}
[ -s "${temp_fn}" ] || \
  myexit --help 1 "Trigger token has to be non-empty! Use -t|--trigger-token options or CI_PIPELINE_TRIGGER_TOKEN environment var."

# triggering the pipeline
trigger_result=$(curl --request POST \
                      --silent "${PIPELINE_ARGUMENTS[@]}" \
                      --form "token=<${temp_fn}" \
                      --form "ref=${PIPELINE_GIT_REF}" \
                      "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/trigger/pipeline")

test -z "${trigger_result}" && \
  myexit 2 'FATAL: No or empty reply from GitLab!'

if [[ "$(echo "${trigger_result}" | ${JQ} '.id // empty')" =~ ^[0-9]+$ ]]; then
    if [ -n "${OUTPUT_FORMAT}" ]; then
        echo "${trigger_result}" | ${JQ} "${OUTPUT_FORMAT}"
    fi
else
    myexit 2 "FATAL: GitLab pipeline trigger failure! Unexpected reply: ${trigger_result}"
fi

# eof
