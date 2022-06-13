#!/bin/bash

[ -n "$TRACE" ] && set -x

# TODO drop obsolete CI_SCRIPTS_DOCKER_CI_REGISTRY env variable
DOCKER_CI_REGISTRY=${CI_SCRIPTS_DOCKER_CI_REGISTRY:-${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY:-"docker.ops.iszn.cz"}}
# TODO drop obsolete CI_SCRIPTS_DOCKER_REGISTRY env variable
DOCKER_REGISTRY=${CI_SCRIPTS_DOCKER_REGISTRY:-${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY:-"docker.ops.iszn.cz"}}
PRODUCTION_DOCKER_REGISTRY=${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY:-${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY:-"docker.ops.iszn.cz"}}
GITLAB_HOSTNAME=${CI_SCRIPTS_GITLAB_HOSTNAME:-"gitlab.seznam.net"}
GITLAB_URL=${CI_SCRIPTS_GITLAB_URL:-"https://${GITLAB_HOSTNAME}"}
GITLAB_USER_LOGIN_URL=${CI_SCRIPTS_GITLAB_USER_LOGIN_URL:-"https://${GITLAB_HOSTNAME}/api/v4/users"}
KUBECTL_BIN=${KUBECTL_BIN:-kubectl}

# assert on invalid global ci-scripts variables
if [[ "${KUBECTL_BIN}" =~ --(password|token) ]]; then
    echo "ERROR: KUBECTL_BIN environment variable should not specify any credentials to avoid leaking them at multiple places including CI pipelines or kubernetes metadata" >&2
    echo "       use ci-scripts' kubernetes-ci-init.sh instead or equivalent kubectl config ... approach" >&2
    exit 1
fi

# retrieve git branch
function get_git_branch() {
    git symbolic-ref --short HEAD 2> /dev/null
}

# retrieve git tag, prefer preset CI variables over calling git command
function get_git_tag() {
    echo ${CI_COMMIT_TAG:-$(git describe --exact-match --tags $(get_git_revision) 2> /dev/null)}
}

# retrieve version from git tag
# works with semantic versioned tags, see https://semver.org/
function get_version_from_git_tag(){
    local tag=$(get_git_tag)
    [[ $tag =~ ^.*[0-9]+.[0-9]+.[0-9]+ ]] && echo $tag | sed -E 's/^([a-zA-Z0-9-]+[-\/])?v?//' || echo ''
}

# retrieve git commit revision, prefer preset CI variables over calling git command
function get_git_revision() {
    local git_commit=${CI_COMMIT_SHA:-$CI_BUILD_REF}
    echo ${git_commit:-$(git log HEAD --pretty=format:'%H' -n 1 2> /dev/null)}
}

function get_deb_version() {
    if which dpkg-parsechangelog >& /dev/null; then
        dpkg-parsechangelog 2> /dev/null | grep -m1 "^Version:" | awk '{print $2}'
    else
        # for wheezy support
        head -n1 debian/changelog 2> /dev/null | awk '{print $2}' | tr -d "()"
    fi
}

function get_npm_version() {
    jq -r '.version // empty' package.json 2> /dev/null
}

# retrieve version from Cargo.toml https://doc.rust-lang.org/cargo/reference/manifest.html#the-version-field
# It uses semver definition, see https://semver.org/
function get_cargo_version() {
    local cargo_file="${1:-'Cargo.toml'}"
    egrep 'version\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+(-.+)?)"' "${cargo_file}" 2>/dev/null |
        sed -r 's/.*version\s*=\s*"(.*)".*/\1/m'
}

function get_version_docker_safe() {
    get_version | tr '~+' '-'
}

# get_version_semver_safe()
#   makes sure thet debian version pre-release character (~) is replaced to semver pre-release one (-)
function get_version_semver_safe() {
    get_version | tr '~' '-'
}

