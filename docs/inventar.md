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
```

## Neue Version ausrollen

Änderungen am Code kommen per Pull Request ins inventar-Repo. Danach auf
debian-ansible:

```
/home/transport/ansible/run.sh inventar-deploy
```

Das holt den neuesten Stand (nur Fast-Forward) und installiert ihn neu in die
venv.

## Noch nicht eingerichtet

Kommt mit den nächsten Schritten des Bauplans: Datenbank, Web-Oberfläche,
systemd-Timer alle 15 Minuten, NPM-Host `inventar.mythenstrasse56.net`,
Glance-Link und Uptime-Kuma-Monitore.
