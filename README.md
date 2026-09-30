# ansible
Just my ansible stuff to set up and update my LXCs and VMs in a structured manner.

Everything runs on the ansible server as user `transport`, repo in `/home/transport/ansible`.

## Setup and update
```
/home/transport/clone.sh
```
Clones the repo on first use, afterwards only does a `git pull`. Bootstrap once with
`git clone https://github.com/gatogatogato/ansible /home/transport/ansible && /home/transport/ansible/clone.sh`.

## Running playbooks
```
/home/transport/ansible/run.sh updates           # apt, apk, micro on all LXCs and VMs
/home/transport/ansible/run.sh updates-proxmox   # apt on the Proxmox nodes
/home/transport/ansible/run.sh install
/home/transport/ansible/run.sh cronjobs
/home/transport/ansible/run.sh shutdown
/home/transport/ansible/run.sh harden-ssh        # transport key only from the ansible server, gato sudo with password
/home/transport/ansible/run.sh audit-key         # read-only: where the private transport key lies
/home/transport/ansible/run.sh remove-key        # delete it there (keeps it where cron uses ssh)
```
`-f` shows the full output. Everything after the task goes to `ansible-playbook`,
e.g. `run.sh updates --limit pihole`.

After an apt upgrade every host is checked: all ports that listened before must listen
again and no service may newly fail. Otherwise the host is marked as failed.

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

## Weekly updates via cron
`run.sh cronjobs` installs a cronjob (Sunday 03:30) that runs `cron-updates.sh`.
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

## License
See [LICENSE](LICENSE).
