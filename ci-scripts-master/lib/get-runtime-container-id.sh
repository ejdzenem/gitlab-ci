#!/bin/bash
#
# get-runtime-container-id.sh [-h|--help]
#
# Gets docker container ID when executed in docker container and returns it on stdout.
#
# Intended usuage is in CI pipeline to manipulate with current container.
#
# Return code: 0 (in container)
#              1 (not in container)
#
# Possible OPTIONS are:
#   -h|--help                      Show this message and exists

set -eo pipefail

SCRIPT_FN=$(readlink -f $0)
CGROUP_FN="/proc/self/cgroup"

source $(dirname ${SCRIPT_FN})/common.sh

[ -n "$TRACE" ] && set -x

if [ "$1" == "--help" -o "$1" == "-h" ]; then
    help_display ${SCRIPT_FN}
    exit 0
fi

regexp_part="docker[/-]([0-9a-fA-F]{16,})"
if grep -E -q "${regexp_part}" ${CGROUP_FN}; then
    grep -E "${regexp_part}" ${CGROUP_FN} | sed -r "s#^.+${regexp_part}.*#\1#g" | tail -1
else
    exit 1
fi
