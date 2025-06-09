#!/usr/bin/env -S bash -euo pipefail
# -------------------------------------------------------------------------------------------------------------------- #
# ACME: CERTIFICATE
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
# shellcheck source=/dev/null
. "${SRC_DIR}/${1:?}"

# Parameters.
KEY="${2:?}"; readonly KEY
ACTION="${3:?}"; readonly ACTION
SERVER="${SERVER:?}"; readonly SERVER
DOMAIN=("${DOMAIN[@]:?}"); readonly DOMAIN
EMAIL="${EMAIL:?}"; readonly EMAIL
TYPE="${TYPE:?}"; readonly TYPE

# -------------------------------------------------------------------------------------------------------------------- #
# -----------------------------------------------------< SCRIPT >----------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

function _err() {
  echo >&2 "[$( date +'%Y-%m-%dT%H:%M:%S%z' )]: $*"; exit 1
}

function acme() {
  local opts; opts=(
    '--server' "${SERVER}"
    '--path' "${SRC_DIR}.${KEY}"
    '--email' "${EMAIL}"
    '--key-type' "${KEY}"
    '--pem'
    '--pfx'
  )

  for i in "${DOMAIN[@]}"; do opts+=('--domains' "${i}"); done

  case "${TYPE}" in
    'http') opts+=('--http' '--http.port' "${PORT:-:8080}") ;;
    'dns') opts+=('--dns' "${DNS}"); for i in "${RESOLVER[@]}"; do opts+=('--dns.resolvers' "${i}"); done ;;
    *) _err 'TYPE does not exist!' ;;
  esac

  case "${ACTION}" in
    'run') opts+=('--accept-tos' 'run') ;;
    'renew') opts+=('--days' "${DAYS:-30}" 'renew' '--renew-hook' "${SRC_DIR}/app_hook.sh") ;;
    *) _err 'ACTION does not exist!' ;;
  esac

  "${SRC_DIR}/lego" "${opts[@]}"
}

function main() {
  acme
}; main "$@"
