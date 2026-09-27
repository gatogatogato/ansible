#!/bin/bash
# Bring ~/ansible up to date with GitHub (clone on first use).

set -euo pipefail

readonly REQUIRED_USER="transport"
readonly REPO_URL="https://github.com/gatogatogato/ansible"
readonly ANSIBLE_DIR="${HOME}/ansible"

if [[ "$(id -un)" != "${REQUIRED_USER}" ]]; then
    echo "Error: Script must be run as user '${REQUIRED_USER}', not '$(id -un)'" >&2
    exit 1
fi

if [[ -d "${ANSIBLE_DIR}/.git" ]]; then
    git -C "${ANSIBLE_DIR}" pull --ff-only
else
    git clone "${REPO_URL}" "${ANSIBLE_DIR}"
fi

# Keep a copy outside the repo so it can be run from anywhere
cp "${ANSIBLE_DIR}/clone.sh" "${HOME}/clone.sh"
