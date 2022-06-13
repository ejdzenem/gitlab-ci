#!/bin/bash
#
# semver_cut.sh [--version-prefix=PREFIX] [major|minor|patch|all|full]
#
# Read list of semantic versions from the stdin and prints them out sorted.
#
# You can specify to return only subpart of version:
#   * only major
#   * only major.minor
#   * only major.minor.patch
# Note that "pre-relased" version are filtered out for subparts defined above.
#
# Parameter 'all' and 'full' (as well as without parameter) returns all
# input versions.
#
# Full SemVer specification can be found: http://semver.org/
#
# Exit when input versions does not fit SemVer 2.0.0 specification.
#
# Gotchas:
#    * According to semver, following statement is true: 1.0.0-alpha.1 < 1.0.0-alpha.beta
#      Unfortunatelly our dummy comparator evaluates 1.0.0-alpha.1 > 1.0.0-alpha.beta
#    * In semver, 1.0.0+1 = 1.0.0+2
#      Unfortunatell our dummy comparator evalutes 1.0.0+1 < 1.0.0+2

set -eo pipefail

[ -n "$TRACE" ] && set -x

self=$(readlink -f $0)
dir=$(dirname $self)

VERSION_PREFIX=

source $dir/common.sh

pargs=$(getopt -o "h,p:" -l "help,version-prefix:" -n "$0" -- "$@")
eval set -- "$pargs"
while true; do
  case "$1" in
    -h|--help)
        help_display $self
        exit 0
        ;;
    -p|--version-prefix)
        VERSION_PREFIX="$2"
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

# sort semantic versions
# (see https://stackoverflow.com/questions/40390957/how-to-sort-semantic-versions-in-bash)
sorted_versions=$(sed "s/^$VERSION_PREFIX//gp;d" | sed '/-/!{s/$/_/}' | sort -V | sed 's/_$//')

invalid_versions=$(echo "$sorted_versions" | \
    egrep -v '^([1-9][0-9]*|0)\.([1-9][0-9]*|0)\.([1-9][0-9]*|0)([-+][0-9A-Za-z]+([-\.+][0-9A-Za-z]+)*)?$' || \
    true)
if [ -n "$invalid_versions" ]; then
    echo "ERROR: there are invalid semantic versions names: " \
        "$(echo $invalid_versions | tr "\n" ",")" 1>&2
    exit 2
fi

case "$1" in
    major)
        echo "$sorted_versions" | cut -f1 -d. | uniq
        ;;
    minor)
        echo "$sorted_versions" | awk -F. '{print $1 "." $2}' | uniq
        ;;
    patch)
        echo "$sorted_versions" | awk -F'[+-]' '{print $1}' | uniq
        ;;
    ''|all|full)
        echo "$sorted_versions"
        ;;
    *)
        myexit --help 1 "Not implemented: $1"
        ;;
esac
