# ntfy (Push-Benachrichtigungen)

Selbst gehosteter Ersatz für Pushover. Container `debian-ntfy.lan`,
192.168.1.68, von unterwegs über den Cloudflare Tunnel als
`https://ntfy.mythenstrasse56.net`. Pushover bleibt vorerst als zweiter Kanal
für die wichtigsten Uptime-Kuma-Monitore.

Themen (Topics):

| Thema | Wer schreibt | Priorität |
| --- | --- | --- |
| `homelab` | Uptime Kuma | hoch bei DOWN |
| `flickr` | Flickr-Uploader, Flickr-Commenter | niedrig (leise) |

Jeder Absender hat einen eigenen Benutzer mit eigenem Token, der nur in sein
Thema schreiben darf. Ohne Anmeldung geht nichts (`deny-all`). Tokens und
Passwörter gehören nach Vaultwarden, nie ins Repo.

## 1. Container anlegen (auf proxmox-n01 oder proxmox-n02 als root)

```
var_os='debian' bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/ntfy.sh)"
```

Im Menü **Advanced** wählen und setzen:
- Hostname `debian-ntfy`
- IPv4 statisch `192.168.1.68/24`, Gateway `192.168.1.1`
- DNS `192.168.1.99` (Pi-hole), Domain `lan`
- Rest Standard (Debian 13, unprivileged, 1 CPU, 512 MB, 2 GB)

CTID notieren. Vorher prüfen, dass die IP frei ist: `ping -c 2 192.168.1.68`
muss ins Leere gehen.

Im Pi-hole unter **Local DNS > DNS Records** `debian-ntfy.lan` auf
`192.168.1.68` eintragen.

## 2. In Ansible aufnehmen (auf debian-ansible als transport)

Der Eintrag `ntfy` steht schon in `inventory.yaml`. Ablauf wie in
`neue-maschine.md`, CTID und Node anpassen:

```
/home/transport/clone.sh
/home/transport/ansible/run.sh bootstrap --limit proxmox-n01 -e ctid=<CTID>
ssh -4 transport@debian-ntfy.lan exit
ansible ntfy -i /home/transport/ansible/inventory.yaml -m ping
/home/transport/ansible/run.sh newserver --limit ntfy
```

Danach auf dem Node als root: `pct exec <CTID> -- passwd gato`.

## 3. ntfy einstellen (in debian-ntfy als root)

Vom Node aus: `pct exec <CTID> -- bash`, oder per SSH als gato und `sudo -i`.

```
install -d -o ntfy -g ntfy /var/cache/ntfy /var/lib/ntfy
cp /etc/ntfy/server.yml /etc/ntfy/server.yml.orig
cat > /etc/ntfy/server.yml <<'YML'
base-url: "https://ntfy.mythenstrasse56.net"
listen-http: ":80"
# Hinter NPM bzw. cloudflared: echte Client-IP aus X-Forwarded-For
behind-proxy: true
cache-file: "/var/cache/ntfy/cache.db"
cache-duration: "24h"
auth-file: "/var/lib/ntfy/user.db"
auth-default-access: "deny-all"
enable-signup: false
enable-login: true
# iPhone: Apple-Push nur über ntfy.sh. Dorthin geht nur ein "bitte abholen",
# der Inhalt bleibt hier.
upstream-base-url: "https://ntfy.sh"
# Keine Web-Oberfläche: die iPhone-App und die Absender brauchen nur die API
web-root: "disable"
YML
systemctl restart ntfy
systemctl status ntfy --no-pager
curl -s http://localhost/v1/health
```

Erwartet: `{"healthy":true}`.

Benutzer und Rechte anlegen (die Passwort-Abfrage kommt jeweils interaktiv):

```
ntfy user add --role=admin gato
ntfy user add kuma
ntfy access kuma homelab write-only
ntfy token add kuma
ntfy user add flickr
ntfy access flickr flickr write-only
ntfy token add flickr
```

Die beiden Tokens (`tk_...`) und das Passwort von gato in Vaultwarden
ablegen. `ntfy user list` und `ntfy token list` zeigen den Stand.

## 4. Erreichbarkeit

Von unterwegs über den Cloudflare Tunnel, zuhause über NPM, wie die anderen
Dienste: Im Pi-hole zeigen alle `*.mythenstrasse56.net` auf NPM (.78), ohne
NPM-Eintrag landet man im LAN also im Leeren.

Im Cloudflare-Dashboard beim Tunnel einen Public Hostname
`ntfy.mythenstrasse56.net` → `HTTP` `192.168.1.68:80`. **Kein** Cloudflare
Access davor, sonst kommt die App nicht durch; die Anmeldung macht ntfy
selbst. Die Länder-Regel (CH, DE, IT, NL) gilt auch hier.

Im NPM einen Proxy Host `ntfy.mythenstrasse56.net` → `http` `192.168.1.68`
Port `80`, **Websockets Support** an, SSL mit dem Wildcard-Zertifikat.

