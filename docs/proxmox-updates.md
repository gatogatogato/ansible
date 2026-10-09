# Erinnerung an Proxmox-Updates

Die Proxmox-Nodes werden nur von Hand aktualisiert (`run.sh updates-proxmox`). Damit das nicht
vergessen geht, prüft `run.sh updates-proxmox-check` jeden Morgen, wie lange Updates schon warten,
und meldet das an Uptime Kuma. Installiert wird dabei nichts.

| | |
| --- | --- |
| Playbook | `proxmox_update_check.yaml`, Grenze `proxmox_update_max_days` (30) in `inventory.yaml` bei `proxmoxservers` |
| Nodes | proxmox-n01, proxmox-n02, proxmox-n03 (ausgeschaltete werden übersprungen) |
| Lauf | täglich 07:00 auf debian-ansible (`cron-run.sh updates-proxmox-check`) |
| Log | debian-ansible `/home/transport/logs/ansible-updates-proxmox-check-<Datum>_<Uhrzeit>.log` |
| Meldung | Uptime-Kuma-Push-Monitor „Proxmox Updates“ |

## Wann wird es rot

Ein Node gilt als fällig, wenn **Updates warten** und das **letzte apt-Upgrade älter als 30 Tage**
ist (Datum aus `/var/log/apt/history.log*`). Ohne wartende Updates bleibt es grün, egal wie lange
das letzte Upgrade her ist. Die Paketlisten frischt der Check höchstens einmal am Tag auf.

Ob ein Neustart wartet (neuerer Kernel installiert als der laufende), steht nur im Log und
macht den Monitor nicht rot.

Nach `run.sh updates-proxmox` wird der Monitor beim nächsten Lauf um 07:00 wieder grün, oder
sofort mit `~/ansible/cron-run.sh updates-proxmox-check`.

## Einrichten (einmal)

1. Auf debian-ansible als `transport` (als gato einloggen, dann `sudo -iu transport`):
   ```
   clone.sh
   run.sh updates-proxmox-check
   ```
   Pro Node steht eine Zeile wie „3 updates waiting, last upgrade 2026-09-27 (7 days ago),
   reboot waiting: no“.

2. In Uptime Kuma einen Monitor anlegen: Typ **Push**, Name „Proxmox Updates“, Gruppe
   „Jobs“, Heartbeat-Intervall **90000** Sekunden (25 Stunden). Die Push-URL kopieren.

3. Auf debian-ansible als `transport` die Push-URL ablegen (URL einsetzen):
   ```
   install -m 600 /dev/null ~/.config/ansible-updates-proxmox-check.env
   echo 'UPTIME_KUMA_PUSH_URL="https://<kuma>/api/push/<token>"' > ~/.config/ansible-updates-proxmox-check.env
   ```

4. Auf debian-ansible als `transport` den Cronjob anlegen und einmal so laufen lassen, wie
   cron es tut (meldet an Kuma):
   ```
   run.sh cronjobs --limit ansible
   crontab -l | grep "proxmox update"
   ~/ansible/cron-run.sh updates-proxmox-check; echo $?
   ```
   `0` und ein grüner Monitor in Kuma heisst: fertig. `1` heisst: ein Node ist schon fällig,
   dann `run.sh updates-proxmox`.