function get_version_from_dockerfile() {
    egrep '^[^#]*org.label-schema.version="([0-9]+\.[0-9]+\.[0-9]+(-.+)?)"' Dockerfile 2> /dev/null | \
        sed -r 's/.*org.label-schema.version="(.*)".*/\1/m'
}

# retrieve version from CHANGELOG.md file https://keepachangelog.com/en/1.0.0/
# function is looking for the first occurence of "## [1.2whatever] - 2222-2-22 22:22"
# string inside of brackets is returned
function get_version_from_changelog_md() {
    local changelog_file=${1:-"CHANGELOG.md"}
    if [ -f "${changelog_file}" -a -s "${changelog_file}" ]; then
        local line_with_unreleased_tag=$(grep -m 1 -Ein "^##[ \t]+\[Unreleased.*\]" "${changelog_file}")
        local line_with_version_tag=$(grep -m 1 -En "^##[ \t]+\[[ \t]*[0-9]+\.[0-9]+\.[0-9]+[^]]*\]" "${changelog_file}")

        # If [Unreleased] tag is present, check if there are any changes not included in the actual release.
        # Shortly, if there is any text between lines with [Unreleased] and first [1.2.3] version tag, then function fails.
        if [ ! -z "$line_with_unreleased_tag" ]; then
            local line_from=$(echo $line_with_unreleased_tag | sed -e 's/:.*//g')
            local line_to=$(($(echo $line_with_version_tag | sed -e 's/:.*//g') - 1 ))

            if [ $line_from -eq $line_to ]; then
                myexit 1 "Error: [Unreleased] tag should be separated from the last release section by a new line."
            fi
            if [ $line_from -gt $line_to ]; then
                myexit 1 "Error: [Unreleased] tag has to be defined before the first version tag."
            fi

            while read line; do
                if [[ $line =~ [^[:space:]] ]]; then
                    myexit 1 "Error: There are changes in the [Unreleased] part of a changelog, which are already commited.
Move them to the part of the changelog which is related to the changes or raise the version number."
                fi
            done < <(head -$line_to  "${changelog_file}" | tail -$(($line_to - $line_from)))
        fi

        echo $line_with_version_tag | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+[^] ]*'
    fi
}

function get_version() {
    for version in \
        "$VERSION" \
        "$([ -x "$PWD/ci/version.sh" ] && bash "$PWD/ci/version.sh")" \
        "$(get_deb_version)" \
        "$(make _print-VERSION 2>/dev/null)" \
        "$(make _print-version 2>/dev/null)" \
        "$(get_npm_version)" \
        "$(get_cargo_version)" \
        "$(cat "$PWD/VERSION" 2>/dev/null)" \
        "$(get_version_from_changelog_md)" \
        "$(get_version_from_dockerfile)" \
        "$(get_version_from_git_tag)" \
        "$(get_git_revision)";
    do
        test -n "$version" && break
    done
    if [ "$(echo $version | wc -w)" -ne 1 ]; then
        myexit 1 "ERROR: version '$version' can not contain whitespaces or be empty!"
    fi
    echo $version
}

# joins string using deliminator
# example usage:
#    $ _join - foo bar x y
#    > foo-bar-x-y
function _join() {
    local delim=$1
    shift
    local result=

    for i in "$@"; do
        test -z "$i" && continue
        test -n "$result" && result="${result}$delim"
        result="${result}$i"
    done
    echo $result
}

function get_build_uniq_id() {
    _join "_" $(get_version_docker_safe) $(get_git_revision) \
        ${CI_PIPELINE_ID:-$(hostname)}
}

function get_component_from_dockerfile() {
    egrep '^[^#]*org.label-schema.name="([a-zA-Z0-9_-]*)"\s.*' Dockerfile 2> /dev/null | \
        sed -r 's/.*org.label-schema.name="([a-zA-Z0-9_-]*)".*/\1/m'
}