Absender im LAN (Kuma, Skripte) nehmen direkt `http://debian-ntfy.lan`, damit
Meldungen auch ohne Internet bei ntfy ankommen.

`uptimekuma-sync.py` legt für `ntfy.mythenstrasse56.net` keinen Monitor an
(Ausschlussliste im shell-Repo), weil die Startseite absichtlich `404`
liefert. Geprüft wird `/v1/health`, siehe Abschnitt 7.

## 5. Testen (auf debian-ansible oder dem Mac)

Geht nur an ntfy, nirgends sonst hin:

```
curl -H "Authorization: Bearer <kuma-Token>" -d "Test aus dem LAN" http://debian-ntfy.lan/homelab
curl -H "Authorization: Bearer <kuma-Token>" -d "Test über Tunnel" https://ntfy.mythenstrasse56.net/homelab
```

Ohne Token muss `403` kommen:

```
curl -s -o /dev/null -w '%{http_code}\n' -d "x" http://debian-ntfy.lan/homelab
```

## 6. iPhone

ntfy-App aus dem App Store, beim ersten Start Mitteilungen **erlauben**. In
den Einstellungen `https://ntfy.mythenstrasse56.net` als **Default Server**
setzen (ohne `/` am Ende) und bei **Users** `gato` für diesen Server anlegen.
Dann die Themen `homelab` und `flickr` abonnieren.

Kommen Meldungen nur beim Öffnen der App, aber nicht als Push:
- Einstellungen > Mitteilungen > ntfy: erlaubt, mit Sperrbildschirm,
  Mitteilungszentrale und Banner.
- Gegentest ohne eigenen Server: Abo auf `https://ntfy.sh` mit zufälligem
  Thema, dann `curl -d test https://ntfy.sh/<thema>`. Kommt auch das nicht,
  liegt es am iPhone.
- Hilft nichts: App löschen und neu installieren (meldet sich neu bei Apple
  an). So am 2026-10-09 gelöst.

## 7. Uptime Kuma

**Settings > Notifications > Setup Notification**:
- Typ **ntfy**, Server URL `http://debian-ntfy.lan` (klappt der Test nicht,
  `http://192.168.1.68`), Topic `homelab`, Priority `5`
- Authentication **Access Token**, Token von kuma
- Vorerst **nicht** als Standard markieren, Pushover bleibt. Erst ein paar
  Wochen parallel laufen lassen.

Zusätzlich einen HTTP-Monitor auf `http://debian-ntfy.lan/v1/health` mit
Benachrichtigung **nur** über **Pushover**, damit ein Ausfall von ntfy selbst
auffällt. Nie auf die Startseite `/` prüfen, die liefert `404`.

## Neuen Absender anlegen (in debian-ntfy als root)

Für jede neue App oder jedes Skript ein eigener Benutzer mit eigenem Token, der
nur in sein Thema schreiben darf. Beispiel: Benutzer `backup`, Thema `backup`.

```
ntfy user add backup
ntfy access backup backup write-only
ntfy token add --label="TrueNAS Backup-Skript" backup
```

- Das Passwort aus `user add` braucht niemand, nur den Token. Trotzdem ein
  langes zufälliges nehmen.
- `token add` zeigt den Token (`tk_...`) einmal an. Sofort in Vaultwarden
  ablegen, mit Benutzer und Thema.
- Soll der Absender in ein bestehendes Thema schreiben, z. B. `homelab`, bei
  `access` einfach dieses Thema angeben.
- gato ist Admin und darf alle Themen lesen. Neues Thema in der iPhone-App
  abonnieren: **+**, **Use another server**, Thema eintragen.

Testen (geht nur an ntfy):

```
curl -H "Authorization: Bearer tk_..." -d "Test" http://debian-ntfy.lan/backup
```

Nachschauen und aufräumen:

```
ntfy user list
ntfy token list backup
ntfy token remove backup tk_...
ntfy user del backup
```

## Sicherheit

Der Server ist über den Tunnel aus dem Internet erreichbar (nur aus CH, DE, IT,
NL). Deshalb:
- `deny-all`: ohne Token oder Anmeldung lässt sich nichts lesen oder senden.
- `web-root: "disable"`: keine Web-Oberfläche mit Login-Seite, nur die API.
  Die App und die Absender funktionieren weiter. Wer sie doch braucht, die
  Zeile entfernen und ntfy neu starten.
- Fehlversuche bei der Anmeldung bremst ntfy pro IP selbst aus. Dafür ist
  `behind-proxy: true` nötig, sonst sähe ntfy nur die IP von cloudflared.
- gato bekommt ein langes zufälliges Passwort aus Vaultwarden.
- Benutzer und Rechte lassen sich nur auf dem Container mit `ntfy user`
  ändern, nie über das Netz.

## Updates

ntfy kommt aus dem apt-Repo `archive.ntfy.sh`. Der Container ist in der
Gruppe `security_daily`: Debian-Sicherheitsupdates und neue ntfy-Versionen
kommen täglich um 06:30 (`run.sh security-updates`, siehe
`sicherheitsupdates.md`), alles andere mit den Sonntags-Updates.
