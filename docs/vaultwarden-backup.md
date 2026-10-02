# Vaultwarden-Backup verteilen

Das Backup-Skript liegt im öffentlichen Repo `gatogatogato/shell` als
`vaultwarden-backup.sh`, beschrieben in `vaultwarden-backup.md` dort.
`run.sh vaultwarden-backup` bringt es auf den Vaultwarden-Container.

| | |
| --- | --- |
| Container | `debian-vaultwarden.lan` (Alpine, Host `vaultwarden` im Inventory) |
| Skript | `/etc/periodic/daily/create-vaultwarden-backup`, root, `0700` |
| Konfig | `/etc/vaultwarden-backup.conf`, root, `0600`, nur im Container |
| Lauf | täglich 00:30 über `/etc/periodic/daily` (`cronjobs_alpineservers.yaml`) |
| Ziel | `vaultwarden@truenas.lan:/mnt/tank01/vaultwarden-backups/vaultwarden` |
| Checkout auf debian-ansible | `/home/transport/repos/shell` |

## Was das Playbook macht

1. Installiert `openssh-client`, `tar` und `gzip`.
2. Holt bzw. aktualisiert das shell-Repo auf debian-ansible.
3. Legt `/etc/vaultwarden-backup.conf` an, falls sie fehlt. Steht im alten Skript noch eine
   Push-URL (`HC_URL="https://..."`), übernimmt es sie, sonst bleibt der Wert leer.
   Eine vorhandene Konfig wird nie überschrieben.
4. Kopiert das Skript nach `/etc/periodic/daily/create-vaultwarden-backup` (ohne Punkt im
   Namen, sonst überspringt `run-parts` die Datei).
5. Bricht mit einem Hinweis ab, wenn in der Konfig keine Push-URL steht.

Die Push-URL erscheint in keiner Ausgabe (`no_log`).

## Ablauf

Auf debian-ansible als `transport`:

```
sudo -iu transport
run.sh vaultwarden-backup --check --diff   # Probelauf, zeigt die Änderungen am Skript
run.sh vaultwarden-backup
```

Danach im Container als root prüfen:

```
ls -l /etc/periodic/daily/create-vaultwarden-backup /etc/vaultwarden-backup.conf
# erwartet: -rwx------ root root  und  -rw------- root root
grep -c HC_URL= /etc/vaultwarden-backup.conf          # 1, ohne die URL anzuzeigen
/etc/periodic/daily/create-vaultwarden-backup          # optional: einmal von Hand laufen lassen
```

Der Lauf von Hand stoppt Vaultwarden für ein paar Sekunden und meldet `OK: ...` mit der
Grösse des Archivs. In Uptime Kuma sollte der Monitor danach einen frischen Push zeigen.

## Skript ändern

Im shell-Repo ändern, committen, pushen, dann `run.sh vaultwarden-backup` erneut ausführen.
Direkt im Container geänderte Skripte überschreibt der nächste Lauf.

## Push-URL ändern

Nur im Container, als root: `micro /etc/vaultwarden-backup.conf` (oder `vi`). Die URL kommt
aus Uptime Kuma, Monitor des Vaultwarden-Backups, Typ Push.
