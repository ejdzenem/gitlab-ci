#!/bin/bash
#
# gitlab-wait-for-pipeline-status.sh [OPTIONS] [ADDITIONAL_OPTIONS]
#
# Returns a final status of a given gitlab pipeline other than `running/pending`.
#
# Possible OPTIONS are:
#   -h|--help                         Show this message and exists.
#   --fail-retry-count   THRESHOLD    How many times the internal call of gitlab-pipeline-status.sh can fail. Default: 3
#   --timeout            TIMEOUT      Timeout in seconds for how long we should wait until the
#                                     pipeline status is not running. Default 60.
#   --retry-delay        DELAY        What delay should be introducted between pipeline status retries. In seconds, default: 10.
#   Everything after -- is consideres as ADDITIONAL_OPTIONS, and is passed as an argument to
#   script gitlab-pipeline-status.sh which is internally used.
#
# Example:
#   gitlab-wait-for-pipeline-status.sh --project-id 8379 --pipeline-id 427354 --token <my-private-access-token-to-gitlab-api>

set -eo pipefail

[ -n "$TRACE" ] && set -x

self=$(readlink -f $0)
dir=$(dirname $self)

# initialize global variables
TIMEOUT=60
RETRY_DELAY=10
FAIL_RETRY_COUNT=3

source $dir/common.sh

delegated_args=()
pargs=$(getopt -o "h,t:,p:,i:" -l "help,timeout:,fail-retry-count:,retry-delay:,project-id:,pipeline-id:,access-token:" -n "$0" -- "$@")
eval set -- "$pargs"
while true; do
  case "$1" in
    -h|--help)
        help_display $self
        $dir/gitlab-pipeline-status.sh --help
        exit 0
        ;;
    -t|--timeout)
        TIMEOUT="$2"
        shift 2
        ;;
    --fail-retry-count)
        FAIL_RETRY_COUNT="$2"
        shift 2
        ;;
    --retry-delay)
        RETRY_DELAY="$2"
        shift 2
        ;;
    --)
        shift
        break
        ;;
    *)
        delegated_args+=($1)
        shift
        ;;
  esac
done

fail_count=0
for i in $(seq 1 $RETRY_DELAY $TIMEOUT); do
    # we dont want to fail, if gitlab is unavailable for a second
    set +e
    state="$("$dir/gitlab-pipeline-status.sh" "${delegated_args[@]}")"
    exit_code=$?
    set -e
    if [ "$exit_code" -eq 0 ]; then
        if [[ "$state" =~ ^(success|failed|canceled|skipped)$ ]]; then
            echo $state
            exit 0
        elif [[ "$state" =~ ^(pending|running)$ ]]; then
            mylog "INFO: Pipeline is still in '$state' state" >&2
        else
            mylog "WARNING: Pipeline is still in unknown '$state' state" >&2
        fi
    elif [ "$exit_code" -eq 99 ]; then
        mylog "ERROR: Got error code $exit_code" >&2
        fail_count=$(( $fail_count+1 ))

        if [ $fail_count -gt "$FAIL_RETRY_COUNT" ]; then
            mylog "FATAL: Reached maximum number of failed retries ($FAIL_RETRY_COUNT), exiting" >&2
            exit 1
        fi
    else
        mylog "FATAL: $state" >&2
        exit 1
    fi

    sleep $RETRY_DELAY
done

mylog "Timeouted with last state: $state"

exit 1
