# flickr-Uploader über Ansible ausrollen

Der Uploader (`uploader-headless.rb`) und das Thumbnail-Skript
(`uploader-scale-images.sh`) liegen im privaten Repo
`gatogatogato/flickr-uploader`. debian-flickr holt es per Deploy-Key von
GitHub nach `/home/gato/Apps/flickr-uploader`, mit
`/usr/local/bin/flickr-uploader-deploy`, entweder automatisch per Cronjob oder
auf Knopfdruck. Aufgebaut wie Glance (`docs/glance.md`).

Repo und Pfade stehen in `inventory.yaml` beim Host `flickr`
(`uploader_repo`, `uploader_dir`, `flickr_old_dir`). Wie man den Uploader
benutzt, steht im README des Repos. Den ganzen Server neu aufbauen:
`docs/flickr-server.md`.

debian-flickr ist oft ausgeschaltet (`run.sh shutdown`). Alles hier braucht den
Server eingeschaltet; was während er aus war gepusht wurde, holt der Cronjob
nach dem Einschalten innert 15 Minuten.

## Keys und Tokens

Nicht im Repo, nur auf dem Server in
`/home/gato/.config/flickr-uploader/credentials.yml` (chmod 600, gehört gato):
flickr API-Key und Secret, flickr Access-Token und -Secret, Mastodon-Token,
ntfy-Token (Benutzer flickr), Pushover als Rückfall. Vorlage: `credentials.example.yml` im Repo. Sind die
flickr Access-Tokens leer oder ungültig, zeigt der Uploader beim Start die
Autorisierungs-URL und schreibt die neuen Tokens selbst in die Datei.
Sicherung auf debian-ansible mit `run.sh flickr-secrets-backup`, siehe
`docs/flickr-server.md`.

## Einmalige Einrichtung (auf debian-ansible, als transport)

```
/home/transport/clone.sh
/home/transport/ansible/run.sh uploader-setup
```

`uploader-setup` installiert git und acl, legt (falls noch nicht da) den
Deploy-Key `/home/gato/.ssh/flickr_uploader_deploy_key` an und bricht ab, wenn
GitHub ihn noch nicht kennt, mit dem öffentlichen Schlüssel in der Meldung.
Diesen in GitHub eintragen: Repo `gatogatogato/flickr-uploader`,
**Settings > Deploy keys > Add deploy key**, Titel `debian-flickr`,
**Allow write access nicht anhaken**. Dann `uploader-setup` nochmals.

Danach:

- Repo geklont nach `/home/gato/Apps/flickr-uploader`
- `flickr-uploader-deploy` in `/usr/local/bin`
- `uploader` in `/usr/local/bin` startet den Uploader
- die alten Dateien aus `/home/gato/UPLOADS` (Skripte, `uploader-config.yml`
  mit den Tokens) sind nach `/home/gato/Apps/alt` verschoben,
  damit Nextcloud sie nicht mehr synchronisiert. Läuft alles, den Ordner
  löschen. Alte Versionen in Nextcloud (Papierkorb, Versionen) von Hand leeren.
- die Cronjobs sind neu gesetzt (`uploader-setup` führt
  `cronjobs_flickrservers` gleich mit aus): Thumbnails aus dem Checkout,
  Deploy alle 15 Minuten.

Fehlt `credentials.yml`, meldet `uploader-setup` das; die Datei aus der Vorlage
anlegen, siehe oben.

## Was flickr-uploader-deploy macht

Läuft als gato (als root startet es git als gato):

1. Holt den neuesten Stand von GitHub (`git fetch`).
2. Prüft den neuen Stand, bevor er den laufenden ersetzt: `ruby -c` für den
   Uploader, `bash -n` für das Thumbnail-Skript, YAML-Check für
   `uploader-config.yml`. Schlägt etwas fehl, bleibt der alte Stand.
3. Bricht ab, wenn im Checkout auf dem Server von Hand geändert wurde.
4. `git merge --ff-only` und zeigt alten und neuen Commit.

Mit `--if-changed` (Cronjob) tut es nichts und schreibt nichts, solange auf
GitHub kein neuer Commit liegt. Ein Commit, der die Prüfung nicht besteht, wird
nur einmal gemeldet und erst mit dem nächsten Push wieder versucht.

Ein laufender Uploader (z.B. einer, der auf die Upload-Zeit wartet) arbeitet
mit dem alten Stand weiter; der neue gilt ab dem nächsten Start.

## Änderung veröffentlichen

Auf dem Mac im Repo `~/Documents/Code/flickr-uploader`: committen, dann

| Weg | Wo | Wann auf dem Server |
|---|---|---|
| 1. Automatisch | `git push` | nach max. 15 Minuten |
| 2. Vom Mac | `./deploy.sh` (pusht und ruft `flickr-uploader-deploy` per SSH auf) | sofort |
| 3. Ansible | debian-ansible: `/home/transport/ansible/run.sh uploader-deploy` | sofort |
| 4. Direkt | debian-flickr als gato: `flickr-uploader-deploy` | sofort |

Log des Cronjobs:

```
ssh gato@debian-flickr.lan tail -20 /home/gato/Apps/flickr-uploader-deploy.log
```

## Wenn der Deploy abbricht

- **`syntax error` / `not valid YAML`:** im Repo korrigieren oder
  `git revert HEAD`, pushen.
- **`local changes in /home/gato/Apps/flickr-uploader`:** jemand hat im Checkout
  auf dem Server geändert. Änderung ins Repo übernehmen, dann dort als gato
  `git -C ~/Apps/flickr-uploader checkout -- .`
- **Permission denied (publickey):** der Deploy-Key fehlt in GitHub, siehe
  Einrichtung.

## Hinweise

- Der Deploy-Key kann nur lesen und nur dieses eine Repo. Neuer Key: Datei
  löschen, `uploader-setup` laufen lassen, alten Key in GitHub entfernen.
- `flickr-uploader-deploy` kommt aus `templates/flickr-uploader-deploy.sh.j2`;
  Änderungen dort machen. `run.sh uploader-deploy` installiert es jedes Mal neu.
