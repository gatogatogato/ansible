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
