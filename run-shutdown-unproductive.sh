#!/bin/bash

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

# Define constants
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

main() {
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