function get_component() {
    for component in \
        "$COMPONENT" \
        "$([ -x "$PWD/ci/component.sh" ] && bash "$PWD/ci/component.sh")" \
        "$(make _print-COMPONENT 2>/dev/null)" \
        "$(make _print-component 2>/dev/null)" \
        "$(get_component_from_dockerfile)";
    do
        test -n "$component" && break
    done
    if [ "$(echo $component | wc -w)" -ne 1 ]; then
        myexit 1 "ERROR: component '$component' can not contain whitespaces or be empty!"
    fi
    echo $component
}

# help_display <filename>
#   print script usage by printing the commented <filename> head section
function help_display () {
    sed '/^[^#]/,$d' $1 | sed '1,1d;2,$s/^# \?//'
}

# (possibly) formatted echo
function mylog {
    #echo `date --iso-8601=seconds` "$@"
    echo "$@"
}


# myexit ( <ecode> [exiting-message] )
#   exiting with message
function myexit () {
    local ecode=0
    local include_help=

    if [ $1 == '--help' ]; then
        shift
        include_help=1
    fi

    [ "$#" -gt 0 ] && \
      ecode=$1

    if [ "$#" -gt 1 ]; then
        shift
        mylog "$@" 1>&2
    fi

    [ -n "$include_help" ] && help_display $(readlink -f $0) 1>&2
    exit ${ecode}
}

# check_variable ( <variable-name> [exiting-message] )
#   Checks that variable is non-empty and exits with an error if it isn't.
check_variable() {
    if [ -z "${!1}" ]; then
        myexit 3 "${2:-ERROR: $1 is empty or unset}"
    fi
}

# detect_docker_server_api_version ()
#   detects maximum supported docker server API version
#   Exits with following reply:
#     * stdout "", exit code 0 - docker just works out of box (no API adjustment needed)
#     * stdout <api-version>, exit code 0 - API adjustment needed, then docker works
#     * stdout "", exit code 1 - docker does not work (server API detection did not help or failed)
function detect_docker_server_api_version() {
    local docker_msg_regexp='client version [^ \t]+ is too new. Maximum supported API version is [^ \t]+'
    local docker_info_reply=

    if docker_info_reply=$(${DOCKER_BIN:-docker} info 2>&1); then
        return 0
    else
        if echo "${docker_info_reply}" | grep -Eq "${docker_msg_regexp}"; then
            target_api_version=$(echo "${docker_info_reply}" | grep -Eo "${docker_msg_regexp}" | awk '{printf $NF}')
            if DOCKER_API_VERSION="${target_api_version}" ${DOCKER_BIN:-docker} info &>/dev/null; then
                echo -n "${target_api_version}"
                return 0
            fi
        fi
    fi
    return 1
}

# ensure_docker_env
#   assert container client is functional
function ensure_docker_env() {
    local docker_server_api_version=
    if ! ${DOCKER_BIN:-docker} info &>/dev/null; then
        # try to detect docker server API version if not defined
        if docker_server_api_version="$(detect_docker_server_api_version)"; then
            export DOCKER_API_VERSION="${docker_server_api_version}"
            if ${DOCKER_BIN:-docker} info &>/dev/null; then
                mylog "WARNING: ensure_docker_env() switched docker into DOCKER_API_VERSION=${DOCKER_API_VERSION} mode"
            else
                myexit 1 "Missing functional docker engine... exiting (DOCKER_API_VERSION=${DOCKER_API_VERSION} detection did not help)"

            fi
        else
            myexit 1 "Missing functional docker engine... exiting"
        fi
    fi
}

function ensure_docker_login() {
    local server="${1}"
    local username="${2}"
    local password_file="${3}"

    if [ -z "${username}" -o -z "${password_file}" ]; then
        mylog "docker login skipped (no credentials provided)"
        return 0
    fi

    if [ -z "${server}" ]; then
        myexit 1 "docker login failed (no server provided)"
    fi

    # can not use --password-stdin because docker is broken and complains:
    # Error: Cannot perform an interactive login from a non TTY device
    if ${DOCKER_BIN:-docker} login --password "$(<${password_file})" --username "${username}" "$server"; then
        mylog "docker login succeeded (${username}@${server})"
        return 0
    fi

    myexit 1 "docker login failed (${username}@${server}, error code $?)"
}

