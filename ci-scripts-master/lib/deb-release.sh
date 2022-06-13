#!/bin/bash
#
# deb-release.sh OPTIONS PACKAGE [PACKAGE..]
#
# Pushes debian package to Seznam repository. It calls:
#   scp [SCP_ARGS] PACKAGE USER@HOST:SUITE
#
# Possible OPTIONS are
#   -h|--help                  Show this message and exists
#   -s|--suite=SUITE           To what suite should the package be released.
#                              (default: "", which means temporary repository)
#   -w|--wait=WAIT_SEC         Repoman works asynchroniously. If WAIT is non-zero,
#                              than the scripts waits until the upload process
#                              is finished approx. WAIT_SEC seconds. Default is 0
#   -u|--user=USER             User to use to copy the deb package (default: sklik.ci)
#   --host=HOST                Host where to copy the deb package (default: repo.dev.dszn.cz)
#   --scp-args=ARGS            Additional arguments passed to scp (can be used to pass
#                              identity file, default: "")
#
# NOTE: deb-release.sh is also sensitive to following environment variables
#   CI_SCRIPTS_REPO_USER=REPO_USER=USER        Equals to --user value
#   CI_SCRIPTS_REPO_HOST=REPO_HOST=HOST        Equals to --host value
#   REPO_PRIVATE_KEY=KEY       KEY will be used to create a private key file to access the repository
# NOTE, that OPTIONS have more priority than env variables
#
# Example:
#   deb-release.sh --suite wheezy-testing --wait=100 szn-sklik-adminserver_2.8.4_all.deb
#   REPO_PRIVATE_KEY="-----BEGIN OPENSSH....." deb-release.sh --suite wheezy-testing --wait=100 szn-sklik-adminserver_2.8.4_all.deb

[ -n "$TRACE" ] && set -x

self=$(readlink -f $0)
dir=$(dirname $self)

PACKAGES=
SUITE=
WAIT_SEC=0
HOST=${CI_SCRIPTS_REPO_HOST:-"${REPO_HOST:-"repo.dev.dszn.cz"}"}
USER=${CI_SCRIPTS_REPO_USER:-"${REPO_USER:-"sklik.ci"}"}
SCP_ARGS=

source $dir/common.sh

pargs=$(getopt -o "h,s:,w:,u:" -l "help,suite:,wait:,host:,user:,scp-args:" -n "$0" -- "$@")
eval set -- "$pargs"
while true; do
  case "$1" in
    -h|--help)
        help_display $self
        exit 0
        ;;
    -s|--suite)
        SUITE="$2"
        shift 2
        ;;
    -w|--wait)
        WAIT_SEC="$2"
        shift 2
        ;;
    --host)
        HOST="$2"
        shift 2
        ;;
    --user)
        USER="$2"
        shift 2
        ;;
    --scp-args)
        SCP_ARGS="$2"
        shift 2
        ;;
    --)
        shift
        break
        ;;
    *)
        help_display $self
        myexit 1 "Not implemented: $1"
        ;;
  esac
done

PACKAGES="$@"

# if user was passed, use non-default => concatenate with @
[ -n "$USER" ] && USER="$USER@"

# if REPO_PRIVATE_KEY environment variable was passed, create tmpfile for it
private_key_file=
if [ -n "$REPO_PRIVATE_KEY" ]; then
    echo "INFO: SSH ${USER}${HOST} private key (in REPO_PRIVATE_KEY env. variable) is specified"
    private_key_file=$(mktemp)
    chmod 600 $private_key_file
    # we trim the key because gitlab pastes space inside
    echo "$REPO_PRIVATE_KEY" | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//' > $private_key_file
    SCP_ARGS="-i $private_key_file $SCP_ARGS"
else
    echo -n "WARNING: SSH ${USER}${HOST} private key (in REPO_PRIVATE_KEY env. variable) is NOT specified (empty). "
    echo "Check your project and/or project group env. variable propagation (existence, protected mode, repository protected branches/tags)."
fi

scp_output=$(scp \
    -o "PasswordAuthentication=no" \
    -o "StrictHostKeyChecking=yes" \
    $SCP_ARGS $PACKAGES \
    "${USER}$HOST:$SUITE" 2>&1)
[ "$?" -ne 0 ] && myexit 3 "$scp_output"

# cleanup temp files
test -e "$private_key_file" && rm "$private_key_file"

packages=$(echo "$scp_output" | sed -n 's/^PACKAGES: \(.*\)$/\1/p')
echo "PACKAGES: $packages"
echo "$packages" > deb-release.PACKAGES

task=$(echo "$scp_output" | sed -n 's/^TASK: \(.*\)$/\1/p')
echo "TASK: $task"
echo "$task" > deb-release.TASK

apt=$(echo "$scp_output" | sed -n 's/^APT: \(.*\)$/\1/p')
echo "APT: $apt"
echo "$apt" > deb-release.APT

# register trap function so during following iteration we can exit easily
trap "exit 11" SIGINT SIGTERM

task_status=
# wait until the repoman says the packages is ready
for i in $(seq 1 $WAIT_SEC); do
    # get state
    repoman_answer=$(timeout 5s curl -L -H 'Accept: application/json' -s "$task" 2>&1)
    task_status=$(echo $repoman_answer | jq -r .status)
    case "$task_status" in
        "")
            echo "$repoman_answer"
            ;;
        "done")
            echo "Package is ready"
            break
            ;;
        *)
            echo "Try #$i: Task's status is: '$task_status', expecting 'done'"
            ;;
    esac
    sleep 1
done

[ "$WAIT_SEC" -ne 0 -a "$task_status" != "done" ] && exit 10

exit 0
