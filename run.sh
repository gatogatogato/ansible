#!/bin/bash
# Run a group of playbooks against the inventory in this repo.
# Replaces the former run-updates-*.sh, run-install.sh, run-cronjobs.sh
# and run-shutdown-unproductive.sh.

set -euo pipefail

readonly REQUIRED_USER="transport"
readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INVENTORY="${REPO_DIR}/inventory.yaml"

usage() {
    cat << EOF
Usage: $(basename "$0") [-h] [-f] TASK [ansible-playbook options]

Tasks:
    updates           apt (Debian), apk (Alpine), micro plugins, snap
    updates-proxmox   apt on the Proxmox nodes
    install           install packages on all servers
    cronjobs          create cronjobs
    shutdown          shut down hercules, flickr and the ansible server
    harden-ssh        allow the transport key only from the ansible server,
                      gato needs a password for sudo
    audit-key         show where the private transport key lies (read-only)
    remove-key        delete it everywhere except the ansible server and hosts whose cron uses ssh
    bootstrap         make a new LXC reachable (--limit proxmox-n0X -e ctid=NNN)
    newserver         basic setup of a new Debian host (--limit NAME)

Options:
    -h    Show this help message
    -f    Full output (also show unchanged and skipped tasks)

Everything after TASK is passed to ansible-playbook, e.g.
    $(basename "$0") updates --limit pihole --check
EOF
    exit 1
}

while getopts "hf" opt; do
    case ${opt} in
        f) export ANSIBLE_DISPLAY_OK_HOSTS=true ANSIBLE_DISPLAY_SKIPPED_HOSTS=true ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))
[[ $# -ge 1 ]] || usage
task="$1"
shift

case "${task}" in
    updates)
        playbooks=(update_debianservers_apt update_alpineservers_apk
                   update_debianservers_micro update_webservers_snap) ;;
    updates-proxmox)
        playbooks=(update_proxmoxservers_apt) ;;
    install)
        playbooks=(install_all_packages install_webservers_packages
                   install_flickrservers_packages install_ansibleservers_packages) ;;
    cronjobs)
        playbooks=(cronjobs_webservers cronjobs_flickrservers cronjobs_ansibleservers) ;;
    shutdown)
        echo "Shutting down non-productive servers!"
        playbooks=(shutdown_unproductive) ;;
    harden-ssh)
        playbooks=(harden_transport_ssh) ;;
    audit-key)
        playbooks=(audit_transport_key) ;;
    remove-key)
        playbooks=(remove_transport_private_key) ;;
    bootstrap)
        playbooks=(bootstrap_lxc) ;;
    newserver)
        playbooks=(install_all_packages newserver_setup_basics newserver_install_all_basicfiles
                   update_debianservers_apt) ;;
    *)
        echo "Error: unknown task '${task}'" >&2
        usage ;;
esac

# These rewrite basic setup, never run them on every host by accident
if [[ "${task}" == "bootstrap" || "${task}" == "newserver" ]] && [[ " $* " != *" --limit "* && " $* " != *" --limit="* && " $* " != *" -l "* ]]; then
    echo "Error: '${task}' needs --limit, see docs/neue-maschine.md" >&2
    exit 1
fi

# cron does not always set USER, so ask id
if [[ "$(id -un)" != "${REQUIRED_USER}" ]]; then
    echo "Error: Script must be run as user '${REQUIRED_USER}', not '$(id -un)'" >&2
    exit 1
fi

# Use the repo's ansible.cfg (compact output) regardless of the current directory
export ANSIBLE_CONFIG="${REPO_DIR}/ansible.cfg"

exit_status=0
for playbook in "${playbooks[@]}"; do
    if ! ansible-playbook "${REPO_DIR}/${playbook}.yaml" -i "${INVENTORY}" "$@"; then
        echo "Error: Playbook '${playbook}' exited with non-zero status" >&2
        exit_status=1
        # newserver steps build on each other, so stop at the first failure
        [[ "${task}" == "newserver" ]] && break
    fi
done
exit ${exit_status}
