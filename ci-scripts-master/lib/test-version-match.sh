#!/bin/bash
#
# test_version_match.sh [OPTIONS]
#
# Test that PROJECT_VERSION match the TAGGED_VERSION
#
# Intended usuage is CI pipeline to check that project version the release tag.
#
# TAGGED_VERSION is git tag which marks a project released version. By default it is obtained
# from environment variable $CI_COMMIT_TAG which is automaticaly set byt Gitlab CI pipeline.
#
# It is possible # to specify TAGGED_VERSION_PREFIX. Usually git tag has some prefix
# (by default it is 'v' e.g. 'v1.3.0') or custom, often used when repository creates two
# complementary services (e.g. worker-1.3.0 and manager-1.3.0).
#
# PROJECT_VERSION is usually defined inside a git repository and it is tried to get it
# automatically (see get_version fce in lib/common.sh).
#
# Possible OPTIONS are:
#   -h|--help                               Show this message and exists
#   -p|--project-version PROJECT_VERSION
#   -t|--tagged-version TAGGED_VERSION
#   -x|--tagged-version-prefix TAGGED_VERSION_PREFIX


set -eo pipefail

[ -n "$TRACE" ] && set -x

self=$(readlink -f $0)
dir=$(dirname $self)

source $dir/common.sh


PROJECT_VERSION=
TAGGED_VERSION=
TAGGED_VERSION_PREFIX=v

pargs=$(getopt -o "h,p:,t:,x:" -l "help,project-version:,tagged-version:,tagged-version-prefix:" -n "$0" -- "$@")
eval set -- "$pargs"
while true; do
  case "$1" in
    -h|--help)
        help_display $self
        exit 0
        ;;
    -p|--project-version)
        PROJECT_VERSION="$2"
        shift 2
        ;;
    -t|--tagged-version)
        TAGGED_VERSION="$2"
        shift 2
        ;;
    -x|--tagged-version-prefix)
        TAGGED_VERSION_PREFIX="$2"
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

PROJECT_VERSION=${PROJECT_VERSION:-"$(get_version_docker_safe)"}
TAGGED_VERSION=${TAGGED_VERSION:-"$CI_COMMIT_TAG"}

[ -z "$PROJECT_VERSION" ] && myexit --help 1 "Parameter PROJECT_VERSION is needed!"
[ -z "$TAGGED_VERSION" ] && myexit --help 1 "Parameter TAGGED_VERSION is needed!"


[ "${TAGGED_VERSION_PREFIX}$PROJECT_VERSION" != "${TAGGED_VERSION}" ] && \
    myexit 2 "Project version does not match the tag: '${TAGGED_VERSION_PREFIX}$PROJECT_VERSION' != '$TAGGED_VERSION'!"

exit 0
