#!/bin/bash
set -euo pipefail

# Constants
readonly RUNDIR="${HOME}/transport/ansible"
readonly INVENTORY="inventory.yaml"
readonly PARMS=""
readonly ACTIONS=(
    "install_all_packages"
    "install_webservers_packages"
    "install_flickrservers_packages"
    "install_ansibleservers_packages"
)

# Main execution
main() {
    for action in "${ACTIONS[@]}"; do
        echo "Running playbook: ${action}"
        if ! ansible-playbook "${RUNDIR}/${action}.yaml" ${PARMS} -i "${RUNDIR}/${INVENTORY}"; then
            echo "Error: Failed to execute playbook ${action}" >&2
            exit 1
        fi
    done
}

main "$@"