function get_docker_registry()  {
    echo $DOCKER_REGISTRY
}
function get_docker_namespace() {
    echo ${DOCKER_REGISTRY_NAMESPACE_EXPLICIT:-${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_NAMESPACE:-${DOCKER_NAMESPACE}}}
}
function get_docker_tag() {
    echo "${TAG:-$(get_version_docker_safe)}"
}

function get_docker_image_name() {
    local registry=${1:-$(get_docker_registry)}
    local namespace=${2:-$(get_docker_namespace)}
    local component=${3:-$(get_component)}
    local tag=${4:-$(get_docker_tag)}

    echo "$registry/$namespace/$component:$tag"
}

# get_docker_image_digest <image-name>
# example[s]:
#   $ get_docker_image_digest docker.dev.dszn.cz/generic/ci-scripts:latest
#   sha256:0d2168f6359eace4412ce48f1dd97219b9e1b5c4949fbb13bdf52acbc81baa9d
function get_docker_image_digest() {
    ${DOCKER_BIN:-docker} images --format '{{ .Repository }}:{{ .Tag }} {{ .Digest }}' --digests | grep -E "^$1 " | awk '{print $2}'
}


function get_ci_docker_registry() {
    echo $DOCKER_CI_REGISTRY
}
function get_ci_docker_tag() {
    get_build_uniq_id
}

function get_ci_docker_image_name() {
    get_docker_image_name \
        "${1:-$(get_ci_docker_registry)}" \
        "${2:-$(get_docker_namespace)}" \
        "${3:-$(get_component)}" \
        "${4:-$(get_ci_docker_tag)}"
}

function docker_image_exists() {
    _docker_image_exists "$(get_docker_registry)" "$(get_docker_namespace)" \
        "$(get_component)" "$(get_docker_tag)"
}

function docker_ci_image_exists() {
    _docker_image_exists "$(get_ci_docker_registry)" "$(get_docker_namespace)" \
        "$(get_component)" "$(get_ci_docker_tag)"
}

# checks whether docker image exists in docker registry
# returns with 0 when the image does NOT exist
function _docker_image_exists() {
    registry=$1
    namespace=$2
    component=$3
    tag=$4

    registry_http_code=$(curl -L -s -o /dev/null -w '%{http_code}' \
        "https://$registry/v2/$namespace/$component/manifests/$tag")

    if [ "$?" != "0" ]; then
        return 3
    elif [ "${registry_http_code:0:1}" == "4" ]; then
        return 0
    elif [[ "${registry_http_code:0:1}" =~ [23] ]]; then
        return 1
    else
        return 2
    fi
}

function in_ci() {
    [ -n "$CI" ]
}

# get_kubectl_version()
#   Gets "sanitized" kubectl client version (e.g. v1.16.6-dirty -> 1.16.6).
function get_kubectl_version() {
    ${KUBECTL_BIN} version --client --output json 2> /dev/null \
        | jq -r '.clientVersion.gitVersion' \
        | sed -E 's/^v([0-9]+\.[0-9]+\.[0-9]+).*$/\1/'
}


