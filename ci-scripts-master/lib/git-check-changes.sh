#!/bin/bash
#
# git-check-changes.sh [--source-branch=BRANCH] [--git-repository=PATH] [--debug] [--print-changes] -- PATH [PATH, ...]
#
# Check if changes were made in given paths compared to source branch.
# PASSES if changes were observed FAILS when there are no changes
# Checked path have to be relative to root of repository.
# Requires GIT binary
#
# Possible options are:
#   -h|--help                      Show this message and exists
#   -b|--source-branch=BRANCH      Name of branch for comparision (default `origin/master`)
#   -r|--git-repository=PATH       Path to root dir of GIT repository (default `./`)
#   -p|--print-changes             Print names of changed files
#   --debug                        Enables debug mode
#
# example:
#   git-check-changes.sh --source-branch="origin/master" --git-repository="/path/to/repo" -- /foo/bar /bar/foo
#


set -eo pipefail

[ -n "$TRACE" ] && set -x


# sourcing the lib
dir=$(dirname $(readlink -f $0))
source $dir/common.sh

SOURCE_BRANCH="origin/master"
GIT_REPOSITORY="./"
CHECK_PATHS="./"
PRINT_CHANGES="0"

# parsing command-line options
pargs=$(getopt -o "h,b:,r:,p" -l "source-branch:,help,git-repository:,debug,print-changes" -n "$0" -- "$@")
eval set -- "$pargs"

while true; do
  case "$1" in
    -h|--help)
        help_display $0
        exit 0
        ;;
    -b|--source-branch)
        SOURCE_BRANCH="$2"
        shift 2
        ;;
    -r|--git-repository)
        if [ ! -d "$2/.git" ]; then
            echo "Error specified path '$2' is not a GIT repository"
            exit 1
        fi
        GIT_REPOSITORY=$2
        shift 2
        ;;
    --debug)
        PRINT_CHANGES="1"
        set -x
        shift
        ;;
    -p|--print-changes)
        PRINT_CHANGES="1"
        shift
        ;;
    --)
        shift
        CHECK_PATHS=$@
        break
        ;;
    *)
        help_display $0
        myexit 1 "Parameter $1 is not recognized."
        ;;
  esac
done


pushd ${GIT_REPOSITORY} &>/dev/null
diff_output=$(git diff --name-only ${SOURCE_BRANCH} -- ${CHECK_PATHS})
popd &>/dev/null

if [ "${PRINT_CHANGES}" == "1" ]; then
    echo "Changed files:"
    echo "${diff_output}"
fi

[ $(echo "${diff_output}" | grep -v "^$" | wc -l) -gt 0 ]


