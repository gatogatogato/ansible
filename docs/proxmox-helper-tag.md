# Tag „proxmox-helper-scripts“ entfernen

Die Proxmox Helper Scripts hängen jedem neuen Gast das Tag `proxmox-helper-scripts` an.
`run.sh helper-tag` richtet auf den Nodes ein, dass es jede Woche wieder entfernt wird.

| | |
| --- | --- |
| Playbook | `proxmox_helper_tag.yaml`, Skript `files/proxmox-remove-helper-tag.sh` |
| Nodes | proxmox-n01, proxmox-n02 (n03 hat keine Gäste und wird übersprungen) |
| Lauf | So 04:30, Cronjob von root auf dem Node (`/etc/cron.d/proxmox-remove-helper-tag`) |
| Skript auf dem Node | `/usr/local/sbin/proxmox-remove-helper-tag.sh` |
| Log | Syslog des Nodes: `journalctl -t proxmox-helper-tag` |

Das Skript geht durch alle VMs (`qm`) und Container (`pct`) des jeweiligen Nodes und ändert nur
Gäste, die das Tag tatsächlich haben. Andere Tags bleiben. Bleibt kein Tag übrig, wird das
Tag-Feld ganz entfernt.

## Einrichten

Auf debian-ansible als `transport` (als gato einloggen, dann `sudo -iu transport`):
```
clone.sh
run.sh helper-tag
```
Der Lauf installiert Skript und Cronjob und führt das Skript einmal aus. Pro Node steht im
Log, welche Gäste das Tag verloren haben.

## Prüfen

Auf proxmox-n01 oder proxmox-n02 als root:
```
cat /etc/cron.d/proxmox-remove-helper-tag
journalctl -t proxmox-helper-tag --since "8 days ago"
```
Neue Gäste von den Helper Scripts behalten das Tag bis zum nächsten Sonntag. Sofort entfernen:
```
/usr/local/sbin/proxmox-remove-helper-tag.sh
```
