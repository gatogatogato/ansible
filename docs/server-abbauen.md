# Server vollständig abbauen

Checkliste, damit von einem LXC oder einer VM nichts übrig bleibt. Beispiel:
Host `foo` (`debian-foo.lan`), CTID `118` auf `proxmox-n01`.

Reihenfolge: erst alles, was auf den Server zeigt, dann den Server selbst.
So gibt es zwischendurch keine Fehlalarme.

## 1. Nachschauen, wo der Server überall vorkommt

Auf debian-ansible als transport:

```
grep -rn "foo" /home/transport/ansible --include=*.yaml
```

Findet Inventory, eigene Install- und Cronjob-Playbooks und Einträge wie in
`shutdown_unproductive.yaml`.

## 2. Überwachung und Zugriffe von aussen entfernen

In den Weboberflächen:

- **Uptime Kuma:** Monitore für foo löschen (und von der Statusseite nehmen).
- **Nginx Proxy Manager:** Proxy Hosts und zugehörige SSL-Zertifikate löschen.
- **Cloudflare Tunnel:** Public Hostnames, die auf foo zeigen, im Cloudflare-Dashboard entfernen.
- **Glance:** Links oder Widgets zu foo aus der Konfiguration nehmen.
- **Changedetection:** Watches auf foo löschen, falls vorhanden.

## 3. Aus Ansible entfernen

In `inventory.yaml` den Host löschen, ebenso eigene Playbooks
(z. B. `install_foo_packages.yaml`, `cronjobs_foo.yaml`) und deren Einträge in
`run.sh`. Committen und pushen (oder Claude darum bitten), dann auf debian-ansible:

```
/home/transport/clone.sh
ssh-keygen -R debian-foo.lan
```

Der zweite Befehl entfernt den Host-Key aus den known_hosts von transport.

## 4. Container oder VM löschen

Auf dem Proxmox-Node als root. Zuerst prüfen, dass es der richtige ist:

```
pct config 118 | grep hostname
pct stop 118
pct destroy 118 --purge --destroy-unreferenced-disks
```

`--purge` entfernt die CTID auch aus Backup-Jobs, Replikation und HA.
Bei einer VM: `qm config`, `qm stop`, `qm destroy <VMID> --purge --destroy-unreferenced-disks`.

## 5. Alte Backups löschen

In der Proxmox-Oberfläche unter dem Backup-Storage die vzdump-Dateien von
CTID 118 löschen. Oder auf dem Node:

```
pvesm list <storage> --vmid 118
pvesm free <volume-id>
```

Erst löschen, wenn du sicher bist, dass du nichts mehr daraus brauchst.

## 6. Netzwerk aufräumen

- **UniFi:** Feste IP-Reservierung (Fixed IP) und allfällige Port-Weiterleitungen oder Firewall-Regeln für foo löschen.
- **Pi-hole:** Unter *Local DNS* die Einträge `debian-foo.lan` (A und CNAME) löschen. Auf dem primären Pi-hole (192.168.1.99), nebula-sync überträgt es auf den zweiten.

## 7. Auf dem Mac

```
ssh-keygen -R debian-foo.lan
```

Und in `~/.ssh/config` einen eventuellen `Host foo`-Block entfernen.

## 8. Kontrolle

```
ping -c1 debian-foo.lan
```

Sollte „unknown host“ melden. Auf debian-ansible darf
`grep -rn foo /home/transport/ansible --include=*.yaml` nichts mehr finden.
