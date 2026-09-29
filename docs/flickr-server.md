# flickr-Server (debian-flickr) neu aufbauen

Was auf debian-flickr läuft, woher jedes Teil kommt, und wie ein neuer Server
entsteht, wenn der alte komplett weg ist. Ein Lauf von `run.sh flickr-server`
richtet alles ein; die Secrets kommen aus der Sicherung auf debian-ansible.

## Was auf dem Server läuft

| Teil | Woher | Wo auf dem Server |
|---|---|---|
| Uploader, Thumbnail-Skript | Repo `gatogatogato/flickr-uploader` | `/home/gato/Apps/flickr-uploader`, Befehl `uploader` |
| Commenter (Cronjob) | Repo `gatogatogato/flickr-scripts` | `/home/gato/Apps/flickr-scripts/flickr-commenter-v9.2.rb`, Logs in `/home/gato/Apps/flickr-commenter/logs` |
| Fotos zum Hochladen | Nextcloud (truenas), alle 5 Minuten per `nextcloudcmd` | `/home/gato/UPLOADS`, hochgeladene in `_Uploaded` |
| Auswahlseite mit Thumbnails | lighttpd, Port 80 | `/var/www/html` (`picker.html`, `small_*.jpg`) |
| Pakete und Ruby-Gems | `install_flickrservers_packages.yaml` | |
| Cronjobs | `cronjobs_flickrservers.yaml` | Crontab von gato |
| Keys und Tokens | nicht in Git, siehe unten | `~/.config/flickr-uploader/`, `~/.config/flickr-scripts/`, `~/.netrc` |

Nichts davon muss vom alten Server gerettet werden, solange die Secrets
gesichert sind (siehe Vorsorge). Die Fotos liegen in Nextcloud, die Logs des
Commenters sind nach 7 Tagen ohnehin weg.

Außerhalb von debian-flickr: https://picker.mythenstrasse56.net zeigt auf
diesen Server (Proxy bzw. Tunnel). Bekommt der neue Server eine andere IP,
dort das Ziel anpassen.

## Keys und Tokens

Drei Dateien, jede nur für gato lesbar (0600):

| Datei auf dem Server | Inhalt | Name in der Sicherung |
|---|---|---|
| `/home/gato/.config/flickr-uploader/credentials.yml` | flickr-App des Uploaders (Key, Secret, Access-Token), Mastodon-Token, Pushover | `uploader-credentials.yml` |
| `/home/gato/.config/flickr-scripts/flickr-credentials.yml` | flickr-App des Commenters (eigene App, eigene Tokens), Pushover | `flickr-credentials.yml` |
| `/home/gato/.netrc` | Nextcloud-Login für den UPLOADS-Sync | `netrc` |

Vorlagen: `credentials.example.yml` im flickr-uploader-Repo,
`flickr-credentials.example.yml` in flickr-scripts. Die Liste steht auch in
`inventory.yaml` (`flickr_secrets`).

### Vorsorge (jetzt, und nach jeder Token-Änderung)

Auf debian-ansible als transport:

```
/home/transport/ansible/run.sh flickr-secrets-backup
```

Kopiert die drei Dateien nach `/home/transport/.config/flickr-secrets/`
(nur für transport lesbar, nie in Git). Zusätzlich den Inhalt der drei Dateien
in Vaultwarden ablegen, für den Fall, dass auch debian-ansible weg ist.

### Wenn keine Sicherung mehr da ist

- **Uploader, flickr Access-Token:** leer lassen, `uploader` zeigt beim Start
  eine URL zum Autorisieren und speichert die Tokens selbst.
- **Commenter, flickr Access-Token:** mit demselben Trick über den Uploader:
  eine temporäre Kopie von `credentials.yml` mit Key und Secret der
  Commenter-App und leeren Access-Tokens anlegen, dann
  `FLICKR_UPLOADER_CREDENTIALS=/tmp/commenter.yml uploader --dry-run`,
  autorisieren, `X`. Die Tokens aus `/tmp/commenter.yml` in
  `flickr-credentials.yml` übernehmen, Kopie löschen.
- **flickr Key und Secret:** https://www.flickr.com/services/apps/ (beide Apps).
- **Mastodon:** ohai.social, Einstellungen > Entwicklung, App des Uploaders.
- **Pushover:** pushover.net, User-Key und App-Token.
- **Nextcloud:** `.netrc` mit `machine truenas.lan login gato password …`
  (ein App-Passwort aus Nextcloud nehmen).

