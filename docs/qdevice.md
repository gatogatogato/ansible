# QDevice: dritte Stimme für den Proxmox-Cluster

Der Cluster hat zwei Nodes, proxmox-n01 und proxmox-n02. Damit er beim Ausfall eines Nodes
quorate bleibt, gibt ein QDevice die dritte Stimme: `corosync-qnetd` auf dem Raspberry Pi.
Der Pi ist kein Proxmox-Node mehr (früher proxmox-n03), auf ihm läuft nur Raspberry Pi OS.

| | |
| --- | --- |
| Host | debian-qdevice.lan, 192.168.1.23 (statisch per nmcli auf dem Pi, DNS im Pi-hole) |
| Ansible-Name | `qdevice`, in den Gruppen `debianservers` und `qdevices` |
| System | Raspberry Pi OS Lite 64-bit (Trixie), Updates mit `run.sh updates` wie alle Debian-Hosts |
| Dienst | `corosync-qnetd`, Port 5403/TCP, die Nodes verbinden sich dorthin |
| Nodes | `corosync-qdevice` auf proxmox-n01 und proxmox-n02 |
| Einrichten | `run.sh qdevice-setup`, dann einmal `pvecm qdevice setup 192.168.1.23` auf proxmox-n01 |
| Überwachung | Uptime Kuma: Ping debian-qdevice.lan und TCP-Port 5403 |

## Stimmen

| Lage | Stimmen | Cluster |
| --- | --- | --- |
| alles läuft | 3 von 3 | quorate |
| ein Node aus | 2 von 3 | quorate, Gäste auf dem anderen Node laufen weiter |
| Pi aus | 2 von 3 | quorate |
| ein Node und der Pi aus | 1 von 3 | nicht quorate, `/etc/pve` nur lesbar |

Ein Neustart des Pi (etwa nach einem Kernel-Update im Sonntags-Lauf) stört den Cluster nicht.
Raspberry Pi OS legt nach einem Kernel-Update kein `/run/reboot-required` an. Darum vergleicht
`update_debianservers_apt.yaml` auf dem Pi den laufenden mit dem installierten Kernel und startet
ihn bei Bedarf neu.

## Härtung und SD-Karte

`run.sh qdevice-setup` spielt auch `qdevice_harden.yaml` ein. Der Pi läuft von einer SD-Karte,
darum schreibt er so wenig wie möglich, und er bietet nur an, was ein QDevice braucht.

| | |
| --- | --- |
| Journal | nur im RAM (`Storage=volatile`, höchstens 32 MB), nach einem Neustart leer |
| `/` | `noatime,commit=600`: Metadaten höchstens alle 10 Minuten auf die Karte. Ein Stromausfall kann die letzten 10 Minuten verlieren |
| Swap | nur zram im RAM, der Timer `rpi-zram-writeback` (Swap auf die Karte) ist maskiert |
| Timer | `apt-daily`, `apt-daily-upgrade` und `man-db` maskiert; Updates kommen sonntags von debian-ansible |
| entfernt | avahi-daemon (`debian-qdevice.local` geht nicht mehr), bluez, rpi-connect-lite, udisks2 |
| aus | cloud-init (`/etc/cloud/cloud-init.disabled`), wpa_supplicant; WLAN, Bluetooth, Audio, Kamera und Display in `/boot/firmware/config.txt` |
| SSH | root nur von 192.168.1.21 und .22 (`/etc/ssh/sshd_config.d/20-root-from-nodes.conf`), Passwörter für niemanden |
| Firewall | nftables (`/etc/nftables.conf`): eingehend nur Ping, SSH (22) und corosync-qnetd (5403) aus 192.168.1.0/24 |

Wenn sich `config.txt` ändert, startet Ansible den Pi einmal neu; der Cluster bleibt quorate.

Schreiblast messen (auf debian-qdevice als gato), zweimal im Abstand von einer Minute;
die siebte Zahl ist die Summe der geschriebenen Sektoren zu 512 Byte:

```
cat /sys/block/mmcblk0/stat
```

Kurz nach dem Flashen schreibt der Pi viel, weil ext4 die Inode-Tabellen der grossen Partition
im Hintergrund nullt (`ext4lazyinit`). Das hört nach einigen Stunden von selbst auf.

Ausgesperrt (Firewall oder SSH)? Bildschirm und Tastatur an den Pi, als gato anmelden,
`sudo nft flush ruleset` bzw. die Datei in `/etc/ssh/sshd_config.d/` korrigieren.

## Zustand prüfen (auf proxmox-n01 als root)

```
pvecm status
```

Erwartet: `Expected votes: 3`, `Total votes: 3`, `Quorate: Yes`, und in der Liste
„Membership information“ bei beiden Nodes das Flag `A,V,NMW` und eine Zeile `Qdevice`.

Auf dem Pi (als gato):

```
sudo corosync-qnetd-tool -l
```

zeigt beide Nodes als verbunden.

## Pi neu aufsetzen (neue SD-Karte)

1. Wie bei der ersten Einrichtung: Raspberry Pi OS Lite flashen, IP setzen, transport anlegen,
   `run.sh newserver --limit qdevice`, `run.sh harden-ssh --limit qdevice`,
   `run.sh qdevice-setup` (Schritte siehe Projektanleitung „n03 Ersatz durch ein QDevice“).
2. Die Nodes kennen noch das alte Zertifikat. Auf proxmox-n01 als root das QDevice entfernen
   und neu einrichten:
   ```
   pvecm qdevice remove
   pvecm qdevice setup 192.168.1.23
   ```
   Bis dahin hat der Cluster nur 2 Stimmen von 3 und bleibt quorate, solange beide Nodes laufen.

## Was nicht in Ansible ist

`pvecm qdevice setup` und `pvecm qdevice remove` ändern den Cluster und bleiben Handarbeit.
`run.sh qdevice-setup` legt nur die Voraussetzungen hin: die Pakete und den Root-Key der Nodes
auf dem Pi (nur von 192.168.1.21 und .22 aus gültig), mit dem sich `pvecm` dort anmeldet.
