#!/bin/bash
#
# argocd.sh ACTION [OPTIONS...]
#
# Helps with common interactions with gitops repository and argocd.
#
# Supported ACTIONS are:
#   --clone                         Clone given gitops repository. If there is already a clone of this repository, it
#                                   will be cleaned and reused. Prints the path to the cloned repository to stdout.
#   --push                          Push any changes present in previously cloned repository. Does nothing
#                                   if there are no changes.
#   --wait                          Same as --push, but also wait until the application is sucessfully synced.
#
#   NOTE: At least one action must be specified.
#
# Possible OPTIONS are:
#   -h|--help                       Show this message and exists
#   -a|--app            APP_NAME    ArgoCD application name, required when using --wait.
#   -r|--repository     REPOSITORY  Gitlab project of gitops repository, e.g. 'sklik-backend/sklik.vydej/gitops-main'.
#                                   Only required with --clone.
#   -b|--branch         BRANCH      Which branch to use in gitops repo. Branch must already exist. Defaults to 'main'.
#   -m|--commit-message MSG         Commit message for changes pushed to gitops repo. Required when pushing changes.
#   -t|--timeout        NAME        Maximum waiting time for application to sync in seconds. Defaults to 300.
#
# The script requires following env variables to be set:
#     GITOPS_TOKEN        Read-write token for gitops repository.
#     ARGOCD_URL          Url of ArgoCD API, e.g. "argocd-vydej.production.sklik.iszn.cz:443"
#     ARGOCD_USER         ArgoCD user with API access.
#     ARGOCD_PASSWORD     Password or API token for ARGOCD_USER
#     GITLAB_USER_NAME    Username used for any commits to gitops repository (Gitlab CI set this to person who triggered the pipeline by default)
#     GITLAB_USER_EMAIL   Email used for any commits to gitops repository (Gitlab CI sets this to the email of person who triggered the pipeline by default)
#
# Example usage:
#
#     GITOPS_DIR=$(/ci/argocd.sh --clone --repository $MY_GITOPS_REPO)
#     # do any required changes in $GITOPS_DIR
#     ./argocd.sh --push --commit-message "Deploy $COMPONENT $VERSION in $NAMESPACE"$'\n\n'"Generated from $CI_PROJECT_URL/-/tree/$CI_COMMIT_SHA/$COMPONENT by $CI_JOB_URL"
#

set -eo pipefail

[ -n "$TRACE" ] && set -x


self="$(readlink -f "$0")"
dir="$(dirname "$self")"

ACTION=""
REPOSITORY=""
BRANCH="main"
APP_NAME=""
COMMIT_MESSAGE=""
TIMEOUT=300
GITOPS="${CI_PROJECT_DIR:-.}/_gitops"

source "$dir/common.sh"

argocd_clone_repository() {
    check_variable REPOSITORY "ERROR: Parameter --repository is required with --clone"
    check_variable GITOPS_TOKEN
    check_variable GITLAB_USER_NAME
    check_variable GITLAB_USER_EMAIL

    if [ -d "$GITOPS" ]; then
        #TODO: check if the repo url matches!
        git -C "$GITOPS" fetch
        git -C "$GITOPS" checkout "$BRANCH"
        git -C "$GITOPS" reset --hard "origin/$BRANCH"
        git -C "$GITOPS" clean -fxd .
    else
        git clone --depth 1 "https://gitlab-ci-token:${GITOPS_TOKEN}@gitlab.seznam.net/$REPOSITORY.git" "$GITOPS"
        git -C "$GITOPS" config user.email "$GITLAB_USER_EMAIL"
        git -C "$GITOPS" config user.name "$GITLAB_USER_NAME"
    fi
    echo "$GITOPS"
}

argocd_push_changes() {
    git -C "$GITOPS" add .
    if ! git -C "$GITOPS" diff-index --quiet --exit-code HEAD; then
        check_variable COMMIT_MESSAGE "ERROR: Commit message is required when pushing changes, use -m/--commit-message"
        git -C "$GITOPS" commit -m "$COMMIT_MESSAGE"
        git -C "$GITOPS" show --stat
        git -C "$GITOPS" push origin "$BRANCH"
        if [ "$1" = "wait" ]; then
            argocd_wait
        fi
    else
        mylog "No changes in gitops repository..."
    fi
}

argocd_wait() { # args: component namespace
    local REV DEADLINE
    DEADLINE=$(date -d +"${TIMEOUT}sec" +%s)
    REV="$(git -C "$GITOPS" rev-parse --short HEAD)"

    check_variable ARGOCD_URL
    check_variable ARGOCD_USER
    check_variable ARGOCD_PASSWORD
    argocd login "$ARGOCD_URL" --grpc-web --username "$ARGOCD_USER" --password "$ARGOCD_PASSWORD"

    check_variable APP_NAME "ERROR: Parameter --app is required when using --wait"
    mylog "Waiting for $APP_NAME to start..."
    # wait until argocd notices the new version
    until argocd app history "$APP_NAME" | grep -q "$REV"; do
        if [ "$(date +%s)" -lt "$DEADLINE" ]; then
            mylog "Waiting for argo to refresh ..."
            sleep 5
        else
            argocd app history "$APP_NAME"
            myexit 4 "ERROR: Waiting deadline for $REV in $APP_NAME exceeded!"
        fi
    done
    # wait until the application is synced and healthy
    argocd app wait "$APP_NAME" --health --sync --timeout $(( DEADLINE - $(date +%s) ))
}


pargs=$(getopt -o "h,a:,r:,b:,m:,t:" -l "help,app:,repository:,branch:,commit-message:,timeout:,clone,push,wait" -n "$0" -- "$@")
eval set -- "$pargs"
while true; do
  case "$1" in
    -h|--help)
        help_display "$self"
        exit 0
        ;;
    -a|--app)
        APP_NAME="$2"
        shift 2
        ;;
    -r|--repository)
        REPOSITORY="$2"
        shift 2
        ;;
    -b|--branch)
        BRANCH="$2"
        shift 2
        ;;
    -m|--commit-message)
        COMMIT_MESSAGE="$2"
        shift 2
        ;;
    -t|--timeout)
        TIMEOUT="$2"
        shift 2
        ;;
    --clone|--push|--wait)
        ACTION="${1/--/}"
        shift 1
        ;;
    --)
        shift
        break
        ;;
    *)
        help_display "$self"
        myexit 1 "Not implemented: $1"
        ;;
  esac
done

case "$ACTION" in
    clone)  argocd_clone_repository ;;
    push)   argocd_push_changes ;;
    wait)   argocd_push_changes wait ;;
    "")     myexit --help 1 "ERROR: One of --clone/--push/--wait params is required!" ;;
    *)      myexit 1 "ERROR: Unexpected action '$ACTION'!" ;;
esac
