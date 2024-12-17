#!/bin/bash

# Set strict error handling
set -euo pipefail

REQUIRED_USER="transport"
REPO_URL="https://github.com/gatogatogato/ansible"
ANSIBLE_DIR="${HOME}/ansible"

# Print header with consistent formatting
print_header() {
    echo "----------------------------------------"
    echo "This script MUST run as user: $REQUIRED_USER"
    echo "----------------------------------------"
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

    echo "Starting in 5 seconds... (Ctrl+C to cancel)"
    sleep 5

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
    cp "${ANSIBLE_DIR}/clone.sh" "${HOME}/clone.sh" || {
        echo "Error: Failed to backup clone script"
        exit 1
    }

    echo "Script completed successfully."
}

main