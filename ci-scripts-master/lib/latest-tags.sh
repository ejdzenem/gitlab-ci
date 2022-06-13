#!/bin/bash
#
# latest-tags.sh [VERSION_PREFIX]
#
# Returns list of major versions and latest.
#
# Read all git tags starting with prefix VERSION_PREFIX folloved by number and
# return upper stream version. By default VERSION_PREFIX is 'v'
#
# For example:
#
#  Given following versions (tags in git repository):
#     v1.0, v1.1, v1.2, v1.3, v2.0 and v2.1
#  then function returns following results:
#   get_latest_tags v1.0.0  => ""
#   get_latest_tags v1.1.0  => ""
#   get_latest_tags v1.1.1  => "v1.1"
#   get_latest_tags v1.2.0  => "v1.2"
#   get_latest_tags v1.3.0  => "v1,v1.3"
#   get_latest_tags v2.0.0  => "v2.0"
#   get_latest_tags v2.1.0  => "v2,v2.1,latest"
#
# NOTICE: Current implementation do not work for patch version.
#

set -eo pipefail

[ -n "$TRACE" ] && set -x

self=$(readlink -f $0)
dir=$(dirname $self)

source $dir/common.sh

if [ "$1" == "--help" ]; then
    help_display $self
    exit 0
fi

version_prefix=${1-"v"}
current_version="$(get_version_semver_safe)"
prefixed_current_version=$version_prefix$current_version
current_major=$(echo "$current_version" | $dir/semver-cut.sh major)
current_minor=$(echo "$current_version" | $dir/semver-cut.sh minor)
current_patch=$(echo "$current_version" | $dir/semver-cut.sh patch)

RELEASE_TAGS=${RELEASE_TAGS:-$(git fetch --tags --quiet; git tag --list "${version_prefix}[0-9]*")}

if ! echo "$RELEASE_TAGS" | grep -q "^$prefixed_current_version$"; then
    echo "ERROR: current version '$prefixed_current_version' is not in git tags '$(echo "$RELEASE_TAGS"| tr "\n" ",")'!" 1>&2
    exit 1
fi


next_versions_patch=$(echo "$RELEASE_TAGS"| $dir/semver-cut.sh patch --version-prefix="$version_prefix" | grep -A1 "^$current_version$" || true)

if ! echo "$next_versions_patch" | grep -q "^$current_version$"; then
    # current version is pre-release, exit.
    exit
fi

next_version_patch=$(echo "$next_versions_patch" | sed -n 2p)
next_version_minor=$(echo "$next_version_patch" | $dir/semver-cut.sh minor)
next_version_major=$(echo "$next_version_patch" | $dir/semver-cut.sh major)


if [ -z "$next_version_patch" ]; then
    echo "$current_major,$current_minor,latest"
    exit 0
fi

if [ "$current_minor" != "$next_version_minor" ]; then
    if [ "$current_major" == "$next_version_major" ]; then
        echo "$current_minor"
    else
        echo "$current_major,$current_minor"
    fi
    exit 0
fi

if [ "$current_major" != "$next_version_major" ]; then
    echo "$current_major"
    exit 0
fi

echo "WARN: Releasing old version!" 1>&2
