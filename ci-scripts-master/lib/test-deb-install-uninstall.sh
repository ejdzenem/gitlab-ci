#!/bin/bash
# test-deb-install-uninstall.sh OPTIONS <deb-file> ...
#
# Possible OPTIONS are:
#   -h|--help                  Show this message and exists
#   --debug                    Enable debug mode
#   -m|--install-mode          Define tool used for installation (apt-get, apt, gdebi)
#   -p|--phases PHASES         Define which phases of (un)install process to perform.
#                              Defaults to: uninstall_tolerant,test_uninstalled,install,test_installed,test_installed_checksum,uninstall,test_uninstalled

[ -n "$TRACE" ] && set -x

SCRIPT_FN=$(readlink -f $0)
SCRIPT_DIR=$(dirname ${SCRIPT_FN})

source ${SCRIPT_DIR}/common.sh

# local functions
# ---------------------------------------------------------------------------

# deb_pkg_field <file> <metadata-field>
#   get pkg metadata field from deb file name
# example: deb_pkg_name mydeb.deb "Version:"
function deb_pkg_field() {
  [ "$#" != 2 ] && return 254
  local retval=$(dpkg-deb -I $1 | awk -v "f=$2" '{if($1==f){print $2}}')
  echo "${retval}"
  test -n "${retval}"
}


# deb_install <file> [file] ...
#   install one or more debian files
#   return 0 if all ok otherwise 1
#   sensitive on DEB_INSTALL_MODE="apt-get|deb-apt-get|gdebi|apt|deb-apt"
function deb_install() {
  local retvalue=0
  if [ "${DEB_INSTALL_MODE}" == "gdebi" ]; then
    for i_pkgfn in "$@"; do
      # perform installation step by step as gdebi does not support package batch
      gdebi --non-interactive ${i_pkgfn} || let "retvalue++"
    done
    return ${retvalue}
  elif [ "${DEB_INSTALL_MODE}" == "apt" -o \
         "${DEB_INSTALL_MODE}" == "deb-apt" ]; then
    dpkg -i "$@" || \
      apt -y --fix-broken install
  else
    dpkg -i "$@" || \
      apt-get -y --fix-broken install
  fi
}

# deb_uninstall <file> [file] ...
#   uninstall given packages (provided as deb files)
#   return number of uninstall failures
function deb_uninstall() {
  apt-get purge -y $(for i_pkgfn in "$@"; do echo "$(deb_pkg_field ${i_pkgfn} "Package:") "; done) || \
    let "fail_cnt++"
}

# deb_installed <file> [file] ...
#   check whether are given packages installed (provided as deb files)
#   return number of images not installed (0 means all given packages installed)
function deb_installed() {
  local fail_cnt=0
  for i_pkgfn in "$@"; do
    i_pkgname=$(deb_pkg_field ${i_pkgfn} "Package:")
    i_pkgver=$(deb_pkg_field ${i_pkgfn} "Version:")
    LC_ALL=C dpkg-query --showformat '${Package} ${Version} ${Status}' --show ${i_pkgname} | \
      grep -q "${i_pkgver} install ok installed"
    if [ "$?" == "0" ]; then
      i_pkg_state="installed"
    else
      i_pkg_state="*NOT* installed"
      let "fail_cnt++"
    fi
    echo "Package ${i_pkgname} ${i_pkgver} (${i_pkgfn}) is ${i_pkg_state}."
  done
  return ${fail_cnt}
}

# deb_installed <file> [file] ...
#   check whether MD5sums extracted from the given packages matches to those
#   stored on the system (implies that package is not only installed but also
#   that it was installed from the provided *.deb file).
#   return number of images not correctly installed (0 means all given packages installed)
function deb_installed_checksum() {
  local fail_cnt=0
  for i_pkgfn in "$@"; do
    i_pkgname=$(deb_pkg_field ${i_pkgfn} "Package:")
    diff  <(dpkg-deb -I ${i_pkgfn} md5sums) \
          /var/lib/dpkg/info/${i_pkgname}.md5sums
    if [ "$?" == "0" ]; then
      i_pkg_state="installed and MD5sums matches."
    else
      i_pkg_state="not installed on the system or MD5sums does not match to those in the package!"
      let "fail_cnt++"
    fi
    echo "Package ${i_pkgname} (${i_pkgfn}) is ${i_pkg_state}"
  done
  return ${fail_cnt}
}

# phase functions
function uninstall_tolerant () {
    deb_uninstall "$@"
    return 0
}
function test_uninstalled () {
    deb_installed "$@"
    test "$?" ==  $(echo "$@" | wc -w)
}
function install () {
    deb_install "$@"
}
function test_installed () {
    deb_installed "$@"
}
function test_installed_checksum () {
    deb_installed_checksum "$@"
}
function uninstall () {
    deb_uninstall "$@"
}

# constants / variables
# ---------------------------------------------------------------------------
FAIL_CNT=0
INSTALL_MODE="apt-get"
DEB_FILES=()
PHASES="uninstall_tolerant,test_uninstalled,install,test_installed,test_installed_checksum,uninstall,test_uninstalled"

# cmdline parsing
# ---------------------------------------------------------------------------
pargs=$(getopt -o "h,m:,p:" -l "help,install-mode:,debug,phases:" -n "$0" -- "$@")
eval set -- "$pargs"
while true; do
  case "$1" in
    -h|--help)
        help_display $SCRIPT_FN
        exit 0
        ;;
    -m|--install-mode)
        INSTALL_MODE="$2"
        shift 2
        ;;
    -p|--phases)
        PHASES="$2"
        shift 2
        ;;
    --debug)
        set -x
        shift
        ;;
    --)
        shift
        ;;
    *)
        if [ -f "$1" -a -s "$1" ]; then
          DEB_FILES+=("$1")
          shift
        elif [ -z "$1" ]; then
          break
        else
          help_display $SCRIPT_FN
          myexit 1 "Not implemented: $1"
        fi
        ;;
  esac
done

if [ "${#DEB_FILES[@]}" == 0 ]; then
  help_display $SCRIPT_FN
  myexit 2 "At least one deb package has to be supplied (${DEB_FILES[*]})."
fi

# main()
# ---------------------------------------------------------------------------
mylog -e "\nPackage files: ${DEB_FILES[*]}"
mylog -e "Package names: $(for i_pkgfn in "${DEB_FILES[@]}"; do echo -n "$(deb_pkg_field ${i_pkgfn} "Package:") "; done)"

DEB_INSTALL_MODE="${INSTALL_MODE}"
i_cnt=0
for i_phase in $(echo ${PHASES} | sed 's/,/ /g'); do
  i_msg="Phase ${i_cnt}: ${i_phase} ${DEB_FILES[@]} [fail_cnt=${FAIL_CNT}]"
  i_msg_len=$(echo "${i_msg}" | wc -c)
  printf "\n%${i_msg_len}s\n" |tr " " "="
  mylog "${i_msg}"
  printf "%${i_msg_len}s\n" |tr " " "="
  ${i_phase} "${DEB_FILES[@]}"
  if [ "$?" == "0" ]; then
    i_state_msg='passed'
  else
    i_state_msg='failed'
    let "FAIL_CNT++"
  fi
  mylog ".phase ${i_state_msg} [fail_cnt=${FAIL_CNT}]"
  let "i_cnt++"
done

myexit ${FAIL_CNT} -e "\n${SCRIPT_FN}:Completed with ${FAIL_CNT} problems."

# eof
