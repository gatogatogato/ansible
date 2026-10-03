# Cloudflare Tunnel (debian-cloudflared1 und debian-cloudflared2)

Alle öffentlichen Dienste (gatogatogato.ch, Vaultwarden, Nextcloud, Home Assistant)
laufen über einen Cloudflare Tunnel. Der Router lässt nichts herein. Der Tunnel hat
zwei Connectoren, je einen pro Node. Beide nutzen denselben Token, Cloudflare
verteilt den Verkehr selbst auf die verbundenen Connectoren. Fällt einer aus (Container,
Node, Update), läuft alles über den anderen weiter.

| | debian-cloudflared1 | debian-cloudflared2 |
| --- | --- | --- |
| Ansible-Name | `cloudflared1` | `cloudflared2` |
| Node | proxmox-n01 | proxmox-n02 |
| Adresse | 192.168.1.75 | 192.168.1.72 |
| Zustand | http://debian-cloudflared1.lan:2000/ready | http://debian-cloudflared2.lan:2000/ready |

Beide statisch im Container gesetzt, DNS-Einträge im Pi-hole. Nie auf proxmox-n03.

- **Routen** (Public Hostnames) stehen nur im Cloudflare-Dashboard: Zero Trust >
  Networks > Tunnels. Sie gelten für alle Connectoren, beim Ausbau ändert sich daran nichts.
- **Token:** `/etc/cloudflared/token` auf jedem Connector (nur root), Kopie in
  `/home/transport/.config/cloudflared-secrets/token` auf debian-ansible und in Vaultwarden.
  Nie in git.
- **Dienst:** `cloudflared.service`, die Unit schreibt Ansible (`templates/cloudflared.service.j2`).
- **Updates:** cloudflared kommt aus Cloudflares apt-Repo und wird mit den
  wöchentlichen Updates aktualisiert.
- **Wer den Connectoren vertraut:** Nextcloud (`trusted_proxies` mit beiden IPs, damit
  es die echte Client-IP sieht). Kommt ein weiterer Dienst mit so einer Liste dazu
  (z. B. Home Assistant), beide IPs eintragen.
- **Uptime Kuma:** pro Connector ein HTTP-Monitor auf `/ready` (200 nur, wenn er mit
  Cloudflare verbunden ist). Die Webseiten selbst bleiben grün, wenn nur ein Connector
  fehlt, darum braucht es diese zwei Monitore.

## Befehle (auf debian-ansible, als transport)

```
/home/transport/ansible/run.sh cloudflared-setup                  # beide Connectoren
/home/transport/ansible/run.sh cloudflared-setup --limit cloudflared2
/home/transport/ansible/run.sh cloudflared-token-backup --limit cloudflared1
```

`cloudflared-setup` installiert cloudflared, wenn es fehlt, legt Token und Unit ab und
startet den Dienst nur neu, wenn sich etwas geändert hat. Die Connectoren kommen
nacheinander dran, der zweite erst, wenn der erste wieder verbunden ist. So bleibt der
Tunnel immer erreichbar.

`cloudflared-token-backup` liest den Token auf dem Connector (aus `/etc/cloudflared/token`
oder aus der Unit von `cloudflared service install`) und legt ihn auf debian-ansible ab.
Es ändert auf dem Connector nichts und überschreibt nie eine abweichende Kopie.

## Neuen Connector aufsetzen (auch nach einem Totalausfall)

