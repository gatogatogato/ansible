#!/bin/bash

# Set strict error handling
set -euo pipefail

# Constants
readonly RUNDIR=~transport/ansible
readonly INVENTORY="inventory.yaml"
readonly PARMS=""
readonly ACTIONS=(
    "cronjobs_webservers"
    "cronjobs_flickrservers"
)

# Main execution
main() {
	for action in "${ACTIONS[@]}"; do
		echo "Running playbook: ${action}"
		if ! ansible-playbook "${RUNDIR}/${action}.yaml" ${PARMS} -i "${RUNDIR}/${INVENTORY}"; then
			echo "Error: Failed to run playbook ${action}" >&2
			exit 1
		fi
	done
}

main "$@"