# hide_secret ([regexp-with-group] [fill-character])
#   filters stdin stream hiding secrets selected by [regexp-with-group] group #1 with character [fill-character] to stdout
#   argument defaults:
#   * [regexp-with-group] defaults to "(.+)"
#   * [fill-character] defaults to "*"
#
# Notes:
#   * if arguments are not supplied, then everything is kept secret
#   * if more than single regexp group is given then the just first group is used
#
# exit code:
#   * 2 invalid [regexp-with-group] argument
#   * 0 otherwise
# example: $ echo 'token: ffdsfdsfdsf' |  hide_secret 'token:[ \t]*(.+)$' '*'
#          token: ***********
function hide_secret () {
    gawk -r -v "ch=${2:-"*"}" -v "re=${1:-"(.+)"}" \
      '{m=match($0,re,ma); \
        if((m>0)&&(ma[1,"length"]>0)){printf("%s%s%s\n",substr($0,1,ma[1,"start"]-1),genstr(ch,ma[1,"length"]),substr($0,ma[1,"start"]+ma[1,"length"]))}else{print}} \
        function genstr(ch,cn){rstr="";for(_i=0;_i<cn;_i++){rstr=sprintf("%s%s",rstr,ch)}return(rstr)}'
}

# join_files FILE [FILE..]
#   Imagine calling `cat FILE [FILE..]' with exception that if files contain no newline at the
#   end of file, it is added to it to ensure that concatenating is done securely.
function cat_files_secure() {
    awk '{print}' "$@"
}

# repeat_for_ecode <ecode> <timeout> <step-duration> <cmd-to-execute>
#   waits for given exit code <ecode> while executing the <cmd-to-execute>
#   example: repeat_for_ecode 0 30 1 mysql -u root -P ${c_port} -h "ip6-localhost" -e "/* ping */ SELECT 1"
function repeat_for_ecode() {
  local exp_ecode=$1
  shift
  local timeout=$1
  shift
  local sleep=$1
  shift
  local retcode=
  local ts_a=${SECONDS}
  local flags=$-
  set +e
  while true; do
    "$@"
    if [ "$?" == "${exp_ecode}" ]; then
      retcode=0
      break
    fi
    [ "${SECONDS}" -gt $(( ${ts_a} + ${timeout} )) ] && \
      break
    sleep $sleep
  done
  [ -z "${retcode}" ] && retcode=1

  [[ "${flags}" =~ e ]] && set -e
  return ${retcode}
}

# split_yaml <file>
#   Checks if yaml file contains multiple yaml fragments in which case it splits them
#   into separate files. The file names are indexed by appending -0, -1, ... to the original
#   name. The original file is deleted after splitting.
function split_yaml() {
    # check if the file needs to be splitted
    grep -q '^---$' "$1" || return 0

    csplit --suppress-matched --elide-empty-files --prefix "${1/.yaml/}" --suffix-format "-%02d.yaml" "$1" '/^---/' '{*}'
    mv -f "$1" "$1.orig"
}

function echo_stderr() {
    echo "$@" >&2
}


