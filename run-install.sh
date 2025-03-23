#!/bin/bash

# Set strict error handling
set -euo pipefail

# Constants
readonly REQUIRED_USER="transport"
readonly RUNDIR="${HOME}/ansible"
readonly INVENTORY="inventory.yaml"
readonly ACTIONS=(
    "install_all_packages"
    "install_webservers_packages"
    "install_flickrservers_packages"
    "install_ansibleservers_packages"
)

# Check if running as correct user
check_user() {
    if [[ "$USER" != "$REQUIRED_USER" ]]; then
        echo "Error: Script must be run as user '$REQUIRED_USER'"
        echo "Current user: $USER"
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
