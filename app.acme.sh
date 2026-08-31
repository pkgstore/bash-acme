#!/usr/bin/env -S bash -euo pipefail
# -------------------------------------------------------------------------------------------------------------------- #
# ACME: CERTIFICATE
# -------------------------------------------------------------------------------------------------------------------- #
# @package    Bash
# @author     Kai Kimera <mail@kai.kim>
# @license    MIT
# @version    0.1.0
# @link       https://libsys.ru/ru/2025/03/481a0666-eb21-555f-858f-0c2d695b9a74/
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
MAIL_ON="${MAIL_ON:?}"; readonly MAIL_ON
MAIL_FROM="${MAIL_FROM:?}"; readonly MAIL_FROM
MAIL_TO=("${MAIL_TO[@]:?}"); readonly MAIL_TO
GITLAB_ON="${GITLAB_ON:?}"; readonly GITLAB_ON
GITLAB_API="${GITLAB_API:?}"; readonly GITLAB_API
GITLAB_PROJECT="${GITLAB_PROJECT:?}"; readonly GITLAB_PROJECT
GITLAB_TOKEN="${GITLAB_TOKEN:?}"; readonly GITLAB_TOKEN

# Variables.
META="$( date '+%FT%T%:z' ) $( hostname -f ) ${SRC_NAME}"
LOG_ACME="${SRC_DIR}/log.acme"
LOG_LEGO="${SRC_DIR}/log.lego"

# -------------------------------------------------------------------------------------------------------------------- #
# -----------------------------------------------------< SCRIPT >----------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

function _error() {
  echo "${META}: $*" >&2; exit 1
}

function _success() {
  echo "${META}: $*" >&2
}

function _mail() {
  (( ! "${MAIL_ON}" )) && return 0

  local type; type="#type:backup:${1}"
  local subj; subj="[$( hostname -f )] ${SRC_NAME}: ${2}"
  local body; body="${3}"
  local id; id="#id:$( hostname -f ):$( dmidecode -s 'system-uuid' )"
  local ip; ip="#ip:$( hostname -I )"
  local date; date="#date:$( date '+%FT%T%:z' )"
  local opts; opts=('-S' 'v15-compat' '-s' "${subj}" '-r' "${MAIL_FROM}")
  [[ "${MAIL_SMTP_SERVER:-}" ]] && opts+=(
    '-S' "mta=${MAIL_SMTP_SERVER} smtp-use-starttls"
    '-S' "smtp-auth=${MAIL_SMTP_AUTH:-none}"
  )
  opts+=('-.')

  printf "%s\n\n-- \n%s\n%s\n%s\n%s" "${body}" "${id^^}" "${ip^^}" "${date^^}" "${type^^}" \
    | s-nail "${opts[@]}" "${MAIL_TO[@]}"
}

function _gitlab() {
  (( ! "${GITLAB_ON}" )) && return 0

  local label; label="${1}"
  local title; title="[$( hostname -f )] ${SRC_NAME}: ${2}"
  local desc; desc="${3}"
  local id; id="#id:$( hostname -f ):$( dmidecode -s 'system-uuid' )"
  local ip; ip="#ip:$( hostname -I )"
  local date; date="#date:$( date '+%FT%T%:z' )"
  local type; type="#type:domain:${label}"

  curl "${GITLAB_API}/projects/${GITLAB_PROJECT}/issues" -X 'POST' -kfsLo '/dev/null' \
    -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" -H 'Content-Type: application/json' \
    -d @- <<EOF
{
  "title": "${title}",
  "description": "${desc//\'/\`}\n\n---\n\n- \`${id^^}\`\n- \`${ip^^}\`\n- \`${date^^}\`\n- \`${type^^}\`",
  "labels": "domain,acme,${label}"
}
EOF
}

function _msg() {
  _mail "${1}" "${2}" "${3}"
  _gitlab "${1}" "${2}" "${3}"

  case "${1}" in
    'error') _error "${3}" ;;
    'success') _success "${3}" ;;
    *) _error "'MSG_TYPE' does not exist!" ;;
  esac
}

function acme() {
  local opts; opts=(
    '--server' "${SERVER}"
    '--path' "${SRC_DIR}/${KEY}"
    '--email' "${EMAIL}"
    '--key-type' "${KEY}"
    '--pem' '--pfx'
    '--pfx.password' "${PFX_PASS:-changeit}"
    '--pfx.format' "${PFX_FORMAT:-RC2}"
  )

  for i in "${DOMAINS[@]}"; do opts+=('--domains' "${i}"); done

  case "${TYPE}" in
    'http')
      opts+=(
        '--http'
        '--http.address' "${PORT:-:8080}"
      )
      ;;
    'dns')
      opts+=('--dns' "${DNS}")
      for i in "${RESOLVERS[@]}"; do opts+=('--dns.resolvers' "${i}"); done
      ;;
    *)
      _error "'TYPE' does not exist!"
      ;;
  esac

  case "${ACTION}" in
    'run')
      opts+=(
        '--accept-tos' 'run'
        '--run-hook' "${SRC_DIR}/app.hook.sh"
        '--run-hook-timeout' "${RUN_HOOK_TIMEOUT:-2m0s}"
      )
      ;;
    'renew')
      opts+=(
        'renew'
        '--days' "${DAYS:-30}"
        '--renew-hook' "${SRC_DIR}/app.hook.sh"
        '--renew-hook-timeout' "${RENEW_HOOK_TIMEOUT:-2m0s}"
      )
      ;;
    *)
      _error "'ACTION' does not exist!"
      ;;
  esac

  local msg_e; msg_e=(
    'error'
    "Error while receiving/renewing certificate for domains"
    "Error while receiving/renewing certificate for domains: ${DOMAINS[@]@Q}!"
  )
  local msg_s; msg_s=(
    'success'
    "Certificate for domains successfully received/renewed"
    "Certificate for domains successfully received/renewed: ${DOMAINS[@]@Q}."
  )

  if "${SRC_DIR}/lego" "${opts[@]}" 2>&1 | tee "${LOG_LEGO}"; then
    grep -q 'no renewal' "${LOG_LEGO}" || _msg "${msg_s[@]}"
  else
    _msg "${msg_e[@]}"
  fi
}

function main() {
  acme 2>&1 | tee "${LOG_ACME}"
}; main "$@"
