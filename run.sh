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
    updates           apt (Debian), apk (Alpine), micro plugins, Beszel, then cleanup
    security-updates  daily security updates for the hosts reachable from the internet,
                      no reboot (docs/sicherheitsupdates.md)
    updates-proxmox   apt on the Proxmox nodes
    updates-proxmox-check
                      read-only: fail for nodes whose updates wait longer than 30 days
                      (Uptime Kuma reminder, docs/proxmox-updates.md)
    helper-tag        remove the tag proxmox-helper-scripts from all guests, weekly cronjob on
                      n01 and n02 (docs/proxmox-helper-tag.md)
    hostconfig-backup save /etc/pve, network, cron etc. of the Proxmox nodes to debian-ansible
                      and the TrueNAS share NAS-SMB (docs/proxmox-hostconfig.md)
    beszel            install the Beszel agents where missing, bring agents and hub to the
                      latest release (docs/beszel.md)
    cleanup           free disk space in all LXCs and VMs: unused packages, package cache,
                      journal, old rotated logs, dangling Docker images (docs/aufraeumen.md)
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
    inventar-setup    set up debian-inventar: packages, inventar repo checkout, venv,
                      secrets file, collector timer, web page (docs/inventar.md)
    inventar-deploy   pull the inventar repo on debian-inventar, restart the web page
    inventar-secrets-backup
                      copy debian-inventar's secrets file to debian-ansible
    camsnaps-setup    set up debian-camsnaps: camera snapshot gallery from the camsnaps repo,
                      its own user and key for Home Assistant, cronjobs (docs/camsnaps.md)
    camsnaps-deploy   pull the camsnaps repo on debian-camsnaps
    cloudflared-setup set up the Cloudflare Tunnel connectors: package, token file,
                      metrics port for Uptime Kuma, one restart at a time (docs/cloudflared.md)
    cloudflared-token-backup
                      copy the tunnel token from a connector to debian-ansible
    qdevice-setup     corosync-qnetd on debian-qdevice (the Raspberry Pi), corosync-qdevice
                      on the Proxmox nodes, root key of the nodes on the Pi, hardening and
                      few writes to the SD card on the Pi (docs/qdevice.md)
    vaultwarden-backup
                      install the nightly backup script from the shell repo on vaultwarden
                      (docs/vaultwarden-backup.md)

Options:
    -h    Show this help message
    -f    Full output (also show unchanged and skipped tasks)

Everything after TASK is passed to ansible-playbook, e.g.
    $(basename "$0") updates --limit pihole1 --check
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
                   update_debianservers_micro inventar_ansible_hosts beszel cleanup) ;;
    cleanup)
        playbooks=(cleanup) ;;
    beszel)
        playbooks=(beszel) ;;
    security-updates)
        # Show the upgraded packages and waiting reboots in the log
        export ANSIBLE_DISPLAY_OK_HOSTS=true
        playbooks=(security_updates) ;;
    updates-proxmox)
        playbooks=(update_proxmoxservers_apt) ;;
    updates-proxmox-check)
        export ANSIBLE_DISPLAY_OK_HOSTS=true
        playbooks=(proxmox_update_check) ;;
    helper-tag)
        # Show which guests lost the tag
        export ANSIBLE_DISPLAY_OK_HOSTS=true
        playbooks=(proxmox_helper_tag) ;;
    hostconfig-backup)
        playbooks=(proxmox_hostconfig_backup) ;;
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
    inventar-setup)
        playbooks=(inventar_setup inventar_ansible_hosts) ;;
    inventar-deploy)
        # Show the pulled commit
        export ANSIBLE_DISPLAY_OK_HOSTS=true
        playbooks=(inventar_deploy inventar_ansible_hosts) ;;
    inventar-secrets-backup)
        playbooks=(inventar_secrets_backup) ;;
    camsnaps-setup)
        playbooks=(camsnaps_setup) ;;
    camsnaps-deploy)
        # Show the pulled commit
        export ANSIBLE_DISPLAY_OK_HOSTS=true
        playbooks=(camsnaps_deploy) ;;
    cloudflared-setup)
        playbooks=(cloudflared_setup) ;;
    cloudflared-token-backup)
        playbooks=(cloudflared_token_backup) ;;
    vaultwarden-backup)
        playbooks=(vaultwarden_backup) ;;
    qdevice-setup)
        playbooks=(qdevice_setup qdevice_harden) ;;
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
