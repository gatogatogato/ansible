# Glance-Config über Ansible ausrollen

Die Konfiguration des Glance-Dashboards (https://glance.mythenstrasse56.net/)
liegt im privaten Repo `gatogatogato/glance`. debian-glance holt sie per
Deploy-Key von GitHub und rollt sie mit `/usr/local/sbin/glance-deploy` aus,
entweder automatisch per Cronjob oder auf Knopfdruck. Aufgebaut wie die
Webseite (`docs/webseite.md`).

Repo und Pfade stehen in `inventory.yaml` beim Host `glance`
(`glance_repo`, `glance_dir`, `glance_data`).

## Einmalige Einrichtung (auf debian-ansible, als transport)

```
/home/transport/clone.sh
/home/transport/ansible/run.sh glance-setup
```

Der erste Lauf installiert git, legt auf debian-glance den Deploy-Key
`/home/gato/.ssh/glance_deploy_key` an und bricht dann mit dem öffentlichen
Schlüssel ab. Diesen in GitHub eintragen: Repo `gatogatogato/glance`,
**Settings > Deploy keys > Add deploy key**, Titel `debian-glance`,
**Allow write access nicht anhaken**.

Danach nochmals:

```
/home/transport/ansible/run.sh glance-setup
/home/transport/ansible/run.sh cronjobs --limit glance
/home/transport/ansible/run.sh glance-deploy
```

`glance-setup` klont das Repo nach `/home/gato/glance` und installiert
`glance-deploy`. `cronjobs --limit glance` richtet den Cronjob ein. Der erste
`glance-deploy` sollte „Server already up to date“ melden, weil auf dem Server
schon der Stand aus dem Repo läuft.

## Was glance-deploy macht

Läuft als root (schreibt `/opt/glance_data`, startet Glance neu):

1. Holt den neuesten Stand aus GitHub in `/home/gato/glance` (git läuft als gato).
2. Prüft, dass `/opt/glance_data/glance.yml` einem Stand aus dem Repo
   entspricht. Wurde auf dem Server mit `~/edit.sh` geändert und die Änderung
   noch nicht ins Repo geholt, bricht es ab und überschreibt nichts.
3. Ist `glance.yml` anders: Backup `glance.yml.<Datum_Zeit>`, dann ersetzen.
   Bilder aus `assets/` nach `/opt/glance_data/assets/`.
4. Hat sich etwas geändert: `systemctl restart glance`. Startet Glance nicht,
   spielt es das Backup zurück, startet wieder und meldet den Fehler.

Mit `--if-changed` (Cronjob) tut es nichts und schreibt nichts, solange auf
GitHub kein neuer Commit liegt. Ein Commit, der einmal fehlgeschlagen ist, wird
nur einmal gemeldet und erst mit dem nächsten Push wieder versucht.

## Änderung veröffentlichen

Auf dem Mac im Repo `~/Documents/Code/glance`:

```
git add -A
git commit -m "Kurz beschreiben, was sich ändert"
git push
```

| Weg | Wo | Wann online |
|---|---|---|
| 1. Automatisch | nichts tun | nach max. 5 Minuten |
| 2. Ansible | debian-ansible: `/home/transport/ansible/run.sh glance-deploy` | sofort |
| 3. Direkt | debian-glance: `sudo glance-deploy` | sofort |

Log des Cronjobs auf debian-glance (wird monatlich rotiert, 3 Monate behalten):

```
ssh gato@debian-glance.lan sudo tail -20 /var/log/glance-deploy.log
```

## Änderungen mit edit.sh auf dem Server

Geht weiterhin. Danach auf dem Mac im Repo `./pull.sh` ausführen, committen
und pushen (die Login-Meldung auf debian-glance erinnert daran). Vergessen ist
nicht schlimm: Der nächste Deploy bricht ab, statt die Änderung zu
überschreiben, und schreibt das ins Log. Nach `pull.sh` und Push läuft er
wieder.

## Wenn der Deploy abbricht

- **`changed on the server (edit.sh?)`:** siehe oben, `./pull.sh` auf dem Mac,
  committen, pushen.
- **`Glance did not start`:** die neue `glance.yml` ist fehlerhaft. Glance läuft
  mit dem Backup weiter. Im Log stehen die Meldungen von Glance. Im Repo
  korrigieren oder `git revert HEAD`, pushen.
- **`local changes in /home/gato/glance`:** jemand hat im Checkout auf dem
  Server geändert. Dort als gato `git -C ~/glance checkout -- .`
- **Permission denied (publickey):** der Deploy-Key fehlt in GitHub, siehe
  Einrichtung.

## Hinweise

- Der Deploy-Key kann nur lesen und nur dieses eine Repo. Neuer Key: Datei
  löschen, `glance-setup` laufen lassen, alten Key in GitHub entfernen.
- `glance-deploy` kommt aus `templates/glance-deploy.sh.j2`; Änderungen dort
  machen. `run.sh glance-deploy` installiert es jedes Mal neu.
- Secrets gibt es in der Glance-Config derzeit keine. Später: `.env` aus Ansible
  Vault nach `/opt/glance_data/.env` und ein systemd-Drop-in mit
  `EnvironmentFile=` (siehe README im glance-Repo).
