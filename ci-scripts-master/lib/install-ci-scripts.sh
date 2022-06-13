#!/bin/bash
#
# install-ci-scripts.sh OPTIONS
#
# Install all ci-scripts dependencies and configure everything necessary to make them run correctly.
#
# Possible OPTIONS are:
#   -h|--help                           Show this message and exit.
#   -m|--minio-client-url       URL     Use this URL to download minio client
#                                       If empty, default version will be installed.
#   -M|--minio-client-checksum  FILE    Path to file with minio client sha256 checksum.
#                                       If empty, the checksum check will be skipped.
#   -d|--dirt-url               URL     Use this URL to download dirt.
#                                       If empty, dirt will not be installed.
#   -k|--known-hosts            FILE    Use this file instead of default known_hosts.
#                                       If empty ssh setup will be skipped.
#   --kustomize-url             URL     Use this URL to download kustomize
#                                       If empty, default version will be installed.
#   --kustomize-checksum        FILE    Path to file with kustomize sha256 checksum.
#                                       If empty, the checksum check will be skipped.
#   --kubeconform-url           URL     Use this URL to download kubeconform.
#                                       If empty, default version will be installed.
#   --kubeconform-checksum      FILE    Path to file with kubeconform sha256 checksum.
#                                       If empty, the checksum check will be skipped.
#   --argocd-cli-url            URL     Use this URL to download argocd client
#                                       If empty, default version will be installed.
#   --argocd-cli-checksum       FILE    Path to file with argocd client sha256 checksum.
#                                       If empty, the checksum check will be skipped.
# The script is sensitive to the following env variables:
#   MINIO_CLIENT_URL
#   MINIO_CLIENT_SHA256SUM_FILE
#   DIRT_SCRIPTS_ARCHIVE_URL
#   SSH_KNOWN_HOSTS_FILE
#   DEB_PACKAGES
#   PIP_PACKAGES
#   KUSTOMIZE_URL
#   KUSTOMIZE_SHA256SUM_FILE
#   KUBECONFORM_URL
#   KUBECONFORM_SHA256SUM_FILE
#   ARGOCD_CLI_URL
#   ARGOCD_CLI_SHA256SUM_FILE
#   KUBECTL_VERSIONS

set -eo pipefail

[ -n "$TRACE" ] && set -x

function setup_apt_repos() {
    echo "deb http://repo/mirror/docker-buster docker-buster stable" >> /etc/apt/sources.list
    apt-get -qq update
}

function install_dirt() {
    local prefix="$(dirname "$dir")"
    mkdir -p "$prefix/dirt-scripts"
    curl -L "$DIRT_SCRIPTS_ARCHIVE_URL" | tar xzf - -C "$prefix/dirt-scripts"
}

function get_kubectl_binary_url() {
    local version=$1
    local base_url=$2
    local kubectl_binary_url="${base_url}v${version}/bin/linux/amd64/kubectl"
    echo -n "${kubectl_binary_url}"
}

function get_kubectl_checksum_url() {
    local version=$1
    local base_url=$2
    local kubectl_checksum_url="${base_url}v${version}/bin/linux/amd64/kubectl.sha256"
    echo -n "${kubectl_checksum_url}"
}

