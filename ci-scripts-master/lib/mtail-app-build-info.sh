#!/bin/bash
#
# mtail-app-build-info.sh [OPTIONS]
#
# Generates mtail file with app_build_info metric. Writes it to stdout.
#
# Possible OPTIONS are:
#   -h|--help                            Show this message and exists
#   -c|--component=COMPONENT             Value of label app in mtail metric
#   --format=prometheus|json|simplejson  Output metric format (default: prometheus)

set -eo pipefail

[ -n "$TRACE" ] && set -x

self=$(readlink -f $0)
dir=$(dirname $self)

# initialize global variables
COMPONENT=
FORMAT="prometheus"

source $dir/common.sh

pargs=$(getopt -o "h,c:" -l "help,component:,format:" -n "$0" -- "$@")
eval set -- "$pargs"
while true; do
  case "$1" in
    -h|--help)
        help_display $self
        exit 0
        ;;
    -c|--component)
        COMPONENT="$2"
        shift 2
        ;;
    --format)
        FORMAT="$2"
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

COMPONENT=${COMPONENT:-$(get_component)}
VERSION=$(get_version)
REVISION=$(get_git_revision)
TAG=$CI_COMMIT_TAG
BUILD_ID=${CI_PIPELINE_ID:=<undefined>}

# if TAG is empty, we set branch, which is present in CI_COMMIT_REF_NAME variable
if [ -z "$TAG" ]; then
    BRANCH=$CI_COMMIT_REF_NAME
    TAG="<undefined>"
else
    BRANCH="<undefined>"
fi

if [ -z "$COMPONENT" ]; then
    myexit --help 2 'Component cannot be empty!'
fi

if [ "${FORMAT}" == "prometheus" ]; then
    cat <<HEREDOC
gauge app_build_info by app, revision, version, branch, tag, build_id

app_build_info["$COMPONENT"]["$REVISION"]["$VERSION"]["$BRANCH"]["$TAG"]["$BUILD_ID"] = 1
HEREDOC

elif [ "${FORMAT}" == "simplejson" ]; then
    printf '{"component": "%s", "revision": "%s", "version": "%s", "branch": "%s", "tag": "%s", "build_id": "%s"}\n' \
      "$COMPONENT" "$REVISION" "$VERSION" "$BRANCH" "$TAG" "$BUILD_ID"
elif [ "${FORMAT}" == "json" ]; then
    printf '{"Name":"app_build_info","Kind":2,"Type":0,"Keys":["app","revision","version","branch","tag", "build_id"],"LabelValues":[{"Labels":["%s","%s","%s","%d","%s","%s"],"Value":{"Value":1}}]}\n' \
      "$COMPONENT" "$REVISION" "$VERSION" "$BRANCH" "$TAG" "$BUILD_ID"
else
    myexit --help 2 "Output format is invalid (--format=${FORMAT})!"
fi

exit 0