1. LXC anlegen mit dem community-script **Cloudflared**
   (https://community-scripts.org/scripts/cloudflared) auf dem richtigen Node, Hostname
   `debian-cloudflaredN`, IPv4 statisch (Tabelle oben). Kein `cloudflared service install`
   ausführen, den Dienst richtet Ansible ein. DNS-Eintrag `debian-cloudflaredN.lan` im Pi-hole.
2. Auf debian-ansible als transport, wie in `docs/neue-maschine.md`:

   ```
   /home/transport/clone.sh
   /home/transport/ansible/run.sh bootstrap --limit proxmox-n02 -e ctid=<CTID>
   ssh -4 transport@debian-cloudflared2.lan exit
   /home/transport/ansible/run.sh newserver --limit cloudflared2
   /home/transport/ansible/run.sh cloudflared-setup --limit cloudflared2
   ```

3. Im Cloudflare-Dashboard beim Tunnel prüfen: der neue Connector ist aufgeführt.

Fehlt auch die Token-Kopie auf debian-ansible (beide Connectoren und debian-ansible weg):
den Token aus Vaultwarden oder aus dem Dashboard (Tunnel > Configure > Token) in
`/home/transport/.config/cloudflared-secrets/token` schreiben (Ordner 0700, Datei 0600).

## Ausfalltest

Einen Connector stoppen (`pct stop <CTID>` auf dem Node), dann gatogatogato.ch,
vault.mythenstrasse56.net, nextcloud.mythenstrasse56.net und ha.mythenstrasse56.net
öffnen. Alles muss gehen, in Kuma wird nur der `/ready`-Monitor des gestoppten Connectors
rot. Wieder starten, dann den anderen testen.

## Umbau von einem auf zwei Connectoren (einmalig, Oktober 2026)

Vorher gab es nur `debian-cloudflared` (192.168.1.75, proxmox-n01), von Hand mit
`cloudflared service install <token>` eingerichtet. Ablauf ohne Unterbruch:

1. **Pi-hole:** zusätzlich `debian-cloudflared1.lan` auf 192.168.1.75 eintragen (der alte
   Name bleibt vorerst) und `debian-cloudflared2.lan` auf 192.168.1.72.
2. **Nextcloud:** die neue IP als vertrauenswürdigen Proxy ergänzen, *bevor* cloudflared2
   Verkehr bekommt. Sonst sieht Nextcloud für diese Anfragen nur 192.168.1.72 als Absender,
   und der Brute-Force-Schutz wirft alle in einen Topf. In der TrueNAS-Shell als root:

   ```
   docker exec -u www-data ix-nextcloud-nextcloud-1 php occ config:system:get trusted_proxies
   docker exec -u www-data ix-nextcloud-nextcloud-1 php occ config:system:set trusted_proxies 2 --value=192.168.1.72
   ```

   Der erste Befehl muss vorher `127.0.0.1` und `192.168.1.75` zeigen (Index 0 und 1),
   danach zusätzlich `192.168.1.72`.

3. **PR mergen**, dann auf debian-ansible als transport:

   ```
   /home/transport/clone.sh
   ssh -4 transport@debian-cloudflared1.lan exit
   /home/transport/ansible/run.sh cloudflared-token-backup --limit cloudflared1
   ```

   Den Token zusätzlich als sichere Notiz in Vaultwarden ablegen.
4. **cloudflared2 aufsetzen** wie oben unter „Neuen Connector aufsetzen“. Ab jetzt zeigt
   das Dashboard zwei Connectoren.
5. **cloudflared1 umstellen** (Token aus der Unit in die Datei, Metrics-Port). Der Dienst
   startet dabei neu, der Tunnel läuft in der Zeit über cloudflared2:

   ```
   /home/transport/ansible/run.sh cloudflared-setup --limit cloudflared1
   ```

6. **Umbenennen:** in Proxmox beim Container von debian-cloudflared (proxmox-n01) unter DNS > Hostname
   `debian-cloudflared1` eintragen, Container neu starten (wieder über cloudflared2
   abgedeckt). Danach im Pi-hole den alten Eintrag `debian-cloudflared.lan` löschen.
7. **Uptime Kuma:** zwei HTTP-Monitore anlegen, „Cloudflare Tunnel 1“ auf
   `http://debian-cloudflared1.lan:2000/ready` und „Cloudflare Tunnel 2“ auf
   `http://debian-cloudflared2.lan:2000/ready`. Dann auf dem Mac `uptimekuma-sync.py`
   (legt die Ping-Monitore für die neuen Namen an, pausiert den alten, den im GUI löschen)
   und `uptimekuma-statuspage.py --apply`.
8. **inventar:** Notizen für .75 und .72 setzen.
9. **Ausfalltest** wie oben.
