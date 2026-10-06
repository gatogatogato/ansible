# ansible
Just my ansible stuff to set up and update my LXCs and VMs in a structured manner.

Everything runs on the ansible server as user `transport`, repo in `/home/transport/ansible`.
`clone.sh` and `run.sh` also work without a path (wrappers in `/usr/local/bin`, set up by `run.sh newserver --limit ansible`).

## Setup and update
```
/home/transport/clone.sh
```
Clones the repo on first use, afterwards only does a `git pull`. Bootstrap once with
`git clone https://github.com/gatogatogato/ansible /home/transport/ansible && /home/transport/ansible/clone.sh`.

## Running playbooks
```
/home/transport/ansible/run.sh updates           # apt, apk, micro on all LXCs and VMs, then cleanup
/home/transport/ansible/run.sh cleanup           # free disk space in all LXCs and VMs (docs/aufraeumen.md)
/home/transport/ansible/run.sh updates-proxmox   # apt on the Proxmox nodes
/home/transport/ansible/run.sh updates-proxmox-check  # read-only: have updates waited too long?
/home/transport/ansible/run.sh install
/home/transport/ansible/run.sh cronjobs
/home/transport/ansible/run.sh shutdown
/home/transport/ansible/run.sh harden-ssh        # transport key only from the ansible server, gato sudo with password
/home/transport/ansible/run.sh audit-key         # read-only: where the private transport key lies
/home/transport/ansible/run.sh remove-key        # delete it there (keeps it where cron uses ssh)
```
`-f` shows the full output. Everything after the task goes to `ansible-playbook`,
e.g. `run.sh updates --limit pihole1`.

After an apt upgrade every host is checked: all ports that listened before must listen
again and no service may newly fail. Otherwise the host is marked as failed.

## Emergency
What to do when DNS, a node, TrueNAS, Vaultwarden or everything is gone, rebuild order and
where backups and credentials live (including the offline USB disk LastResort):
[docs/notfall.md](docs/notfall.md).

## New machines
See [docs/neue-maschine.md](docs/neue-maschine.md): `run.sh bootstrap` sets up a new LXC from its
Proxmox node via `pct exec`, `run.sh newserver` does the basic setup.
To remove a server completely, see [docs/server-abbauen.md](docs/server-abbauen.md).

## Glance config
The Glance dashboard config lives in the private repo `gatogatogato/glance`. `run.sh glance-setup`
prepares debian-glance once, afterwards a cronjob deploys every push within 5 minutes,
`run.sh glance-deploy` does it right away. See [docs/glance.md](docs/glance.md).

## flickr uploader
The flickr uploader on debian-flickr lives in the private repo `gatogatogato/flickr-uploader`.
`run.sh uploader-setup` prepares debian-flickr once, afterwards a cronjob pulls every push within
15 minutes (when the server is on), `run.sh uploader-deploy` does it right away.
See [docs/flickr-uploader.md](docs/flickr-uploader.md).
To rebuild debian-flickr from scratch (`run.sh flickr-server`, secrets backup with
`run.sh flickr-secrets-backup`), see [docs/flickr-server.md](docs/flickr-server.md).

## Inventar
debian-inventar collects a list of all devices on the network (UniFi, Pi-hole, NPM, Proxmox,
ping scan), code in the private repo `gatogatogato/inventar`. `run.sh inventar-setup` sets it up
(also from scratch) including a systemd timer that collects every 15 minutes and the web page on
port 8080, `run.sh inventar-deploy` pulls a new version and restarts the web page,
`run.sh inventar-secrets-backup` copies the credentials to debian-ansible. See [docs/inventar.md](docs/inventar.md).

## Camera gallery
debian-camsnaps copies Home Assistant's camera snapshots every 10 minutes and shows them as a
gallery, code in the private repo `gatogatogato/camsnaps`. `run.sh camsnaps-setup` sets it up
(own user and SSH key for Home Assistant, cronjobs), `run.sh camsnaps-deploy` pulls a new version.
See [docs/camsnaps.md](docs/camsnaps.md).

