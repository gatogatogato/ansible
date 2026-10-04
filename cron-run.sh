#!/bin/bash
# Unattended run.sh task for cron: runs "run.sh TASK", keeps a log and
# reports the result to an Uptime Kuma push monitor. Usage: cron-run.sh TASK
#
# The push URL is a secret and stays out of the repo. Put it into
# ~/.config/ansible-TASK.env on the ansible server, e.g. ansible-updates.env:
#   UPTIME_KUMA_PUSH_URL="https://<kuma>/api/push/<token>"

set -uo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $(basename "$0") TASK" >&2
    exit 1
fi
readonly TASK="$1"
readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ENV_FILE="${HOME}/.config/ansible-${TASK}.env"
readonly LOG_DIR="${HOME}/logs"
readonly LOG_FILE="${LOG_DIR}/ansible-${TASK}-$(date +%Y-%m-%d).log"

# cron starts with a minimal PATH
export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin"

UPTIME_KUMA_PUSH_URL=""
# shellcheck source=/dev/null
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

mkdir -p "${LOG_DIR}"
"${REPO_DIR}/run.sh" "${TASK}" > "${LOG_FILE}" 2>&1
rc=$?

if [[ ${rc} -eq 0 ]]; then
    status="up"
    msg="${TASK} OK"
else
    status="down"
    # Hosts with failures, taken from the play recaps
    failed_hosts=$(awk '/PLAY RECAP/ {r=1; next} r && /(failed|unreachable)=[1-9]/ {print $1}' "${LOG_FILE}" | sort -u | paste -sd, -)
    msg="${TASK} failed on ${failed_hosts:-unknown hosts}, see ${LOG_FILE}"
fi

if [[ -n "${UPTIME_KUMA_PUSH_URL}" ]]; then
    curl -fsS --max-time 10 -o /dev/null --get \
        --data-urlencode "status=${status}" \
        --data-urlencode "msg=${msg}" \
        "${UPTIME_KUMA_PUSH_URL}" || echo "Warning: Uptime Kuma push failed" >> "${LOG_FILE}"
fi

# Keep logs for eight weeks
find "${LOG_DIR}" -name "ansible-${TASK}-*.log" -mtime +56 -delete

exit ${rc}