## Neuaufbau Schritt für Schritt

### 1. Container anlegen

Wie in `docs/neue-maschine.md`, Schritt 1: Debian 13, Hostname
`debian-flickr`, 8 GB Disk reichen (belegt sind rund 4 GB). DHCP wie bisher.
CTID und Node notieren.

### 2. Ansible-Zugang und Grundsetup (auf debian-ansible, als transport)

Der Host `flickr` steht schon in `inventory.yaml`. Der alte SSH-Host-Key passt
nicht mehr, deshalb zuerst entfernen:

```
/home/transport/clone.sh
/home/transport/ansible/run.sh bootstrap --limit proxmox-n0X -e ctid=NNN
ssh-keygen -R debian-flickr.lan
ssh -4 transport@debian-flickr.lan exit
/home/transport/ansible/run.sh newserver --limit flickr
```

Danach auf dem Proxmox-Node ein Passwort für gato setzen
(`pct exec NNN -- passwd gato`), siehe `docs/neue-maschine.md`.

### 3. flickr-Teil einrichten

```
/home/transport/ansible/run.sh flickr-server
```

Das macht der Reihe nach:

1. Pakete und Gems (`install_flickrservers_packages`)
2. Ordner, Web-Root für gato, lighttpd (`flickr_server_setup`)
3. Secrets aus der Sicherung, nur fehlende Dateien (`flickr_secrets_restore`)
4. Uploader-Repo, `flickr-uploader-deploy`, `uploader` (`flickr_uploader_setup`)
5. flickr-scripts-Repo für den Commenter (`flickr_commenter_setup`)
6. Cronjobs (`cronjobs_flickrservers`)

Ein neuer Server hat neue Deploy-Keys, deshalb bricht der erste Lauf bei
Schritt 4 und 5 ab und zeigt je einen öffentlichen Schlüssel. Beide in GitHub
eintragen (Repo **Settings > Deploy keys > Add deploy key**, Titel
`debian-flickr.lan`, **Allow write access nicht anhaken**), den alten Key des
toten Servers dort löschen. Dann `run.sh flickr-server` nochmals.

Fehlen Secrets auch in der Sicherung, bricht Schritt 3 mit der Liste ab; die
Dateien wie oben beschrieben von Hand anlegen und nochmals laufen lassen.

### 4. Prüfen

- `ssh gato@debian-flickr.lan`, dann `uploader --dry-run`: Login bei flickr
  klappt, Fotos werden gelistet, nichts wird hochgeladen.
- Nach 5 Minuten: `ls ~/UPLOADS` zeigt die Fotos aus Nextcloud.
- Nach 10 Minuten (zwischen 6 und 22 Uhr): https://picker.mythenstrasse56.net/picker.html
  zeigt nach dem ersten `uploader`-Lauf die Thumbnails.
- Nach dem nächsten Commenter-Lauf (8, 12, 13, 15, 17, 19, 20 Uhr):
  `~/commenter-logfile.txt` bzw. `~/Apps/flickr-commenter/logs/`.
- `run.sh flickr-secrets-backup`, damit die Sicherung zum neuen Server passt.

## Änderungen im Alltag

- **Uploader:** `docs/flickr-uploader.md` (push reicht, Cronjob holt es).
- **Commenter:** in flickr-scripts committen und pushen, dann
  `run.sh commenter-setup` (holt den neuesten Stand, nur fast-forward).
- **Pakete, Ordner, lighttpd:** `run.sh flickr-server` darf jederzeit wieder
  laufen, es überschreibt keine Secrets und keine Fotos.

## Hinweise

- Dropbox ist abgelöst; `cronjobs_flickrservers` entfernt den alten
  Neustart-Cronjob für `dropbox.service`. Der Dienst selbst liegt noch auf dem
  alten Server, auf einem neuen gibt es ihn nicht mehr.
- Die Setup-Playbooks verschieben alte Kopien mit Keys im Code
  (`uploader-headless.rb`, `uploader-config.yml`, `flickr-commenter.rb`) nach
  `/home/gato/Apps/alt`, statt sie zu löschen. Läuft alles, den Ordner löschen.
