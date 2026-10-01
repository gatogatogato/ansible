# Inventar (debian-inventar)

debian-inventar sammelt eine Liste aller Geräte im Netz aus UniFi, Pi-hole,
NPM und Proxmox, dazu einen Ping-Scan. Der Code liegt im privaten Repo
`gatogatogato/inventar`, der Bauplan im Projekt „Optimierungen“. Der Sammler
liest nur, er ändert in keiner Quelle etwas.

| | |
| --- | --- |
| Container | CT 107 auf proxmox-n01, Debian |
| Adresse | 192.168.1.66, `debian-inventar.lan` (statisch im Container, DNS in Pi-hole) |
| Checkout | `/home/gato/Apps/inventar`, gehört gato, venv in `.venv` |
| Befehl | `inventar` (Link auf die venv) |
| Zugangsdaten | `/etc/inventar/secrets.env`, nur gato darf lesen |
| Daten | `/var/lib/inventar/inventar.db` und `notes.yaml`, gehören gato |
| Webseite | http://debian-inventar.lan:8080 (Dienst `inventar-web`) |
| Sammler | alle 15 Minuten (Timer `inventar-collect.timer`) und auf Knopfdruck „Jetzt aktualisieren“ (`inventar-collect-refresh.path`) |
| Kopie der Zugangsdaten | `/home/transport/.config/inventar-secrets/` auf debian-ansible |

Repo und Pfade stehen in `inventory.yaml` beim Host `inventar`.

## Neu aufsetzen (auch nach einem Totalausfall)

1. LXC anlegen, wie in `docs/neue-maschine.md` Schritt 1: CT 107 auf
   proxmox-n01, Hostname `debian-inventar`, IPv4 statisch `192.168.1.66/24`,
   DNS-Eintrag `debian-inventar.lan` in Pi-hole. Nie auf proxmox-n03.
2. Auf debian-ansible als transport, wie in `docs/neue-maschine.md`:

   ```
   /home/transport/clone.sh
   /home/transport/ansible/run.sh bootstrap --limit proxmox-n01 -e ctid=107
   ssh -4 transport@debian-inventar.lan exit
   /home/transport/ansible/run.sh newserver --limit inventar
   ```

3. Den Sammler einrichten:

   ```
   /home/transport/ansible/run.sh inventar-setup
   ```

   Beim allerersten Mal legt der Lauf den Deploy-Key
   `/home/gato/.ssh/inventar_deploy_key` an und bricht mit dem öffentlichen
   Schlüssel ab. Diesen in GitHub eintragen: Repo `gatogatogato/inventar`,
   **Settings > Deploy keys > Add deploy key**, Titel `debian-inventar`,
   **Allow write access nicht anhaken**. Dann `inventar-setup` nochmals.

   `inventar-setup` installiert git, python3-venv und fping, klont das Repo,
   baut die venv und legt `/etc/inventar/secrets.env` an. Liegt auf
   debian-ansible eine Kopie der Zugangsdaten, kommt sie zurück; sonst entsteht
   eine leere Datei zum Ausfüllen. Eine vorhandene Datei wird nie überschrieben.
   Dazu kommen der Ordner `/var/lib/inventar` und die systemd-Units für den
   Timer und die Webseite; beide laufen danach sofort.

## Zugangsdaten

Wie die vier Nur-Lese-Zugänge angelegt werden, steht in `docs/zugaenge.md` im
inventar-Repo. Eintragen auf debian-inventar:

```
sudo -u gato micro /etc/inventar/secrets.env
```

Danach (und nach jeder Änderung) auf debian-ansible sichern:

```
/home/transport/ansible/run.sh inventar-secrets-backup
```

Die Zugangsdaten gehören zusätzlich in Vaultwarden.

## Sammler von Hand laufen lassen

Auf debian-inventar als gato:

```
inventar --demo                         # nur eingebaute Beispieldaten, kein Netz
inventar --sources pihole               # nur eine Quelle abfragen
inventar --json /tmp/inventar.json      # alle Quellen, Tabelle + Rohliste
inventar collect                        # ein Lauf in die Datenbank, wie der Timer
```

## Timer: Sammler alle 15 Minuten

`inventar-collect.timer` startet `inventar-collect.service` 2 Minuten nach dem
Booten und danach alle 15 Minuten. Ein Lauf fragt alle Quellen ab, schreibt den
Stand in die Datenbank, merkt sich jede MAC und IP mit „zuerst/zuletzt gesehen“
und berechnet die Warnungen. Antwortet keine einzige Quelle, gilt der Lauf als
fehlgeschlagen und der letzte Stand bleibt stehen.

Nachsehen auf debian-inventar:

```
systemctl list-timers 'inventar*'             # wann lief er, wann läuft er wieder
journalctl -u inventar-collect -n 50          # Ausgabe der letzten Läufe mit Warnungen
sudo systemctl start inventar-collect         # sofort einen Lauf starten
```

„Jetzt aktualisieren“ auf der Webseite macht dasselbe ohne Anmeldung: Die Seite legt
`/var/lib/inventar/refresh.request` an, `inventar-collect-refresh.path` sieht die Datei und
startet `inventar-collect.service`, der Lauf löscht sie als Erstes. Der Webdienst braucht
dafür keine Rechte an systemd. Hängt ein Knopfdruck, zeigt
`systemctl status inventar-collect-refresh.path` den Zustand.

„DNS anlegen“ geht genauso: Die Seite legt `/var/lib/inventar/dns.request` an,
`inventar-dns.path` startet `inventar-dns.service` (`inventar dns-apply`), das den Eintrag
in Pi-hole anlegt und danach einen Sammler-Lauf anstösst. Pi-hole braucht dafür
`webserver.api.app_sudo` an (docs/zugaenge.md im inventar-Repo). Fehler stehen auf der
Seite und in `journalctl -u inventar-dns`.

