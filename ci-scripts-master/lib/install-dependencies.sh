#!/bin/bash
# DEPRECATED - use install-ci-scripts.sh instead of this file
#
# install-dependencies.sh [-h|--help] [requirement-file]
#
# Installs ci-scripts dependencies
#
# Execute before using ci-scripts downloaded from gitlab pages
#
# Return code: 0/1 ~ pass/fail
#
# Possible OPTIONS are:
#   -h|--help                      Show this message and exists

set -eo pipefail

SCRIPT_FN=$(readlink -f $0)
APT_GET='apt-get -y -qq'

echo "WARNING: $SCRIPT_FN is deprecated, please use install-ci-scripts.sh instead." > /dev/stderr

source $(dirname ${SCRIPT_FN})/common.sh

if [ "$1" == "--help" -o "$1" == "-h" ]; then
    help_display ${SCRIPT_FN}
    exit 0
fi

[ -n "$TRACE" ] && set -x

REQUIREMENTS_FP=${1:-"$(dirname ${SCRIPT_FN})/depends.txt"}

test -s "${REQUIREMENTS_FP}"
${APT_GET} update
${APT_GET} install $(cat "${REQUIREMENTS_FP}")

# eof
