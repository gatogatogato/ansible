# Konfiguration der Proxmox-Hosts sichern

vzdump sichert die Gäste, aber nicht die Nodes selbst. `run.sh hostconfig-backup`
packt pro Node ein kleines tar mit allem, was man für den Neuaufbau eines Nodes braucht.

| | |
| --- | --- |
| Playbook | `proxmox_hostconfig_backup.yaml`, Einstellungen in `inventory.yaml` bei `proxmoxservers` |
| Nodes | proxmox-n01, proxmox-n02, proxmox-n03 |
| Lauf | So 05:00 auf debian-ansible (`cron-run.sh hostconfig-backup`, nach vzdump, vor dem Storj-Upload um 06:00) |
| Kopie 1 | debian-ansible `/home/transport/backups/proxmox-hostconfig/<node>/`, nur `transport` darf lesen |
| Kopie 2 | Share NAS-SMB, also TrueNAS `/mnt/tank01/proxmox-raw-backups/hostconfig/<node>/` |
| Kopie 3 | Storj, über den TrueCloud-Task „Proxmox raw backups“ (ganzes Dataset) |
| Stände | die letzten 8 pro Node, an beiden Orten |
| Log | debian-ansible `/home/transport/logs/ansible-hostconfig-backup-<Datum>.log` |
| Meldung | Uptime-Kuma-Push-Monitor „Proxmox Host-Config“ |

## Was drin ist

`/etc/pve` (Cluster-Konfiguration, Storage, Backup-Jobs, Gast-Configs, Benutzer, und in
`/etc/pve/priv` Schlüssel und das SMB-Passwort), `/etc/network`, `/etc/hosts`, `/etc/hostname`,
`/etc/resolv.conf`, `/etc/fstab`, Cron (`/etc/crontab`, `/etc/cron.d`, `/var/spool/cron/crontabs`),
`/root/.ssh`, `/etc/ssh`, Ansible-Zugang (`/home/transport/.ssh`, `/etc/sudoers.d`), `/etc/apt`, Kernel-Module und Boot-Parameter, sysctl, udev-Regeln,
eigene systemd-Units, `/etc/vzdump.conf`, LVM, Postfix, Zeitzone. Dazu `system-info.txt` mit
`pveversion -v`, IP-Adressen, Disks, ZFS-Pools, Cluster- und Storage-Status.

Die Liste steht in `inventory.yaml` (`hostconfig_paths`), was auf einem Node fehlt, wird übersprungen.

Die tars enthalten Geheimnisse. Darum liegen sie auf debian-ansible mit `0600` und sonst nur
im LAN-Share und verschlüsselt bei Storj, nicht in Nextcloud.

## Einrichten (einmal)

1. Auf debian-ansible als `transport` (als gato einloggen, dann `sudo -iu transport`):
   ```
   clone.sh
   run.sh hostconfig-backup
   ls -l /home/transport/backups/proxmox-hostconfig/*/
   ```
   Am Ende muss für jeden Node ein tar da sein. Bricht es mit „No Proxmox node has
   /mnt/pve/NAS-SMB mounted“ ab, ist das Share auf keinem Node eingebunden
   (Datacenter → Storage → NAS-SMB).

2. In Uptime Kuma einen Monitor anlegen: Typ **Push**, Name „Proxmox Host-Config“, Gruppe
   „Jobs“, Heartbeat-Intervall **691200** Sekunden (8 Tage). Die Push-URL kopieren.

3. Auf debian-ansible als `transport` die Push-URL ablegen (URL einsetzen):
   ```
   install -m 600 /dev/null ~/.config/ansible-hostconfig-backup.env
   echo 'UPTIME_KUMA_PUSH_URL="https://<kuma>/api/push/<token>"' > ~/.config/ansible-hostconfig-backup.env
   ```

4. Auf debian-ansible als `transport` den Cronjob anlegen und einmal so laufen lassen, wie
   cron es tut (meldet an Kuma):
   ```
   run.sh cronjobs --limit ansible
   crontab -l | grep hostconfig
   ~/ansible/cron-run.sh hostconfig-backup; echo $?
   ```
   `0` und ein grüner Monitor in Kuma heisst: fertig.

## Hineinschauen

Auf debian-ansible als `transport`:
```
tar -tzvf /home/transport/backups/proxmox-hostconfig/proxmox-n01/hostconfig-proxmox-n01-<Datum>.tar.gz
tar -xzOf /home/transport/backups/proxmox-hostconfig/proxmox-n01/hostconfig-proxmox-n01-<Datum>.tar.gz etc/network/interfaces
```

## Zurückspielen

Nie ein ganzes tar über einen laufenden Node auspacken, und `etc/pve` nie in einen laufenden
Cluster zurückschreiben, das überschreibt die Konfiguration aller Nodes.

**Ein Node ist kaputt, die anderen laufen:**
1. Den toten Node auf einem gesunden Node als root aus dem Cluster nehmen:
   `pvecm delnode proxmox-n0X`.
2. Proxmox neu installieren, gleicher Name, gleiche IP.
3. tar auf den neuen Node kopieren (auf debian-ansible als `transport`):
   `scp /home/transport/backups/proxmox-hostconfig/proxmox-n0X/hostconfig-proxmox-n0X-<Datum>.tar.gz root@proxmox-n0X.lan:/root/`
4. Auf dem neuen Node als root einzelne Dateien vergleichen und übernehmen, zuerst Netzwerk:
   ```
   mkdir /root/restore && tar -xzf /root/hostconfig-proxmox-n0X-<Datum>.tar.gz -C /root/restore
   diff /root/restore/etc/network/interfaces /etc/network/interfaces
   cp /root/restore/etc/network/interfaces /etc/network/interfaces && ifreload -a
   ```
   Danach bei Bedarf `/etc/hosts`, `/etc/modules`, `/etc/kernel/cmdline`, Cron, `/root/.ssh`.
5. Dem Cluster wieder beitreten: auf dem neuen Node als root `pvecm add proxmox-n01.lan`
   (bzw. einen anderen gesunden Node). `/etc/pve` kommt dann vom Cluster.
6. Ansible-Zugang wiederherstellen, auf dem neuen Node als root:
   ```
   apt install -y sudo
   useradd -m -s /bin/bash transport
   cp -a /root/restore/home/transport/.ssh /home/transport/ && chown -R transport:transport /home/transport/.ssh
   cp /root/restore/etc/sudoers.d/* /etc/sudoers.d/ && visudo -c
   ```
   Test auf debian-ansible als `transport`: `run.sh hostconfig-backup --limit proxmox-n0X`.

**Alles weg:** Proxmox neu installieren und den Cluster neu bauen. Aus `etc/pve` im tar
`storage.cfg`, `jobs.cfg`, `user.cfg`, `datacenter.cfg` von Hand übernehmen, die Gäste mit
vzdump zurückholen (die Gast-Configs stecken auch im vzdump-Archiv).
