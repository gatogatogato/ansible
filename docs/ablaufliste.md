# Ablaufliste: was still abläuft

Alles im Homelab, das irgendwann abläuft oder bezahlt werden muss, mit Ort zum Nachsehen und
Erneuern. Ziel: kein „plötzlich geht nichts mehr“. Die Werte selbst (Tokens, Passwörter)
stehen nie hier, sondern in Vaultwarden und in den Secret-Dateien auf den Servern.

Die Spalte **Ablauf** einmal ausfüllen (oder „nie“), für jedes Datum einen Termin in die
Erinnerungen-App (Liste „Wiederholend“), zwei Wochen vorher. Nach jedem Erneuern das neue
Datum hier eintragen.

## Muss erneuert oder bezahlt werden

| Was | Wofür | Ablauf | Nachsehen und erneuern |
| --- | --- | --- | --- |
| Domain gatogatogato.ch | Webseite | ? | Beim Registrar: Auto-Renew an, hinterlegte Karte gültig |
| Domain mythenstrasse56.net | Tunnel, NPM-Zertifikat, alle Dienste | ? | Beim Registrar: Auto-Renew an, hinterlegte Karte gültig |
| Kreditkarte für Domains und Storj | Zahlungen oben und unten | ? | Kartenablauf; beim Kartenwechsel überall neu hinterlegen |
| Storj (Konto, Zahlung) | Backups ausser Haus (TrueCloud) | ? | Storj-Konsole → Billing |
| GitHub-Token (fine-grained) für den Git-Mirror | `git-mirror.sh`, `~/.config/git-mirror.env` auf debian-ansible | ? | github.com → Settings → Developer settings → Fine-grained tokens. GitHub mailt eine Woche vorher. Neues Token mit denselben Rechten (alle Repos, Contents + Metadata lesen), in die env-Datei und Vaultwarden |
| Let's-Encrypt-Wildcard auf NPM | alle `*.mythenstrasse56.net` im LAN | alle 90 Tage, erneuert sich selbst | NPM → SSL Certificates. Nur prüfen, dass die Erneuerung klappt (siehe Kuma unten) |
| Cloudflare-API-Token für die DNS-Challenge von NPM (falls genutzt) | Erneuerung des Wildcard-Zertifikats | ? | dash.cloudflare.com → My Profile → API Tokens, Spalte „TTL“ |

## Läuft nur ab, wenn man es so eingestellt hat

Einmal nachsehen; steht dort ein Datum, oben in die Tabelle verschieben.

| Was | Wofür | Nachsehen |
| --- | --- | --- |
| UniFi-API-Key (Integration-API) | inventar (`UNIFI_API_KEY`) | UniFi lokal (https://192.168.1.1) → Integrationen, Ablaufdatum des Keys |
| Proxmox-Token `inventar@pve!sammler` | inventar | als root auf proxmox-n01: `pveum user token list inventar@pve` (Spalte expire, 0 = nie) |
| ntfy-Tokens (kuma, flickr, backup) | Benachrichtigungen | als root auf debian-ntfy: `ntfy token list` |
| Storj Access Grant / API-Key | TrueCloud-Tasks | Storj-Konsole → Access Keys; TrueNAS → Credentials → Backup Credentials |
| Home-Assistant-Token (long-lived) | Skripte, falls genutzt | HA → Profil → Sicherheit, gilt 10 Jahre |

## Läuft nicht ab (nur bei Wechsel oder Verlust erneuern)

Cloudflare-Tunnel-Token (`docs/cloudflared.md`), Deploy-Keys der privaten Repos, flickr- und
Mastodon-Tokens (`docs/flickr-server.md`), Pushover, Pi-hole-App-Passwörter (Achtung: ein neues
ersetzt das alte, siehe `zugaenge.md` im inventar-Repo), NPM-User inventar, Nextcloud-App-Passwörter,
Kuma-Push-URLs, Vaultwarden-Admin-Token, Recovery-Codes und YubiKeys (Notfallblatt).

## Warnung in Uptime Kuma

Bei jedem HTTPS-Monitor unter *Bearbeiten → Erweitert* **Certificate Expiry Notification**
einschalten (Settings → Notifications: Tage 21, 14, 7). Dann meldet Kuma ein Zertifikat,
das sich nicht erneuert hat, bevor es abläuft. Das gilt auch für die schon angelegten
Monitore der Gruppe „Automatisch (Inventar)“. Neue Monitore aus `uptimekuma-sync.py`
(shell-Repo) übernehmen die Einstellung vom ersten HTTP-Monitor ohne Tag `inventar` als Vorlage.

Domains und Kartenablauf sieht Kuma nicht; dafür sind die Termine in der Erinnerungen-App.
