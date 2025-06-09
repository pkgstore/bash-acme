#!/usr/bin/env -S bash -eu
# -------------------------------------------------------------------------------------------------------------------- #
# ACME: HOOK
# -------------------------------------------------------------------------------------------------------------------- #
# @package    Bash
# @author     Kai Kimera <mail@kai.kim>
# @license    MIT
# @version    0.1.0
# @link       https://lib.onl/ru/2025/03/481a0666-eb21-555f-858f-0c2d695b9a74/
# -------------------------------------------------------------------------------------------------------------------- #

(( EUID != 0 )) && { echo >&2 'This script should be run as root!'; exit 1; }

# -------------------------------------------------------------------------------------------------------------------- #
# CONFIGURATION
# -------------------------------------------------------------------------------------------------------------------- #

# Sources.
SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P )"
SRC_NAME="$( basename "$( readlink -f "${BASH_SOURCE[0]}" )" )"
# shellcheck source=/dev/null
. "${SRC_DIR}/${SRC_NAME%.*}.conf"

# Parameters.
DATA=("${DATA:?}"); readonly DATA
SERVICES=("${SERVICES[@]:?}"); readonly SERVICES
CRT="${LEGO_CERT_PATH:?}"; readonly CRT
KEY="${LEGO_CERT_KEY_PATH:?}"; readonly KEY
PEM="${LEGO_CERT_PEM_PATH:?}"; readonly PEM
PFX="${LEGO_CERT_PFX_PATH:?}"; readonly PFX

# -------------------------------------------------------------------------------------------------------------------- #
# -----------------------------------------------------< SCRIPT >----------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

function _if_svc() {
  local service; service="${1}"

  systemctl list-units --type='service' --state='active' | grep -Fq "${service}" && return 0 || return 1
}

function crt_install() {
  local cert=("${CRT}" "${KEY}" "${PEM}" "${PFX}")

  for i in "${cert[@]}"; do
    install -m '0644' -Dt "${DATA}/$( echo "${i}" | awk -F '/' '{ print $(NF-2) }' )" "${i}"
  done
}

function svc_reload() {
  for s in "${SERVICES[@]}"; do
    _if_svc "${s}" || continue
    systemctl reload "${s}"
  done
}

function main() {
  crt_install && svc_reload
}; main "$@"
