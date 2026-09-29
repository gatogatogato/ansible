#!/bin/bash
# Mirror all of gatogatogato's GitHub repos (public and private) as bare
# repos, so the code survives a lost GitHub account or deleted repos.
# Runs nightly from cron, keeps a log and reports to an Uptime Kuma push
# monitor. Restore a repo with: git clone <MIRROR_DIR>/<name>.git
#
# Token and settings are secrets and stay out of the repo. Put them into
# ~/.config/git-mirror.env on the ansible server (chmod 600):
#   GITHUB_TOKEN="github_pat_..."   # fine-grained, all repos, Contents + Metadata read-only
#   MIRROR_DIR="/home/transport/git-mirror"          # optional, where the mirrors go
#   UPTIME_KUMA_PUSH_URL="https://<kuma>/api/push/<token>"   # optional

set -uo pipefail

readonly GITHUB_USER="gatogatogato"
readonly ENV_FILE="${HOME}/.config/git-mirror.env"
readonly LOG_DIR="${HOME}/logs"
readonly LOG_FILE="${LOG_DIR}/git-mirror-$(date +%Y-%m-%d).log"

# cron starts with a minimal PATH
export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin"

GITHUB_TOKEN=""
MIRROR_DIR="${HOME}/git-mirror"
UPTIME_KUMA_PUSH_URL=""
# shellcheck source=/dev/null
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

mkdir -p "${LOG_DIR}"
exec >> "${LOG_FILE}" 2>&1
echo "=== $(date '+%F %T') mirror to ${MIRROR_DIR}"

report() {
    echo "$2"
    [[ -n "${UPTIME_KUMA_PUSH_URL}" ]] || return 0
    curl -fsS --max-time 10 -o /dev/null --get \
        --data-urlencode "status=$1" \
        --data-urlencode "msg=$2" \
        "${UPTIME_KUMA_PUSH_URL}" || echo "Warning: Uptime Kuma push failed"
}

if [[ -z "${GITHUB_TOKEN}" ]]; then
    report down "No GITHUB_TOKEN in ${ENV_FILE}"
    exit 1
fi

# Hand the token to git through the environment, never on the command line
# (visible in ps) or in a remote URL (stored in the mirror's config)
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="http.https://github.com/.extraheader"
GIT_CONFIG_VALUE_0="Authorization: Basic $(printf 'x-access-token:%s' "${GITHUB_TOKEN}" | base64 -w0)"
export GIT_CONFIG_VALUE_0
export GIT_TERMINAL_PROMPT=0

# All repos the token can see that belong to GITHUB_USER, new ones included
list_repos() {
    local page=1 names
    while :; do
        names=$(curl -fsS --max-time 30 \
            -H "Authorization: Bearer ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github+json" \
            "https://api.github.com/user/repos?affiliation=owner&per_page=100&page=${page}" |
            python3 -c 'import json, sys; print("\n".join(r["name"] for r in json.load(sys.stdin)))') || return 1
        [[ -n "${names}" ]] || return 0
        echo "${names}"
        page=$((page + 1))
    done
}

if ! repos=$(list_repos) || [[ -z "${repos}" ]]; then
    report down "Could not list the repos on GitHub (token expired?)"
    exit 1
fi

mkdir -p "${MIRROR_DIR}"
failed=()
count=0
while read -r name; do
    dir="${MIRROR_DIR}/${name}.git"
    url="https://github.com/${GITHUB_USER}/${name}.git"
    echo "--- ${name}"
    if [[ -d "${dir}" ]]; then
        git -C "${dir}" remote update --prune
    else
        git clone --mirror "${url}" "${dir}"
    fi || { failed+=("${name}"); continue; }
    count=$((count + 1))
done <<< "${repos}"

# Keep logs for eight weeks
find "${LOG_DIR}" -name 'git-mirror-*.log' -mtime +56 -delete

if [[ ${#failed[@]} -eq 0 ]]; then
    report up "Mirrored ${count} repos"
else
    report down "Mirror failed for $(IFS=,; echo "${failed[*]}"), see ${LOG_FILE}"
    exit 1
fi
