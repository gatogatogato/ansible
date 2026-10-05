# Aufräumen in den Containern und VMs

`run.sh cleanup` macht in allen LXCs und VMs Platz auf der Festplatte. Die Proxmox-Nodes
bleiben aussen vor. Es läuft automatisch am Ende jedes `run.sh updates`, also auch im
wöchentlichen Lauf am Sonntag 03:30, und meldet Fehler über denselben Uptime-Kuma-Monitor.

| | |
| --- | --- |
| Playbook | `cleanup.yaml`, alte Logs in `tasks/cleanup_rotated_logs.yaml` |
| Hosts | `debianservers` (ausgeschaltete werden übersprungen) und `alpineservers` |
| Lauf | mit `run.sh updates` (Cron So 03:30) oder allein mit `run.sh cleanup` |

## Was weggeräumt wird

Debian:
- Pakete, die niemand mehr braucht (`apt autoremove --purge`), auch alte Kernel in VMs
- Konfiguration von früher entfernten Paketen (dpkg-Status `rc`)
- der apt-Paket-Cache (`apt clean`)
- das Journal: höchstens 200 MB und 1 Monat (Drop-in `/etc/systemd/journald.conf.d/50-size.conf`,
  ohne das nimmt journald bis zu 10 % der Platte)
- rotierte Logs in `/var/log` (`*.1`, `*.gz` usw.), die älter als 4 Wochen sind
- ungetaggte Docker-Images (`docker image prune`), nur wo Docker installiert ist

Alpine (vaultwarden): der apk-Cache und rotierte Logs älter als 4 Wochen.

Nicht angefasst: laufende Logs, Docker-Volumes und getaggte Images, `/tmp` und `/var/tmp`
(räumt systemd-tmpfiles selbst auf).

Pro Host steht im Ausgabe-Log, wie viel frei wurde und wie voll `/` jetzt ist, z.B.
`Freed 312 MB, / is 41% full`.

## Von Hand

Auf debian-ansible als transport:

```
/home/transport/ansible/run.sh cleanup --check          # nur zeigen, was passieren würde
/home/transport/ansible/run.sh cleanup --limit pihole   # nur ein Host
/home/transport/ansible/run.sh cleanup
```
