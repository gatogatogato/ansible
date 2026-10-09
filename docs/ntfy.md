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

Nie auf proxmox-n03.

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

Nur über den Cloudflare Tunnel, kein NPM-Eintrag und kein Pi-hole-Eintrag für
`ntfy.mythenstrasse56.net` nötig: Ohne lokalen Eintrag löst der Name auch
zuhause öffentlich auf und geht über Cloudflare.

Im Cloudflare-Dashboard beim Tunnel einen Public Hostname
`ntfy.mythenstrasse56.net` → `HTTP` `192.168.1.68:80`. **Kein** Cloudflare
Access davor, sonst kommt die App nicht durch; die Anmeldung macht ntfy
selbst. Die Länder-Regel (CH, DE, IT, NL) gilt auch hier.

Absender im LAN (Kuma, Skripte) nehmen direkt `http://debian-ntfy.lan`, damit
Meldungen auch ohne Internet bei ntfy ankommen.

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

ntfy-App aus dem App Store. In den Einstellungen bei **Users** den Server
`https://ntfy.mythenstrasse56.net` mit `gato` hinzufügen, dann **Subscribe**,
**Use another server**, gleiche Adresse, Themen `homelab` und `flickr`.

## 7. Uptime Kuma

**Settings > Notifications > Setup Notification**:
- Typ **ntfy**, Server URL `http://debian-ntfy.lan`, Topic `homelab`, Priority `5`
- Authentication **Access Token**, Token von kuma
- Vorerst **nicht** als Standard markieren, Pushover bleibt. Erst ein paar
  Wochen parallel laufen lassen.

Zusätzlich einen HTTP-Monitor auf `http://debian-ntfy.lan/v1/health` mit
Benachrichtigung über **Pushover**, damit ein Ausfall von ntfy selbst auffällt.

## Updates

ntfy kommt aus dem apt-Repo `archive.ntfy.sh` und wird mit den normalen
Sonntags-Updates mitaktualisiert.
