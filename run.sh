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
    updates           apt (Debian), apk (Alpine), micro plugins
    updates-proxmox   apt on the Proxmox nodes
    install           install packages on the Debian servers
    cronjobs          create cronjobs
    shutdown          shut down hercules, flickr and the ansible server
    harden-ssh        allow the transport key only from the ansible server,
                      gato needs a password for sudo
    audit-key         show where the private transport key lies (read-only)
    remove-key        delete it everywhere except the ansible server and hosts whose cron uses ssh
    bootstrap         make a new LXC reachable (--limit proxmox-n0X -e ctid=NNN)
    newserver         basic setup of a new Debian host (--limit NAME)
    website-setup     prepare websrv for the website: packages, Apache virtual host,
                      website repo checkout (docs/webseite.md)
    website-deploy    pull the website repo on websrv and run its deploy script
    glance-setup      prepare debian-glance for the glance config repo: deploy key,
                      checkout, glance-deploy script (docs/glance.md)
    glance-deploy     deploy glance.yml and assets from the glance repo, restart Glance
    flickr-server     set up a (new) debian-flickr completely: packages, folders, web server,
                      secrets, uploader, commenter, cronjobs (docs/flickr-server.md)
    flickr-secrets-backup
                      copy debian-flickr's keys and tokens to debian-ansible
    uploader-setup    prepare debian-flickr for the flickr-uploader repo: deploy key,
                      checkout, flickr-uploader-deploy, cronjobs (docs/flickr-uploader.md)
    uploader-deploy   pull the flickr-uploader repo on debian-flickr
    commenter-setup   check out / update flickr-scripts on debian-flickr for the commenter

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
                   update_debianservers_micro) ;;
    updates-proxmox)
        playbooks=(update_proxmoxservers_apt) ;;
    install)
        playbooks=(install_all_packages install_webservers_packages
                   install_flickrservers_packages install_ansibleservers_packages) ;;
    cronjobs)
        playbooks=(cronjobs_webservers cronjobs_flickrservers cronjobs_ansibleservers
                   cronjobs_alpineservers cronjobs_glance) ;;
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
    website-setup)
        playbooks=(install_webservers_packages website_apache website_setup) ;;
    website-deploy)
        # Show the pulled commit and the output of deploy.sh
        export ANSIBLE_DISPLAY_OK_HOSTS=true
        playbooks=(website_deploy) ;;
    glance-setup)
        playbooks=(glance_setup) ;;
    glance-deploy)
        # Show the pulled commit and the output of glance-deploy
        export ANSIBLE_DISPLAY_OK_HOSTS=true
        playbooks=(glance_deploy) ;;
    flickr-server)
        playbooks=(install_flickrservers_packages flickr_server_setup flickr_secrets_restore
                   flickr_uploader_setup flickr_commenter_setup cronjobs_flickrservers) ;;
    flickr-secrets-backup)
        playbooks=(flickr_secrets_backup) ;;
    commenter-setup)
        playbooks=(flickr_commenter_setup cronjobs_flickrservers) ;;
    uploader-setup)
        playbooks=(flickr_uploader_setup cronjobs_flickrservers) ;;
    uploader-deploy)
        # Show the pulled commit
        export ANSIBLE_DISPLAY_OK_HOSTS=true
        playbooks=(flickr_uploader_deploy) ;;
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
