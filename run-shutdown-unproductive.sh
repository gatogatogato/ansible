#!/bin/bash

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

# Constants
readonly RUNDIR="${HOME}/transport/ansible"
readonly INVENTORY="inventory.yaml"
readonly PLAYBOOK="shutdown_unproductive.yaml"

# Print banner function
print_banner() {
    cat << 'EOF'
* * * * * * * * * * * * * * * * * * * * * * * *
*                                             *
*    Shutting down non-productive servers!    *
*                                             *
* * * * * * * * * * * * * * * * * * * * * * * *
EOF
}

# Check if running as correct user
check_user() {
    if [[ "${USER}" != "${REQUIRED_USER}" ]]; then
        echo "Error: Script must be run as user '${REQUIRED_USER}'"
        echo "Current user: ${USER}"
        exit 1
    fi
}

main() {
    check_user
    print_banner

    # Check if ansible-playbook exists
    if ! command -v ansible-playbook >/dev/null 2>&1; then
        echo "Error: ansible-playbook not found" >&2
        exit 1
    }

    # Check if directory and files exist
    if [[ ! -d "${RUNDIR}" ]]; then
        echo "Error: Ansible directory ${RUNDIR} not found" >&2
        exit 1
    }

    if [[ ! -f "${RUNDIR}/${INVENTORY}" ]]; then
        echo "Error: Inventory file not found at ${RUNDIR}/${INVENTORY}" >&2
        exit 1
    }

    if [[ ! -f "${RUNDIR}/${PLAYBOOK}" ]]; then
        echo "Error: Playbook not found at ${RUNDIR}/${PLAYBOOK}" >&2
        exit 1
    }

    # Run ansible playbook
    ansible-playbook "${RUNDIR}/${PLAYBOOK}" ${PARMS:+${PARMS}} -i "${RUNDIR}/${INVENTORY}"
}

main "$@"