## Vaultwarden backup
The nightly backup script lives in the public repo `gatogatogato/shell` (`vaultwarden-backup.sh`).
`run.sh vaultwarden-backup` installs it on vaultwarden as `/etc/periodic/daily/create-vaultwarden-backup`,
the Uptime Kuma push URL stays in `/etc/vaultwarden-backup.conf` on the container.
See [docs/vaultwarden-backup.md](docs/vaultwarden-backup.md).

## Cloudflare Tunnel
Two connectors of the same tunnel, debian-cloudflared1 (proxmox-n01) and debian-cloudflared2
(proxmox-n02), so the public services survive the loss of one. `run.sh cloudflared-setup` installs
cloudflared, puts the token into `/etc/cloudflared/token` and restarts one connector at a time;
`run.sh cloudflared-token-backup` copies the token to debian-ansible.
See [docs/cloudflared.md](docs/cloudflared.md).

## Proxmox host configuration
vzdump saves the guests, not the nodes. `run.sh hostconfig-backup` packs `/etc/pve`, network,
cron, SSH and a few more files of every Proxmox node into a tar and keeps the newest 8 per node
on debian-ansible and on the TrueNAS share NAS-SMB, from where TrueCloud uploads them.
`run.sh cronjobs` runs it every Sunday at 05:00 via `cron-run.sh hostconfig-backup`.
See [docs/proxmox-hostconfig.md](docs/proxmox-hostconfig.md).

## Proxmox update reminder
The Proxmox nodes are updated by hand. `run.sh cronjobs` installs a daily check (07:00,
`cron-run.sh updates-proxmox-check`) that turns its Uptime Kuma push monitor red when a node has
updates waiting and its last apt upgrade is older than 30 days. It installs nothing.
See [docs/proxmox-updates.md](docs/proxmox-updates.md).

## Weekly updates via cron
`run.sh cronjobs` installs a cronjob (Sunday 03:30) that runs `cron-updates.sh`
(a wrapper for `cron-run.sh updates`, which any run.sh task can use).
It logs to `/home/transport/logs/` and reports to an Uptime Kuma push monitor. The push URL
stays out of the repo, in `/home/transport/.config/ansible-updates.env`:
```
UPTIME_KUMA_PUSH_URL="https://<kuma>/api/push/<token>"
```

On the Alpine servers `run.sh cronjobs` also sets the timezone (Europe/Zurich, Alpine defaults to UTC)
and runs `/etc/periodic/daily` at 00:30. On vaultwarden that is the backup, which has to be done
before the Proxmox backup and the Sunday updates.

## Nightly mirror of the GitHub repos
`run.sh cronjobs` also installs a cronjob (daily 02:00) that runs `git-mirror.sh`. It mirrors
every repo of gatogatogato, private ones and new ones included, as a bare repo, so the code
survives a lost GitHub account. Log in `/home/transport/logs/`, result to its own Uptime Kuma
push monitor. Settings stay out of the repo, in `/home/transport/.config/git-mirror.env` (chmod 600):
```
GITHUB_TOKEN="github_pat_..."              # fine-grained, all repos, Contents and Metadata read-only
MIRROR_DIR="/home/transport/git-mirror"    # optional, e.g. a TrueNAS share later
UPTIME_KUMA_PUSH_URL="https://<kuma>/api/push/<token>"   # optional
```
Restore: `git clone /home/transport/git-mirror/<repo>.git`.

## Checks on GitHub
Every push and pull request runs `yamllint` and `ansible-lint` (which includes
`ansible-playbook --syntax-check`), see `.github/workflows/pruefen.yml`. Rules live in
`.yamllint` and `.ansible-lint`: a few style rules are skipped, and rules where a change would
touch the servers (pipes without pipefail, git via command, missing changed_when, ...) only
warn. Run the same checks locally:
```
pip install ansible ansible-lint yamllint
yamllint . && ansible-lint
```

## License
See [LICENSE](LICENSE).
