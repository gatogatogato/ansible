# Kamera-Galerie (debian-camsnaps)

debian-camsnaps (192.168.1.67, CT 116) zeigt die Schnappschüsse, die Home
Assistant bei Ereignissen macht (Klingel, Person am Eingang, Terrasse), als
Galerie: http://debian-camsnaps.lan/snapshots/, intern über NPM als
https://camsnaps.mythenstrasse56.net/snapshots/. Nur intern erreichbar.

Home Assistant löscht die Bilder in `/config/www` nach 6 Tagen
(Automation „Time based - delete old camera snapshots“). camsnaps behält alle.

Das Skript liegt im privaten Repo `gatogatogato/camsnaps` (README dort).
Repo und Pfade stehen in `inventory.yaml` beim Host `camsnaps`.

## Wie es läuft

| Was | Wo |
|---|---|
| Checkout | `/opt/camsnaps` (gehört gato), Befehl `camsnaps` |
| Bilder holen und Seite bauen | Benutzer `camsnaps`, Cronjob alle 10 Min.: `camsnaps run` |
| Log | `/var/log/camsnaps.log`, nur Einträge bei neuen Bildern oder Fehlern |
| Bilder, Vorschaubilder, Seite | `/var/www/html/snapshots` (`thumbs/`, `index.html`) |
| Schlüssel für Home Assistant | `/var/lib/camsnaps/.ssh/ha_ed25519`, eingetragen im HA-Add-on „Advanced SSH & Web Terminal“ |
| Neue Version aus GitHub | gato, Cronjob alle 15 Min.: `camsnaps-deploy --if-changed`, Log `/home/gato/camsnaps-deploy.log` |

camsnaps meldet sich bei Home Assistant als root an (das SSH-Add-on kennt nur
diesen Benutzer), liest aber nur: `ls` und `tar` in `/root/config/www`. Kopiert
werden nur Bilder, die zu einer Kamera in `config.toml` passen und noch fehlen.
Gelöscht wird nie etwas.

## Einmalige Einrichtung (auf debian-ansible, als transport)

```
clone.sh
run.sh camsnaps-setup
```

Der erste Lauf legt den Deploy-Key `/home/gato/.ssh/camsnaps_deploy_key` an und
bricht mit dem öffentlichen Schlüssel ab. Diesen in GitHub eintragen: Repo
`gatogatogato/camsnaps`, **Settings > Deploy keys > Add deploy key**, Titel
`debian-camsnaps.lan`, **Allow write access nicht anhaken**.

Der zweite Lauf legt den Schlüssel für Home Assistant an und bricht wieder ab.
In Home Assistant: **Einstellungen > Add-ons > Advanced SSH & Web Terminal >
Konfiguration**, die angezeigte Zeile unter `authorized_keys` ergänzen,
speichern, Add-on neu starten.

Der dritte Lauf:

1. installiert die Pakete, schaltet die unbenutzten Apache-Module ssl und
   rewrite ab (Port 443 ist danach zu),
2. übergibt `/var/www/html/snapshots` dem Benutzer camsnaps,
3. holt neue Bilder und baut die Seite einmal (bricht hier ab, wenn das nicht
   geht, dann bleibt das Alte unverändert),
4. richtet die Cronjobs ein, entfernt die alten von transport (scp und
   `gallery.sh`), verschiebt `gallery.sh` nach `/var/lib/camsnaps/alt/`,
5. nimmt transport aus der Gruppe root.

Danach den privaten transport-Key auf camsnaps löschen, den braucht dort nichts
mehr:

```
run.sh remove-key --limit camsnaps
```

Wenn alles läuft, kann `/var/lib/camsnaps/alt/` weg.

## Änderung veröffentlichen

Auf dem Mac im Repo `~/Documents/Code/camsnaps` ändern und pushen. Der Server
holt es innert 15 Minuten, sofort mit:

```
run.sh camsnaps-deploy
```

`camsnaps-deploy` prüft vorher, dass `camsnaps.py` und `config.toml` gültig
sind, sonst bleibt die laufende Version.

## Von Hand

Auf debian-camsnaps als gato:

```
sudo -u camsnaps camsnaps run      # jetzt holen und bauen
sudo -u camsnaps camsnaps build    # nur Seite neu bauen
tail /var/log/camsnaps.log
```

## Neu aufbauen

Neuen Container nach `docs/neue-maschine.md` (IP 192.168.1.67, Name
debian-camsnaps.lan), dann `run.sh camsnaps-setup` wie oben. Der neue
Schlüssel für Home Assistant muss dort eingetragen werden. Die alten Bilder
gibt es nur auf dem alten Container und im Proxmox-Backup (Home Assistant hat
nur die letzten 6 Tage), also vorher `/var/www/html/snapshots/*.jpg`
umkopieren.
