# Notfall: was tun, wenn …

Eine Seite für den Ernstfall. Sie sagt, in welcher Reihenfolge man wieder aufbaut, wo
Backups und Zugänge liegen und was bei den häufigsten Ausfällen zu tun ist. Die Details
stehen in den verlinkten Anleitungen.

Ausgedruckt neben das Notfallblatt legen, denn im Ernstfall ist GitHub vielleicht nicht
erreichbar. Nach grösseren Umbauten diese Seite nachführen.

## Welches Szenario?

Von leicht nach schwer. Je weiter unten, desto weiter zurück muss man greifen.

| Szenario | Was fehlt | Woraus zurück |
| --- | --- | --- |
| [DNS](#-nichts-mehr-aufgelöst-wird-dns) | Namensauflösung im Netz | Pi-hole starten, sonst vzdump |
| [Von aussen nichts erreichbar](#-von-aussen-nichts-erreichbar-ist) | Tunnel | zweiter Connector, sonst [cloudflared.md](cloudflared.md) |
| [Ein Container kaputt](#-ein-container-kaputt-ist) | ein Dienst | vzdump auf TrueNAS |
| [Vaultwarden weg](#-vaultwarden-ausfällt) | Passwörter am Server | App-Cache, Backup auf TrueNAS |
| [debian-ansible weg](#-debian-ansible-ausfällt) | Updates, Sicherungen | vzdump |
| [Ein Node weg](#-ein-node-ausfällt) | Gäste dieses Nodes | vzdump auf dem anderen Node, Host-Config |
| [Zwei Nodes weg](#-zwei-nodes-gleichzeitig-weg-sind) | Quorum | `pvecm expected 1` |
| [TrueNAS weg](#-truenas-ausfällt) | alle lokalen Backups, Nextcloud | Storj, LastResort |
| [GitHub weg](#-github-nicht-erreichbar-ist) | Code, Deploys | Git-Mirror, LastResort |
| [Alles weg](#-alles-weg-ist-äusserster-notfall-lastresort) | Homelab und Vaultwarden | **nur LastResort** (und Storj) |

Die USB-Disk **LastResort** ist für den äussersten Notfall: Brand, Diebstahl, Ransomware,
oder wenn auch Vaultwarden nicht mehr geht. Mit ihr allein kommt man wieder an alle
Passwörter, die Storj-Zugänge und den neuesten Stand jedes Gasts. Sie liegt ausser Haus und
wird alle 3 Monate erneuert (`usb-backup.sh`, Anleitung `usb-backup.md` im shell-Repo).

## Zugänge ohne Vaultwarden

| Was | Wo |
| --- | --- |
| Alle Passwörter | Vaultwarden. Die Apps (iPhone, Mac, Browser) haben den Tresor zwischengespeichert und zeigen ihn auch ohne Server an, nur Ändern geht dann nicht. |
| Admin-Token Vaultwarden, Mail-Passwort für Cloudflare Access, Proxmox-Zugang, Recovery-Codes | Notfallblatt (Papier) |
| Ganzer Tresor offline | USB-Disk „LastResort“ (Samsung T7, verschlüsselt): Bitwarden-Export mit eigenem Passwort, siehe `usb-backup.md` im shell-Repo. Disk-Passwort und Export-Passwort stehen auf dem Notfallblatt. |
| Ansible-Zugang | Schlüssel von `transport` nur auf debian-ansible (`~transport/.ssh`). Als `gato` kommt man mit dem eigenen Schlüssel vom Mac auf jeden Debian-Container. |
| Secrets der Server | Kopien auf debian-ansible unter `/home/transport/.config/` (flickr, inventar, cloudflared, Kuma-Push-URLs), zusätzlich in Vaultwarden |

## Wo die Backups liegen

| Was | Lokal | Ausser Haus |
| --- | --- | --- |
| Alle Gäste (vzdump, So 01:00, 4 Stände) | TrueNAS `/mnt/tank01/proxmox-raw-backups/dump` (Proxmox: Storage NAS-SMB) | Storj (TrueCloud So 06:00, 2 Stände), LastResort (neuester je Gast) |
| Proxmox-Nodes (So 05:00, 8 Stände) | debian-ansible `/home/transport/backups/proxmox-hostconfig/`, NAS-SMB `hostconfig/` | Storj (mit dem Dataset oben) |
| Vaultwarden (täglich 00:30) | TrueNAS `/mnt/tank01/vaultwarden-backups/vaultwarden` | Storj (täglich 04:05), LastResort |
| Nextcloud Daten, DB und Config | ZFS-Snapshots auf TrueNAS | Storj (täglich 02:10 und 02:20), LastResort |
| Home Assistant (Mo/Mi/Fr) | TrueNAS-Share ha-backups | Storj (Sa 02:23), LastResort |
| TrueNAS-Config | – | LastResort |
| Code | GitHub, Git-Mirror auf debian-ansible (täglich 02:00) | LastResort |

Zeiten und Stände im Detail: Zeitplan in den Projektnotizen. Wie man ein Backup zurückspielt
und prüft, steht im Restore-Test (jährlich im November).

## Reihenfolge beim Wiederaufbau

Was oben steht, brauchen die unteren. Nie etwas auf proxmox-n03 legen, das ist nur der
Raspberry Pi für das Quorum.

1. **Netz:** UniFi Cloud Gateway (192.168.1.1). DHCP nur für .100 bis .200, alles darunter ist
   im Gerät selbst fest eingestellt.
2. **Proxmox** n01 und n02, dazu n03 für das Quorum. Neuaufbau eines Nodes:
   [proxmox-hostconfig.md](proxmox-hostconfig.md).
3. **TrueNAS** (192.168.1.79): Hier liegen alle lokalen Backups, ohne TrueNAS kein vzdump-Restore.
4. **Pi-hole** .99 (CT 117, n02) und .59 (CT 105, n01). Ohne DNS geht im Netz fast nichts,
   denn die UniFi-Regel „DNS extern sperren“ lässt keine anderen DNS-Server zu.
5. **debian-ansible** (192.168.1.133). Die IP ist fest, weil alle Hosts den Ansible-Schlüssel
   nur von dort annehmen (`controller_ips` in `inventory.yaml`).
6. **cloudflared1 und cloudflared2** (.75, .72): Zugang von aussen, siehe [cloudflared.md](cloudflared.md).
7. **Vaultwarden** (.74), **NPM** (.78), **Nextcloud** (TrueNAS-App), **Home Assistant** (.80).
8. **Uptime Kuma**, dann der Rest: websrv, inventar, glance, flickr, camsnaps, mbusmaster.

Einen Container aus vzdump zurückholen, auf einem Node als root:

```
ls /mnt/pve/NAS-SMB/dump/ | grep -- -<CTID>-
pct restore <CTID> /mnt/pve/NAS-SMB/dump/vzdump-lxc-<CTID>-<Datum>.tar.zst --storage <Speicher>
pct start <CTID>
```

Die IP steckt in der Gast-Config und kommt mit dem Backup zurück. Danach auf debian-ansible
als transport `run.sh updates --limit <name>`.

## Was tun, wenn …

### … nichts mehr aufgelöst wird (DNS)

1. Laufen die Pi-holes? Auf proxmox-n02 als root `pct status 117`, auf proxmox-n01 `pct status 105`.
2. `dig @192.168.1.99 github.com` vom Mac. SERVFAIL heisst, Unbound kommt nicht raus: Unbound
   leitet per DNS-over-TLS an 8.8.8.8 und 8.8.4.4 weiter. Die UniFi-Policy „DNS Pi-holes erlauben“
   muss für beide Pi-holes Port 53 **und 853** erlauben.
3. Notlösung, solange kein Pi-hole läuft: in UniFi die Policy „DNS extern sperren“ kurz
   ausschalten und im Mac einen öffentlichen DNS-Server eintragen. Danach wieder einschalten.

### … von aussen nichts erreichbar ist

1. Uptime Kuma: Sind „Cloudflare Tunnel 1“ und „2“ rot? Dann [cloudflared.md](cloudflared.md).
2. Beide grün, aber ein einzelner Dienst nicht: Ziel im Cloudflare-Dashboard prüfen
   (Zero Trust > Networks > Tunnels), dann den Dienst selbst.
3. Nur aus dem Ausland? Die Cloudflare-Regel lässt nur CH, DE, IT und NL zu. Unterwegs
   Teleport nutzen.

### … ein Container kaputt ist

Aus vzdump zurückholen (Befehl oben). Ist der Stand von Sonntag zu alt, gibt es bei
Vaultwarden, Nextcloud und Home Assistant eigene, neuere Backups (Tabelle oben).

### … Vaultwarden ausfällt

- Die Apps zeigen weiter alles an. Nichts neu anlegen, bis der Server wieder läuft.
- Container aus vzdump zurückholen oder das neueste tar aus
  `/mnt/tank01/vaultwarden-backups/vaultwarden` auf einen frischen Container entpacken.
  Backup-Skript: [vaultwarden-backup.md](vaultwarden-backup.md).
- Ist das 2FA-Gerät weg: Recovery-Code vom Notfallblatt.

### … debian-ansible ausfällt

- Nichts geht kaputt, es fehlen nur die Updates am Sonntag, die Host-Config-Sicherung und der
  Git-Mirror. Kuma meldet die ausbleibenden Pushes.
- Am einfachsten aus vzdump zurückholen, dann ist auch der transport-Schlüssel wieder da.
  Ein frischer Container muss wieder 192.168.1.133 bekommen. Danach:
  [neue-maschine.md](neue-maschine.md) und `run.sh newserver --limit ansible`.

### … ein Node ausfällt

- Die Gäste auf diesem Node sind weg, es gibt keine automatische Übernahme. Der Cluster
  bleibt bedienbar, solange zwei der drei Nodes laufen (n03 zählt mit).
- Was dringend ist, auf dem anderen Node aus vzdump zurückholen (siehe oben), mit derselben
  CTID. Vorher den Gast im Cluster vom toten Node entfernen, sonst gibt es die CTID zweimal.
- Doppelt vorhanden und laufen weiter: Pi-hole (.99 auf n02, .59 auf n01) und cloudflared
  (.75 auf n01, .72 auf n02).
- Node neu aufsetzen: [proxmox-hostconfig.md](proxmox-hostconfig.md), Abschnitt „Zurückspielen“.

### … zwei Nodes gleichzeitig weg sind

Ohne Quorum lässt Proxmox nichts mehr ändern, auch keinen Gast starten. Auf dem letzten
Node als root `pvecm expected 1`, dann geht es wieder. Das gilt bis zum nächsten Neustart
des Clusters.

### … TrueNAS ausfällt

- Alle lokalen Backups, Nextcloud und die Kopien der Proxmox-Nodes sind dann weg. Laufende
  Gäste auf den Nodes laufen weiter, nur das nächste vzdump schlägt fehl.
- TrueNAS neu installieren und die Config von LastResort einspielen
  (`truenas/truenas-config-*.tar`, System → General → Manage Configuration → Upload Config).
  Dann sind die TrueCloud-Tasks mit den Storj-Zugängen wieder da, und die Daten kommen aus
  Storj zurück. Ohne die Disk: Storj-Zugänge aus Vaultwarden, Tasks von Hand anlegen.

### … GitHub nicht erreichbar ist

Die Deploys (Webseite, Glance, Uploader, inventar) holen nichts Neues, alles läuft aber weiter.
Kopien aller Repos: Git-Mirror auf debian-ansible und LastResort.

### … alles weg ist (äusserster Notfall: LastResort)

Haus, Homelab und Vaultwarden sind weg, oder nichts davon ist mehr vertrauenswürdig
(Ransomware). Ausgangspunkt ist die Disk LastResort, dazu ein Mac und das Notfallblatt.
Die genauen Schritte stehen auch auf der Disk selbst (`LIESMICH.md` in jedem Lauf).

1. **Disk prüfen.** Am Mac entsperren (Disk-Passwort vom Notfallblatt), den neuesten Lauf
   nehmen und im Terminal:
   ```
   cd /Volumes/LastResort/homelab-backup/<Datum_Zeit> && shasum -a 256 -c SHA256SUMS | grep -v ': OK$'
   ```
   Keine Ausgabe heisst alles heil. Sonst den Lauf davor nehmen.
2. **Passwörter zurück.** In der Bitwarden-App oder auf bitwarden.com (Konto anlegen genügt)
   `vaultwarden/bitwarden_encrypted_export_*.json` importieren, mit dem Export-Passwort vom
   Notfallblatt. Darin stehen auch Storj, Cloudflare, GitHub und die Server-Secrets.
3. **Netz und Proxmox** (n01, n02) neu aufsetzen und den Cluster bilden.
4. **TrueNAS** neu installieren, dann `truenas/truenas-config-*.tar` einspielen (System →
   General → Manage Configuration → Upload Config). Damit sind Tasks und Storj-Zugänge wieder
   da, und die Daten lassen sich aus Storj zurückholen.
5. **Gäste:** `proxmox-vzdump/` auf einen Proxmox-Storage kopieren und zurückspielen, in der
   Reihenfolge oben. Pi-hole und debian-ansible zuerst.
6. **Vaultwarden-Server:** `vaultwarden/vaultwarden-backup-*.tar.gz` oder der vzdump-Stand.
7. **Home Assistant:** neue Installation, beim Onboarding „Aus Backup wiederherstellen“ mit
   `homeassistant/*.tar`.
8. **Nextcloud:** Dateien liegen offen in `nextcloud/`, sonst Storj.
9. **Code:** `git clone /Volumes/LastResort/homelab-backup/<Datum_Zeit>/git/ansible.git` usw.

Der Stand ist höchstens 3 Monate alt. Neueres liegt nur in Storj, und dafür braucht man
zuerst die Zugänge aus Schritt 2.
