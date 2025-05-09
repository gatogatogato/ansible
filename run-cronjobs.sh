#!/bin/bash

# Set strict error handling
set -euo pipefail

# Constants
readonly REQUIRED_USER="transport"
readonly RUNDIR="${HOME}/ansible"
readonly INVENTORY="inventory.yaml"
readonly ACTIONS=(
    "cronjobs_webservers"
    "cronjobs_flickrservers"
)

# Check if running as correct user
check_user() {
    if [[ "${USER}" != "${REQUIRED_USER}" ]]; then
        echo "Error: Script must be run as user '${REQUIRED_USER}'" >&2
        echo "Error: Current user is '${USER}'" >&2
        exit 1
    fi
}

# Main execution
main() {
    check_user
    for action in "${ACTIONS[@]}"; do
        echo "Running playbook: ${action}"
        if ! ansible-playbook "${RUNDIR}/${action}.yaml" -i "${RUNDIR}/${INVENTORY}"; then
            echo "Error: Playbook '${action}' exited with non-zero status" >&2
            exit 1
        fi
    done
}

main "$@"
