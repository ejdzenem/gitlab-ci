#!/bin/bash
#
# gitlab-pipeline-status.sh [OPTIONS]
#
# Returns a status of a given gitlab pipeline.
#
# Possible OPTIONS are:
#   -h|--help                         Show this message and exists.
#   -p|--project-id      PROJECT      Gitlab's project ID. If not passed and gitlab CI environment
#                                     is detected, CI_PROJECT_ID env variable is used.
#   -i|--pipeline-id     ID           Gitlab's pipeline ID. Required.
#   --access-token       TOKEN        Gitlab User's private access token. If not passed and gitlab CI
#                                     environment is detected, CI_PIPELINE_ACCESS_TOKEN is used.
# Example:
#   # getting state of the development-kubernetes-backup pipeline nr. 427354
#  ./gitlab-pipeline-status.sh --project-id 8379 --pipeline-id 427354 --access-token <my-private-access-token-to-gitlab-api>
#
# Exit codes:
#   1        Failed to get arguments, or required argument is missing.
#   2        If gitlab returned 404 status code.
#   99       If gitlab returned status code different then 200 and 404.

set -eo pipefail

[ -n "$TRACE" ] && set -x

self=$(readlink -f $0)
dir=$(dirname $self)

# initialize global variables
PROJECT_ID=
PIPELINE_ID=
ACCESS_TOKEN=

source $dir/common.sh

pargs=$(getopt -o "h,p:,i:" -l "help,project-id:,pipeline-id:,access-token:" -n "$0" -- "$@")
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
    -i|--pipeline-id)
        PIPELINE_ID="$2"
        shift 2
        ;;
    --access-token)
        ACCESS_TOKEN="$2"
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

# if passed project id was empty and we detect CI environment we fill current project
in_ci && read -r PROJECT_ID <<< "${PROJECT_ID:-$CI_PROJECT_ID}"
in_ci && read -r ACCESS_TOKEN <<< "${ACCESS_TOKEN:-$CI_PIPELINE_ACCESS_TOKEN}"

[ -z "$PIPELINE_ID" ]   && myexit --help 1 "Pipeline ID must be set!"
[ -z "$PROJECT_ID" ]    && myexit --help 1 "Project ID must be set!"
[ -z $(cat <<< "$ACCESS_TOKEN") ] && myexit --help 1 "Private token must be set!"

tmpfile=$(mktemp)
function cleanup {
  rm -f "$tmpfile"
}
trap cleanup EXIT

http_status=$(curl -K- -o $tmpfile -s -w "%{http_code}" "https://$GITLAB_HOSTNAME/api/v4/projects/$PROJECT_ID/pipelines/$PIPELINE_ID" <<< "header = \"private-token: $ACCESS_TOKEN\"")

if [ "$http_status" != "200" ]; then
    [ "$http_status" == "404" ] && exit_status=2 || exit_status=99
    myexit $exit_status "FATAL: Expected that gitlab will return 200 http status, got $http_status instead with body $(cat $tmpfile)"
fi

cat $tmpfile | jq -r .status
