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

## License
See [LICENSE](LICENSE).
