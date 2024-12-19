#!/bin/bash

# Set strict error handling
set -euo pipefail

REQUIRED_USER="transport"
REPO_URL="https://github.com/gatogatogato/ansible"
ANSIBLE_DIR="${HOME}/ansible"

# Print header with consistent formatting
print_header() {
    printf '%s\n' \
        "* * * * * * * * * * * * * * * * * * * * * * * *" \
        "*                                             *" \
        "*   This script must run as user ${REQUIRED_USER}" \
        "*                                             *" \
        "* * * * * * * * * * * * * * * * * * * * * * * *"
}

# Check if running as correct user
check_user() {
    if [[ "${USER}" != "${REQUIRED_USER}" ]]; then
        echo "Error: Script must be run as user '${REQUIRED_USER}'" >&2
        echo "Error: Current user is '${USER}'" >&2
        exit 1
    fi
}

# Main script execution
main() {
    print_header
    check_user

    echo "Cloning repository..."
    if [[ -d "${ANSIBLE_DIR}" ]]; then
        echo "Removing existing ansible directory..."
        rm -rf "${ANSIBLE_DIR}"
    fi

    git clone "${REPO_URL}" "${ANSIBLE_DIR}" || {
        echo "Error: Failed to clone repository '${REPO_URL}'" >&2
        exit 1
    }

    echo "Backing up clone script..."
    if command -v at >/dev/null 2>&1; then
        echo "cp '${ANSIBLE_DIR}/clone.sh' '${HOME}/clone.sh'" | at now || {
            echo "Error: Failed to schedule backup using 'at', falling back to direct copy" >&2
            cp "${ANSIBLE_DIR}/clone.sh" "${HOME}/clone.sh" || {
                echo "Error: Failed to backup clone script" >&2
                exit 1
            }
        }
    else
        cp "${ANSIBLE_DIR}/clone.sh" "${HOME}/clone.sh" || {
            echo "Error: Failed to backup clone script" >&2
            exit 1
        }
    fi

    echo "Script completed successfully."
}

main