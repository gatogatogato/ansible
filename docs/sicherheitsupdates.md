# Tägliche Sicherheitsupdates

Alle LXCs und VMs werden sonntags um 03:30 aktualisiert (`run.sh updates`). Für die Container,
die Verkehr aus dem Internet sehen, wären das bis zu 7 Tage mit einer bekannten Lücke. Darum
holt `run.sh security-updates` für diese Container jeden Morgen die Sicherheitsupdates.

| | |
| --- | --- |
| Playbook | `security_updates.yaml`, Vorlage `templates/50unattended-upgrades.j2` |
| Container | Gruppe `security_daily` in `inventory.yaml`: cloudflared1, cloudflared2, websrv, npm, vaultwarden |
| Lauf | täglich 06:30 auf debian-ansible (`cron-run.sh security-updates`) |
| Log | debian-ansible `/home/transport/logs/ansible-security-updates-<Datum>_<Uhrzeit>.log` |
| Meldung | Uptime-Kuma-Push-Monitor „Sicherheitsupdates“ |

## Was passiert

Ein Container nach dem anderen:

- **Debian:** `unattended-upgrade` installiert nur Pakete aus Debian-Security. Auf cloudflared1/2
  kommt zusätzlich Cloudflares Repo dazu (`security_updates_extra_sites`), weil cloudflared selbst
  das Programm am Internet ist. Danach startet `needrestart` die Dienste neu, die noch alte
  Bibliotheken benutzen (z. B. Apache nach einem OpenSSL-Update). Auf cloudflared wartet der Lauf,
  bis der Connector wieder mit Cloudflare verbunden ist, bevor der zweite drankommt; der Tunnel
  bleibt also oben. Zum Schluss dieselbe Prüfung wie bei `run.sh updates`: alle Ports, die vorher
  offen waren, müssen wieder offen sein, und kein Dienst darf neu ausgefallen sein.
- **Alpine (vaultwarden):** `apk upgrade`, Vaultwarden wird nur neu gestartet, wenn sich etwas
  geändert hat. Alpines stabile Versionen bekommen nur Fehlerbehebungen.

Nie automatisch: **Neustarts** (wenn einer nötig ist, steht es im Log, und der Sonntagslauf macht
ihn) und alle anderen Updates (warten auf Sonntag). Aufräumen macht weiterhin `run.sh cleanup`.

Der apt-Timer im Container führt `unattended-upgrade` nicht selbst aus
(`/etc/apt/apt.conf.d/20auto-upgrades` steht auf `0`), so gibt es nur einen Lauf pro Tag und
keinen Konflikt mit dem Sonntagslauf. needrestart listet bei normalen apt-Läufen nur auf und
startet nichts neu (`/etc/needrestart/conf.d/ansible.conf`).

Nicht abgedeckt: Programme, die nicht als Debian-Paket kommen, z. B. Nginx Proxy Manager selbst
auf npm (nur das Debian darunter wird aktualisiert).

## Wann wird es rot

Wenn ein Update fehlschlägt, ein Container nicht erreichbar ist, ein Dienst nach dem Neustart
nicht mehr läuft oder ein Connector sich nicht wieder verbindet. Im Kuma-Text steht der
Container, die Einzelheiten im Log.

## Einrichten (einmal)

1. Nach dem Merge auf **debian-ansible als `transport`** (als gato
   einloggen, dann `sudo -iu transport`) das Repo holen und einen ersten Lauf von Hand machen:
   ```
   clone.sh
   run.sh security-updates
   ```
   Am Ende `failed=0 unreachable=0` bei allen fünf Containern. Beim ersten Lauf werden
   unattended-upgrades und needrestart installiert.

2. In Uptime Kuma einen Monitor anlegen: Typ **Push**, Name „Sicherheitsupdates“, Gruppe
   „Jobs“, Heartbeat-Intervall **90000** Sekunden (25 Stunden). Die Push-URL kopieren.

3. Auf **debian-ansible als `transport`** die Push-URL ablegen (URL einsetzen):
   ```
   install -m 600 /dev/null ~/.config/ansible-security-updates.env
   echo 'UPTIME_KUMA_PUSH_URL="https://<kuma>/api/push/<token>"' > ~/.config/ansible-security-updates.env
   ```

4. Auf **debian-ansible als `transport`** den Cronjob anlegen und einmal so laufen lassen, wie
   cron es tut (meldet an Kuma):
   ```
   run.sh cronjobs --limit ansible
   crontab -l | grep "security updates"
   ~/ansible/cron-run.sh security-updates; echo $?
   ```
   `0` und ein grüner Monitor in Kuma heisst: fertig.

## Weitere Container aufnehmen

Den Host in `inventory.yaml` unter `security_daily` eintragen. Braucht er ein Programm aus einem
fremden apt-Repo täglich, dessen Server unter `security_updates_extra_sites` beim Host angeben
(so wie `pkg.cloudflare.com` bei der Gruppe `cloudflared`).
