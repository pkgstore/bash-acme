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
CFG="${1:?}"; readonly CFG
KEY="${2:?}"; readonly KEY
ACTION="${3:?}"; readonly ACTION
SERVER="${SERVER:?}"; readonly SERVER
DOMAINS=("${DOMAINS[@]:?}"); readonly DOMAINS
RESOLVERS=("${RESOLVERS[@]:?}"); readonly RESOLVERS
EMAIL="${EMAIL:?}"; readonly EMAIL
TYPE="${TYPE:?}"; readonly TYPE
DNS="${DNS:?}"; readonly DNS

# -------------------------------------------------------------------------------------------------------------------- #
# -----------------------------------------------------< SCRIPT >----------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

function _date() {
  local type; type="${1}"

  case "${type}" in
    'd') date -u '+%d' ;;
    'm') date -u '+%m' ;;
    's') date -u '+%s' ;;
    't') date -u '+%F.%H-%M-%S' ;;
    'Y') date -u '+%Y' ;;
    'z') date '+%FT%T%:z' ;;
    *) return 1 ;;
  esac
}

function _msg() {
  local type; type="${1}"
  local msg; msg="$( _date 'z' ) $( _host 'f' ) ${SRC_NAME}: ${2:?}"

  case "${type}" in
    'error') echo "${msg}" >&2; exit 1 ;;
    'success') echo "${msg}" ;;
    *) return 1 ;;
  esac
}

function acme() {
  local opts; opts=(
    '--server' "${SERVER}"
    '--path' "${SRC_DIR}/${KEY}"
    '--email' "${EMAIL}"
    '--key-type' "${KEY}"
    '--pem' '--pfx'
    '--pfx.pass' "${PFX_PASS:-changeit}"
    '--pfx.format' "${PFX_FORMAT:-RC2}"
    '--http-timeout' "${HTTP_TIMEOUT:-0}"
    '--dns-timeout' "${DNS_TIMEOUT:-10}"
    '--cert.timeout' "${CERT_TIMEOUT:-30}"
    '--overall-request-limit' "${REQUEST_LIMIT:-18}"
    '--user-agent' "${USER_AGENT:-ACME-LEGO/$CFG}"
  )
  (( "${TLS_SKIP_VERIFY:-0}" )) && opts+=('--tls-skip-verify')
  for i in "${DOMAINS[@]}"; do opts+=('--domains' "${i}"); done

  case "${TYPE}" in
    'http')
      opts+=(
        '--http'
        '--http.port' "${PORT:-:8080}"
      )
      [[ "${HTTP_DELAY:-}" ]] && opts+=('--http.delay' "${HTTP_DELAY}")
      [[ "${HTTP_PROXY_HEADER:-}" ]] && opts+=('--http.proxy-header' "${HTTP_PROXY_HEADER}")
      [[ "${HTTP_MEMCACHED_HOST:-}" ]] && opts+=('--http.memcached-host' "${HTTP_MEMCACHED_HOST}")
      [[ "${HTTP_S3_BUCKET:-}" ]] && opts+=('--http.s3-bucket' "${HTTP_S3_BUCKET}")
      ;;
    'dns')
      opts+=('--dns' "${DNS}")
      (( "${DNS_ANS:-1}" )) || opts+=('--dns.propagation-disable-ans')
      (( "${DNS_RNS:-0}" )) && opts+=('--dns.propagation-rns')
      for i in "${RESOLVERS[@]}"; do opts+=('--dns.resolvers' "${i}"); done
      ;;
    *)
      _msg 'error' "'TYPE' does not exist!"
      ;;
  esac

  case "${ACTION}" in
    'run')
      opts+=(
        '--accept-tos' 'run'
        '--run-hook' "${SRC_DIR}/app_hook.sh"
        '--run-hook-timeout' "${RUN_HOOK_TIMEOUT:-2m0s}"
      )
      (( "${NO_BUNDLE:-0}" )) && opts+=('--no-bundle')
      (( "${MUST_STAPLE:-0}" )) && opts+=('--must-staple')
      ;;
    'renew')
      opts+=(
        'renew'
        '--days' "${DAYS:-30}"
        '--renew-hook' "${SRC_DIR}/app_hook.sh"
        '--renew-hook-timeout' "${RENEW_HOOK_TIMEOUT:-2m0s}"
      )
      (( "${ARI_DISABLE:-0}" )) && opts+=('--ari-disable')
      (( "${REUSE_KEY:-0}" )) && opts+=('--reuse-key')
      (( "${NO_BUNDLE:-0}" )) && opts+=('--no-bundle')
      (( "${MUST_STAPLE:-0}" )) && opts+=('--must-staple')
      ;;
    *)
      _msg 'error' "'ACTION' does not exist!"
      ;;
  esac

  if "${SRC_DIR}/lego" "${opts[@]}"; then
    msg=(
      'success'
      "Certificate retrieval/renewal completed successfully"
      "Certificate retrieval/renewal completed successfully."
    ); _mail "${msg[@]}"; _gitlab "${msg[@]}"; _msg 'success' "${msg[2]}"
  else
    msg=(
      'error'
      "Error while retrieving/updating certificate"
      "Error while retrieving/updating certificate!"
    ); _mail "${msg[@]}"; _gitlab "${msg[@]}"; _msg 'error' "${msg[2]}"
  fi
}

function main() {
  acme
}; main "$@"
