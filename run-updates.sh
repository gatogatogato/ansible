#!/bin/bash
set -euo pipefail

# Default configurations
readonly RUNDIR="${HOME}/transport/ansible"
readonly INVENTORY="inventory.yaml"
readonly ACTIONS=(
    "update_all_apt"
    "update_all_gem"
    "update_all_micro"
    "update_webservers_snap"
    "update_piholeservers"
)

# Function to display usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [-h] [-d directory] [-i inventory] [-p parameters]
Run multiple Ansible playbooks sequentially.

Options:
    -h          Show this help message
    -d DIR      Set ansible directory (default: ${RUNDIR})
    -i FILE     Set inventory file (default: ${INVENTORY})
    -p PARAMS   Additional ansible-playbook parameters
EOF
    exit 1
}

# Main execution function
run_playbooks() {
    local run_dir="$1"
    local inventory="$2"
    local params="$3"
    local exit_status=0

    echo "Starting playbook execution..."
    for action in "${ACTIONS[@]}"; do
        echo "Running playbook: ${action}"
        if ! ansible-playbook "${run_dir}/${action}.yaml" ${params} -i "${run_dir}/${inventory}"; then
            echo "Error running playbook: ${action}" >&2
            exit_status=1
        fi
    done

    return $exit_status
}

# Parse command line arguments
working_dir="${RUNDIR}"
inv_file="${INVENTORY}"
parameters=""

while getopts "hd:i:p:" opt; do
    case ${opt} in
        h)
            usage
            ;;
        d)
            working_dir="${OPTARG}"
            ;;
        i)
            inv_file="${OPTARG}"
            ;;
        p)
            parameters="${OPTARG}"
            ;;
        \?)
            usage
            ;;
    esac
done

# Verify directory and inventory exist
[[ -d "${working_dir}" ]] || { echo "Error: Directory ${working_dir} not found" >&2; exit 1; }
[[ -f "${working_dir}/${inv_file}" ]] || { echo "Error: Inventory file ${working_dir}/${inv_file} not found" >&2; exit 1; }

# Execute playbooks
run_playbooks "${working_dir}" "${inv_file}" "${parameters}"
