#!/bin/bash

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

# Constants
readonly REQUIRED_USER="transport"
readonly RUNDIR="${HOME}/ansible"
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
        echo "Error: Script must be run as user '${REQUIRED_USER}'" >&2
        echo "Error: Current user is '${USER}'" >&2
        exit 1
    fi
}

main() {
    check_user
    print_banner

    # Check if ansible-playbook exists
    if ! command -v ansible-playbook >/dev/null 2>&1; then
        echo "Error: Command 'ansible-playbook' not found" >&2
        exit 1
    fi

    # Check if directory and files exist
    if [[ ! -d "${RUNDIR}" ]]; then
        echo "Error: Directory '${RUNDIR}' not found" >&2
        exit 1
    fi

    if [[ ! -f "${RUNDIR}/${INVENTORY}" ]]; then
        echo "Error: Inventory file '${RUNDIR}/${INVENTORY}' not found" >&2
        exit 1
    fi

    if [[ ! -f "${RUNDIR}/${PLAYBOOK}" ]]; then
        echo "Error: Playbook '${RUNDIR}/${PLAYBOOK}' not found" >&2
        exit 1
    fi

    # Run ansible playbook
    if ! ansible-playbook "${RUNDIR}/${PLAYBOOK}" -i "${RUNDIR}/${INVENTORY}"; then
        echo "Error: Playbook '${PLAYBOOK}' exited with non-zero status" >&2
        exit 1
    fi
}

main "$@"
