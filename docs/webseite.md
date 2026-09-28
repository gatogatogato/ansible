# Webseite gatogatogato.ch einrichten

Einmalige Einrichtung, damit websrv die Hugo-Quelle aus dem privaten Repo
`gatogatogato/gatogatogato.ch-hugo` auschecken, bauen und veröffentlichen kann.
Wie man danach eine Änderung veröffentlicht, steht in `DEPLOY.md` im
Webseiten-Repo.

Repo und Ordner stehen in `inventory.yaml` beim Host `websrv`
(`website_repo`, `website_dir`).

## 1. Privates Repo anlegen (GitHub)

Auf github.com/new: Name `gatogatogato.ch-hugo`, **Private**, ohne README,
.gitignore oder Lizenz (sonst gibt es beim ersten Push einen Konflikt).

## 2. Quelle ins Repo bringen (auf dem Mac)

Die aktuelle Quelle vom websrv holen, ohne die gebaute Seite:

```
cd ~/Documents/Code
rsync -a --exclude public --exclude resources gato@debian-websrv.lan:gatogatogato.ch-hugo/ gatogatogato.ch-hugo/
cd gatogatogato.ch-hugo
```

Die vorbereiteten Dateien `README.md`, `DEPLOY.md` und `.gitignore` in diesen
Ordner kopieren, dazu das Deploy-Skript als `deploy.sh` (ausführbar,
`chmod +x deploy.sh`).

Vor dem ersten Commit prüfen, dass in der YAML-Datei keine Tokens oder
Passwörter stehen (z. B. API-Keys für Analytics oder Kontaktformulare).

```
git init -b main
git add .
git status          # nur Quelle, kein public/
git commit -m "Hugo-Quelle von gatogatogato.ch"
git remote add origin git@github.com:gatogatogato/gatogatogato.ch-hugo.git
git push -u origin main
```

## 3. websrv vorbereiten (auf debian-ansible, als transport)

```
/home/transport/clone.sh
/home/transport/ansible/run.sh website-setup
```

Der erste Lauf installiert git und acl, legt auf websrv den Deploy-Key
`/home/gato/.ssh/website_deploy_key` an und bricht dann mit dem öffentlichen
Schlüssel ab. Diesen in GitHub eintragen: Repo **Settings > Deploy keys >
Add deploy key**, Titel `websrv`, **Allow write access nicht anhaken**.

Danach nochmals:

```
/home/transport/ansible/run.sh website-setup
```

Bricht er ab, weil `/home/gato/gatogatogato.ch-hugo` schon existiert (die alte
Kopie), den Ordner als gato zur Seite schieben und `website-setup` nochmals
starten:

```
ssh gato@debian-websrv.lan mv /home/gato/gatogatogato.ch-hugo /home/gato/gatogatogato.ch-hugo.alt
```

Liefert Apache die Seite direkt aus diesem Ordner aus (DocumentRoot prüfen mit
`grep -ri DocumentRoot /etc/apache2/sites-enabled`), ist die Seite zwischen
`mv` und dem ersten Deploy kurz weg. Dann Schritt 4 direkt anschliessen.

## 4. Erster Deploy

```
/home/transport/ansible/run.sh website-deploy
```

Seite im Browser prüfen. Wenn alles passt, die alte Kopie löschen:

```
ssh gato@debian-websrv.lan rm -rf /home/gato/gatogatogato.ch-hugo.alt
```

## Hinweise

- Der Deploy-Key kann nur lesen und nur dieses eine Repo. Er liegt nur auf
  websrv. Neuer Key: Datei löschen, `website-setup` laufen lassen, alten Key in
  GitHub entfernen.
- Der tägliche Backup-Cron (`cronjobs_webservers.yaml`) sichert den Ordner
  weiterhin; die Quelle liegt jetzt zusätzlich in GitHub.
- Hugo-Version: websrv nutzt Hugo aus Debian (`hugo version`), der Mac meist eine
  neuere aus Homebrew. Baut die Seite nur lokal, liegt es oft daran.