# docker_image_copy_pull_tag_push <src-image> <dst-image> [src-image-digest] [overwrite-ena]
#   copies <src-image> to <dst-image> (using docker pull+tag+push)
#   optionally verifies [src-image-digest]
#   allows overwriting destination image if [overwrite-ena] is 1 or true
function docker_image_copy_pull_tag_push() {
    local src_image="$1"
    local dst_image="$2"
    local src_digest="$3"
    local dst_overwrite_ena=false
    [ "$4" == "1" -o "${4,,}" == "true" ] && dst_overwrite_ena=true
    local docker_bin="${DOCKER_BIN:-"docker"}"
    local src_digest_detected=
    local dst_digest_detected=

    if [ -z "${src_image}" ]; then
        echo_stderr "${FUNCNAME[0]}(): Source image not specified!"
        return 1
    fi
    if [ -z "${dst_image}" ]; then
        echo_stderr "${FUNCNAME[0]}(): Destinantion image not specified!"
        return 1
    fi

    if ! ${docker_bin} pull "${src_image}"; then
        echo_stderr "${FUNCNAME[0]}(): Source image ${src_image} pull failed!"
        return 2
    fi

    # check source image content
    src_digest_detected=$(${docker_bin} inspect "${src_image}" | jq -r '.[0].RepoDigests[0]' | awk -F@ '{print $2}')
    if [ -z "${src_digest_detected}" ]; then
        echo_stderr "${FUNCNAME[0]}(): Source image ${src_image} content digest detection failed!"
        return 3
    fi

    if [ -n "${src_digest}" -a "${src_digest}" != "${src_digest_detected}" ]; then
        echo_stderr "${FUNCNAME[0]}(): Source image ${src_image} has different content than expected (got:${src_digest_detected} != expected:${src_digest})"
        return 4
    fi

    # check destination image presence and content
    if ${docker_bin} pull "${dst_image}" 2> /dev/null ; then
        dst_digest_detected=$(${docker_bin} inspect "${dst_image}" | jq -r '.[0].RepoDigests[0]' | awk -F@ '{print $2}')
    fi

    if [ -n "${dst_digest_detected}" ]; then
        # destination image exists
        if [ "${src_digest_detected}" == "${dst_digest_detected}" ]; then
            # destination image exists and has same content (regardless of check enforcement)
            return 0
        elif [ "${dst_overwrite_ena}" == "false" ]; then
            echo_stderr "${FUNCNAME[0]}(): Source image ${src_image} and destination image ${dst_image} exist with different content (${src_digest_detected} != ${dst_digest_detected}), refusing to override!"
            return 5
        fi
    fi

    if ! ${docker_bin} tag "${src_image}" "${dst_image}"; then
        echo_stderr "${FUNCNAME[0]}(): ${src_image} -> ${dst_image} docker tagging failed!"
        return 6
    fi

    if ! ${docker_bin} push "${dst_image}"; then
        echo_stderr "${FUNCNAME[0]}(): docker push ${dst_image} failed!"
        return 7
    fi
}

# generate_curl_credentials( <username> <password-file> )
function generate_curl_credentials() {
    echo -n "$1:"
    cat "$2"
}

# generate_curl_credentials_for_docker_image_project( <docker-image> )
#   generates curl auth file for docker registry project access where <docker-image> belongs to
#   tests which CI_SCRIPTS_*_DOCKER_REGISTRY* env variables to use
function generate_curl_credentials_for_docker_image_project() {
    local image="$1"
    if [[ -n "${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY}" && \
          -n "${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_NAMESPACE}" && \
          -n "${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_USER}" && \
          -n "${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_PASSWORD_FILE}" && \
          "${image}" =~ ^${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY}/${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_NAMESPACE}[:/] ]]; then
        echo -n "user = ${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_USER}:"
        cat "${CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_PASSWORD_FILE}"
    elif [[ -n "${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY}" && \
            -n "${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_NAMESPACE}" && \
            -n "${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_USER}" && \
            -n "${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_PASSWORD_FILE}" && \
          "${image}" =~ ^${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY}/${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_NAMESPACE}[:/] ]]; then
        echo -n "user = ${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_USER}:"
        cat "${CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_PASSWORD_FILE}"
    fi
}


