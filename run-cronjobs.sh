#!/bin/bash

# Set strict error handling
set -euo pipefail

# Constants
readonly RUNDIR="${HOME}/transport/ansible"
readonly INVENTORY="inventory.yaml"
readonly ACTIONS=(
    "cronjobs_webservers"
    "cronjobs_flickrservers"
)

# Check if running as correct user
check_user() {
    if [[ "${USER}" != "${REQUIRED_USER}" ]]; then
        echo "Error: Script must be run as user '${REQUIRED_USER}'"
        echo "Current user: ${USER}"
        exit 1
    fi
}

# Main execution
main() {
    check_user
    for action in "${ACTIONS[@]}"; do
        echo "Running playbook: ${action}"
        if ! ansible-playbook "${RUNDIR}/${action}.yaml" ${PARMS} -i "${RUNDIR}/${INVENTORY}"; then
            echo "Error: Failed to run playbook ${action}" >&2
            exit 1
        fi
    done
}

main "$@"