Der Dienst läuft als gato mit den Zugangsdaten aus `/etc/inventar/secrets.env`
und darf nur nach `/var/lib/inventar` schreiben. Für den Ping-Scan bekommt er
das Recht CAP_NET_RAW, sonst nichts.

## Webseite

http://debian-inventar.lan:8080 zeigt oben die Warnungen und die nächste freie
IP im statischen Bereich (.10–.99), darunter alle Geräte. Name, Raum, Web-UI und
Notiz lassen sich anklicken und bearbeiten (Enter speichert, Esc bricht ab),
„Warnungen ausblenden“ ist für Geräte, die absichtlich aus sind. Die Seite
fragt keine Quelle ab, sie liest nur die Datenbank; schreiben kann sie nur
Notizen und geplante IPs in diese Datenbank.

Eine Anmeldung hat die Seite nicht. Später kommt sie über NPM als
`https://inventar.mythenstrasse56.net` mit einer Access-Liste, die nur das LAN
zulässt; Ziel ist `http://debian-inventar.lan:8080`. Für Glance liefert
`/api/summary` die Zahl der Warnungen und Geräte, den letzten Lauf und die
nächste freie IP.

```
systemctl status inventar-web
journalctl -u inventar-web -n 50              # Änderungen an Notizen und Fehler
```

## Datenbank und Notizen

Alles liegt in `/var/lib/inventar/`:

| Datei | |
| --- | --- |
| `inventar.db` | SQLite: Läufe, letzter Stand, Verlauf jeder MAC/IP, Notizen |
| `notes.yaml` | alle Notizen als Text, bei jedem Lauf neu geschrieben (Sicherung, nicht von Hand ändern) |

Die alte Numbers-Liste oder eine `notes.yaml` einmalig übernehmen, auf
debian-inventar als gato:

```
inventar import-notes ips-numbers-2026-09-29.csv    # direkt die CSV aus Numbers
inventar import-notes notes.yaml                    # oder die Datei aus inventar.numbers_import
```

Es werden nur leere Felder gefüllt, was schon auf der Webseite eingetragen ist,
bleibt. Die Ausgabe zeigt pro IP, was übernommen und was übersprungen wurde.

## Neue Version ausrollen

Änderungen am Code kommen per Pull Request ins inventar-Repo. Danach auf
debian-ansible:

```
/home/transport/ansible/run.sh inventar-deploy
```

Das holt den neuesten Stand (nur Fast-Forward), installiert ihn neu in die
venv und startet die Webseite neu. Der Timer nimmt beim nächsten Lauf den
neuen Code. Geänderte systemd-Units kommen mit `run.sh inventar-setup`; das holt
ebenfalls den neuesten Code, startet die Webseite neu und stößt gleich einen ersten Sammel-Lauf an.

Vorher auf debian-ansible immer `/home/transport/clone.sh`, damit das Ansible-Repo selbst aktuell ist.

## Abgleich mit dem Ansible-Inventory

`inventar_ansible_hosts.yaml` schreibt die Liste aller Hosts aus `inventory.yaml` (Name, Adresse,
Gruppen) nach `/var/lib/inventar/ansible-hosts.json`. Der Sammler warnt dann bei Proxmox-Gästen,
die in keinem Ansible-Host vorkommen (bekommen keine Updates), und bei Ansible-Hosts, die er im
Netz nicht findet. Die Liste wird mit `inventar-setup`, `inventar-deploy` und den wöchentlichen
`updates` neu geschrieben; nach einer Änderung am Inventory also `run.sh inventar-deploy`, wenn es
nicht bis Sonntag warten soll.

## Überwachung

- **Uptime Kuma, Push-Monitor „Inventar Sammler“** (Gruppe Jobs): Jeder Lauf meldet sich
  mit Geräte- und Warnungszahl. Fällt auch nur eine Quelle aus, meldet er „down“ mit den
  Namen der Quellen. Die Push-URL steht als `UPTIME_KUMA_PUSH_URL` in
  `/etc/inventar/secrets.env`, nie im Repo. Heartbeat-Intervall im Monitor: 20 Minuten
  (Timer alle 15 Minuten plus Laufzeit), Retries 1, damit ein einzelner Aussetzer nicht alarmiert.
- **Uptime Kuma, HTTP-Monitor für die Webseite** (Gruppe Dienste): `http://debian-inventar.lan:8080/api/summary`.
- **Glance**: Eintrag unter Monitoring (glance-Repo).
- **Pi-holes synchron**: Mit `PIHOLE2_URL`/`PIHOLE2_PASSWORD` in `secrets.env` vergleicht jeder
  Lauf den zweiten Pi-hole (.59) mit dem ersten (.99). Unterschiede stehen als Warnung im Inventar;
  dauern sie länger als eine Stunde, meldet der Push-Monitor „Inventar Sammler“ „down“.
- **Uptime Kuma, Monitore für die Hosts selbst**: Ping für jeden statischen oder reservierten
  Host mit DNS-Namen und HTTPS für jede aktive NPM-Domain, in der Gruppe „Automatisch (Inventar)“.
  Angelegt werden sie vom Skript `uptimekuma-sync.py` im shell-Repo (Doku `uptimekuma-sync.md`).
  Das Skript läuft nicht automatisch: nach einem neuen Host oder einer neuen NPM-Domain auf dem Mac
  von Hand starten, erst ohne, dann mit `--apply`.
- **NPM**: `inventar.mythenstrasse56.net` mit Access-Liste.