# docker_image_copy <src-image> <dst-image> [src-image-digest] [overwrite-ena]
#   copies <src-image> to <dst-image> (using docker pull+tag+push or retag)
#   optionally verifies [src-image-digest]
#   allows overwriting destination image if [overwrite-ena] is 1 or true
function docker_image_copy_retag () {
    local src_image="$1"
    local dst_image="$2"
    local src_digest="$3"
    local dst_overwrite_ena=false
    [ "$4" == "1" -o "${4,,}" == "true" ] && dst_overwrite_ena=true
    local response=
    local src_digest_detected=
    local dst_digest_detected=
    if [ -z "${src_image}" ]; then
        echo_stderr "${FUNCNAME[0]}(): Source image not specified!"
        return 1
    fi
    if [ -z "${dst_image}" ]; then
        echo_stderr "${FUNCNAME[0]}(): Destinantion image not specified!"
        return 1
    fi

    # 1. test src image is present, receive image hash, test API access
    local src_image_query_url="https://$(echo -n "${src_image}" | sed -r 's#/#/api/repositories/#;s#:#/tags/#')"
    if ! response=$(curl -L -K <(generate_curl_credentials_for_docker_image_project "${src_image}") "${src_image_query_url}"); then
        echo_stderr "${FUNCNAME[0]}(): Source image ${src_image} presence detection failed!"
        return 2
    fi
    src_digest_detected=$(echo -n "${response}" | jq -r '.digest')
    if [ "${src_digest_detected}" == "null" -o -z "${src_digest_detected}" ]; then
        echo_stderr "${FUNCNAME[0]}(): Source image ${src_image} content digest detection failed!"
        return 3
    fi

    if [ -n "${src_digest}" -a "${src_digest}" != "${src_digest_detected}" ]; then
        echo_stderr "${FUNCNAME[0]}(): Source image ${src_image} has different content than expected (got:${src_digest_detected} != expected:${src_digest})"
        return 4
    fi

    local dst_image_query_url="https://$(echo -n "${dst_image}" | sed -r 's#/#/api/repositories/#;s#:#/tags/#')"
    if response=$(curl -L -K <(generate_curl_credentials_for_docker_image_project "${dst_image}") "${dst_image_query_url}"); then
        dst_digest_detected=$(echo -n "${response}" | jq -r .digest)
        [ "${dst_digest_detected}" == "null" ] && dst_digest_detected=""
    fi

    if [ -n "${dst_digest_detected}" -a "${src_digest_detected}" == "${dst_digest_detected}" ]; then
        # destination image exists and has same content (regardless of check enforcement)
        return 0
    fi

    # 2. retag action
    local retag_query_url="https://$(echo -n "${dst_image}" | sed -r 's#/#/api/repositories/#;s#:.+$#/tags#')"
    local dst_image_tag=$(echo -n "${dst_image}" | sed -r 's#^[^:]+:##')
    local src_image_project_repository="$(echo -n "${src_image}" | sed -r 's#^[^/]+/##;s#:.+$##')"
    local retag_data="$(printf '{"tag":"%s","src_image":"%s:%s","override":%s}' "${dst_image_tag}" \
                          "${src_image_project_repository}" "${src_digest_detected}" "${dst_overwrite_ena}")"
    response='{"code":500,"message":"Internal Server Error"}'
    if response=$(curl -L -K <(generate_curl_credentials_for_docker_image_project "${dst_image}") \
                       -H 'Accept: application/json' -H 'Content-Type: application/json' \
                       --data-raw "${retag_data}" "${retag_query_url}"); then
        local response_code="$(echo -n "${response}" | jq -r ".code")"
        if [[ -z "${response}" || "${response_code}" =~ ^2[0-9][0-9]$ ]]; then
            # when Harbor succeeds to retag image leaves response empty (bug?)
            return 0
        else
            echo_stderr "${FUNCNAME[0]}(): Source image ${src_image} retag to ${dst_image} failed!"
            echo_stderr "${response}"
            return 5
        fi
    else
        echo_stderr "${FUNCNAME[0]}(): Source image ${src_image} retag to ${dst_image} failed!"
        return 6
    fi
}


# docker_image_copy <src-image> <dst-image> [src-image-digest] [overwrite-ena]
#   copies <src-image> to <dst-image> (using docker pull+tag+push or retag)
#   optionally verifies [src-image-digest]
#   allows overwriting destination image if [overwrite-ena] is 1 or true
function docker_image_copy() {
    local src_image_registry_host=$(echo -n "${src_image}" | awk -F/ '{printf $1}')
    local dst_image_registry_host=$(echo -n "${dst_image}" | awk -F/ '{printf $1}')

    if [ "${src_image_registry_host}" == "${dst_image_registry_host}" -a \
         "${CI_SCRIPTS_DOCKER_REGISTRY_USE_HARBOR_API_ENABLED:-true}" == "true" ]; then
        if ! docker_image_copy_retag "$@"; then
            docker_image_copy_pull_tag_push "$@"
        fi
    else
        docker_image_copy_pull_tag_push "$@"
    fi
}