function install_from_url() {
    local download_url="${1}"
    local checksum_file_or_url="${2}"
    local binary_name="${3}"
    local filename="${4:-$(basename "${download_url}")}"
    if [[ "$checksum_file_or_url" =~ https?://.+ ]]; then
        checksum_plaintext=$(curl -L --fail "${checksum_file_or_url}")
        echo "$checksum_plaintext /tmp/$filename" > /tmp/${filename}.sha256
        sha256sum_file="/tmp/${filename}.sha256"
    else
        echo "$checksum_file_or_url"
        sha256sum_file="${2}"
    fi
    curl -L --fail "${download_url}" -o "/tmp/$filename"
    [ -n "${sha256sum_file}" ] && sha256sum -c "${sha256sum_file}"
    if [[ $filename = *.gz ]] ; then
        tar xf "/tmp/$filename" -C "/usr/local/bin/"
    else
        cp -f "/tmp/$filename" "/usr/local/bin/${binary_name}"
    fi
    chmod +x "/usr/local/bin/${binary_name}"
    rm -f "/tmp/$filename" "$sha256sum_file"
}

function install_kubectl_versions_from_url() {
    local versions_to_download="${1}"
    local kubectl_base_url="https://storage.googleapis.com/kubernetes-release/release/"
    IFS=, read -r -a versions <<< "$versions_to_download"
    for version in "${versions[@]}"; do
        download_binary_url=$(get_kubectl_binary_url $version $kubectl_base_url)
        download_checksum_url=$(get_kubectl_checksum_url $version $kubectl_base_url)
        binary_name="kubectl${version}"
        install_from_url "$download_binary_url" "$download_checksum_url" "$binary_name"
    done
}

function setup_ssh() {
    mkdir -p "/root/.ssh"
    chmod 700 "/root/.ssh"
    cp "$SSH_KNOWN_HOSTS_FILE" "/root/.ssh/"
}

function install_ci_scripts_dependencies() {
    setup_apt_repos
    [ -n "$DEB_PACKAGES" ] && apt-get -qq install $DEB_PACKAGES
    [ -n "$PIP_PACKAGES" ] && python3 -m pip install --upgrade $PIP_PACKAGES
    [ -n "$DIRT_SCRIPTS_ARCHIVE_URL" ] && install_dirt
    [ -n "$MINIO_CLIENT_URL" ] && install_from_url $MINIO_CLIENT_URL $MINIO_CLIENT_SHA256SUM_FILE "mc"
    [ -n "$KUSTOMIZE_URL" ] && install_from_url $KUSTOMIZE_URL $KUSTOMIZE_SHA256SUM_FILE "kustomize"
    [ -n "$KUBECONFORM_URL" ] && install_from_url $KUBECONFORM_URL $KUBECONFORM_SHA256SUM_FILE "kubeconform"
    [ -n "$ARGOCD_CLI_URL" ] && install_from_url "$ARGOCD_CLI_URL" "$ARGOCD_CLI_SHA256SUM_FILE" "argocd" "argocd"
    [ -n "$SSH_KNOWN_HOSTS_FILE" ] && setup_ssh
    [ -n "$KUBECTL_VERSIONS" ] && install_kubectl_versions_from_url $KUBECTL_VERSIONS  # NOTE: the default kubectl version is installed as a Debian package.
}

self="$(readlink -f "$0")"
dir="$(dirname "$self")"

MINIO_CLIENT_URL="${MINIO_CLIENT_URL:-https://dl.minio.io/client/mc/release/linux-amd64/archive/mc.RELEASE.2018-09-26T00-42-43Z}"
MINIO_CLIENT_SHA256SUM_FILE="${MINIO_CLIENT_SHA256SUM_FILE:-$dir/checksums/mc.sha256sum}"
DIRT_SCRIPTS_ARCHIVE_URL="${DIRT_SCRIPTS_ARCHIVE_URL:-https://sklik-devops.glpages.seznam.net/dirt/all.tar.gz}"
SSH_KNOWN_HOSTS_FILE="${SSH_KNOWN_HOSTS_FILE:-$dir/conf/known_hosts}"
DEB_PACKAGES="${DEB_PACKAGES:-$(cat $dir/conf/depends.txt)}"
KUSTOMIZE_URL="${KUSTOMIZE_URL:-https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.5.5/kustomize_v4.5.5_linux_amd64.tar.gz}"
KUSTOMIZE_SHA256SUM_FILE="${KUSTOMIZE_SHA256SUM_FILE:-$dir/checksums/kustomize.sha256sum}"
KUBECONFORM_URL="${KUBECONFORM_URL:-https://github.com/yannh/kubeconform/releases/download/v0.4.12/kubeconform-linux-amd64.tar.gz}"
KUBECONFORM_SHA256SUM_FILE="${KUBECONFORM_SHA256SUM_FILE:-$dir/checksums/kubeconform.sha256sum}"
ARGOCD_CLI_URL="${ARGOCD_CLI_URL:-https://github.com/argoproj/argo-cd/releases/download/v2.3.2/argocd-linux-amd64}"
ARGOCD_CLI_SHA256SUM_FILE="${ARGOCD_CLI_SHA256SUM_FILE:-$dir/checksums/argocd.sha256sum}"
KUBECTL_VERSIONS="${KUBECTL_VERSIONS:-1.19.9}"

source "$dir/common.sh"

pargs="$(getopt -o "h,g:,G:,m:,M:,d:,k:" -l "help,minio-client-url:,minio-client-checksum:,dirt-url:,known-hosts:,kustomize-url:,kustomize-checksum:" -n "$0" -- "$@")"
eval "set -- $pargs"
while true; do
  case "$1" in
    -h|--help)
        help_display "$self"
        exit 0
        ;;
    -m|--minio-client-url)
        MINIO_CLIENT_URL="$2"
        shift 2
        ;;
    -M|--minio-client-checksum)
        MINIO_CLIENT_SHA256SUM_FILE="$2"
        shift 2
        ;;
    -d|--dirt-url)
        DIRT_SCRIPTS_ARCHIVE_URL="$2"
        shift 2
        ;;
    -k|--known-hosts)
        SSH_KNOWN_HOSTS_FILE="$2"
        shift 2
        ;;
    --kustomize-url)
        KUSTOMIZE_URL="$2"
        shift 2
        ;;
    --kustomize-checksum)
        KUSTOMIZE_SHA256SUM_FILE="$2"
        shift 2
        ;;
    --kubeconform-url)
        KUBECONFORM_URL="$2"
        shift 2
        ;;
    --kubeconform-checksum)
        KUBECONFORM_SHA256SUM_FILE="$2"
        shift 2
        ;;
    --argocd-cli-url)
        ARGOCD_CLI_URL="$2"
        shift 2
        ;;
    --argocd-cli-checksum)
        ARGOCD_CLI_SHA256SUM_FILE="$2"
        shift 2
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

install_ci_scripts_dependencies
