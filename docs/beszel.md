# Beszel (Auslastung, Platten, Temperaturen mit Verlauf)

Uptime Kuma sagt, ob etwas läuft. Beszel zeigt, wie es den Hosts geht: CPU,
RAM, Disk, Netz, Temperaturen und auf den Proxmox-Nodes und dem TrueNAS die
SMART-Werte der Platten, jeweils mit Verlauf. Alarme (Disk voll, RAM am
Anschlag, Host weg, zu heiss) gehen an ntfy.

- **Hub**: Container `debian-beszel.lan`, 192.168.1.71, auf proxmox-n02,
  Weboberfläche `http://debian-beszel.lan:8090`, im LAN auch
  `https://beszel.mythenstrasse56.net` (NPM, nicht über den Tunnel).
- **Agents**: ein kleines Programm auf jedem Host, Port 45876. Der Hub verbindet
  sich zu den Agents, nicht umgekehrt. Ein Agent antwortet nur dem öffentlichen
  Schlüssel des Hubs (`beszel_hub_key` in `inventory.yaml`).
- **Ansible** (`run.sh beszel`, auch im Sonntagslauf `run.sh updates`):
  installiert den Agent auf allen Hosts in `debianservers` und
  `proxmoxservers`, bringt Agents und Hub auf die neueste Version und schreibt
  die Liste der Systeme in den Hub. Ausgeschaltete Hosts (hercules) werden
  übersprungen.
- **TrueNAS** ist nicht in Ansible: der Agent läuft dort als App (Abschnitt 6).
- **Vaultwarden** (Alpine) hat vorerst keinen Agent.

## 1. Container anlegen (auf proxmox-n02 als root)

Vorher prüfen, dass die IP frei ist (muss ins Leere gehen):

```
ping -c 2 192.168.1.71
```

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/beszel.sh)"
```

Im Menü **Advanced** wählen und setzen:
- Hostname `debian-beszel`
- IPv4 statisch `192.168.1.71/24`, Gateway `192.168.1.1`
- DNS `192.168.1.99` (Pi-hole), Domain `lan`
- Rest Standard (Debian 13, unprivileged, 1 CPU, 512 MB, 5 GB)

CTID notieren.

Im Pi-hole unter **Local DNS > DNS Records** `debian-beszel.lan` auf
`192.168.1.71` eintragen.

## 2. In Ansible aufnehmen (auf debian-ansible als transport)

Der Eintrag `beszel` steht schon in `inventory.yaml`. Ablauf wie in
`neue-maschine.md`, CTID einsetzen:

```
/home/transport/clone.sh
/home/transport/ansible/run.sh bootstrap --limit proxmox-n02 -e ctid=<CTID>
ssh -4 transport@debian-beszel.lan exit
ansible beszel -i /home/transport/ansible/inventory.yaml -m ping
/home/transport/ansible/run.sh newserver --limit beszel
```

Danach auf proxmox-n02 als root: `pct exec <CTID> -- passwd gato`.

## 3. Konto im Hub anlegen (im Browser)

`http://debian-beszel.lan:8090` öffnen. Beim ersten Aufruf fragt Beszel nach dem
Admin-Konto:
- E-Mail `gato@mythenstrasse56.net` (muss nicht existieren, ist nur der Login)
- langes zufälliges Passwort, vorher in Vaultwarden als „Beszel“ anlegen

Das erste Konto ist das einzige; weitere Konten legt nur der Admin an.

## 4. Schlüssel des Hubs eintragen

Im Hub oben rechts **Add System** (System hinzufügen). Der Dialog zeigt unten
den **Public Key** (`ssh-ed25519 AAAA...`). Kopieren und den Dialog **ohne zu
speichern** schliessen: die Systeme trägt Ansible ein.

Den Schlüssel in `inventory.yaml` bei `beszel_hub_key` eintragen (oder Claude
schicken), committen und pushen. Er ist öffentlich und darf ins Repo.

## 5. Agents ausrollen (auf debian-ansible als transport)

```
/home/transport/clone.sh
/home/transport/ansible/run.sh qdevice-setup
/home/transport/ansible/run.sh beszel
```

`qdevice-setup` öffnet auf dem Pi (debian-qdevice) den Port 45876 in der
Firewall, sonst erreicht der Hub den Agent dort nicht. `beszel` installiert die
Agents, schreibt `/opt/beszel/beszel_data/config.yml` (die Liste der Systeme
aus dem Inventory) und startet den Hub neu.

Im Hub sollten danach alle Hosts nach einer Minute grün sein, hercules grau
(ausgeschaltet).

Neuer Host: kommt er nach `debianservers`, ist er beim nächsten `run.sh beszel`
oder Sonntagslauf automatisch dabei, mit Agent und im Hub.

**Achtung:** Der Hub löscht Systeme, die nicht in `config.yml` stehen, samt
Verlauf. Einen Host im Inventory umbenennen heisst im Hub: alter weg, neuer
ohne Verlauf. Von Hand im Hub angelegte Systeme verschwinden beim nächsten
Lauf; dauerhaft gehören sie in `beszel_extra_systems` in `inventory.yaml`.

## 6. Agent auf dem TrueNAS (im TrueNAS-Webinterface)

Zuerst die Platten nachschauen, unter **System > Shell**:

```
lsblk -d -o NAME,MODEL,SIZE
```

Dann **Apps > Discover Apps > ⋮ > Install via YAML**, Name `beszel-agent`, und
einfügen. Bei `KEY` den Schlüssel aus Schritt 4 einsetzen und bei `devices`
eine Zeile pro Platte aus `lsblk` (z. B. `sda`, `nvme0n1`):

```yaml
services:
  beszel-agent:
    # :alpine bringt smartctl und zfs mit
    image: henrygd/beszel-agent:alpine
    container_name: beszel-agent
    restart: unless-stopped
    network_mode: host
    # SMART: Rohzugriff auf die Platten, NVMe braucht auch SYS_ADMIN
    cap_add:
      - SYS_RAWIO
      - SYS_ADMIN
    devices:
      - /dev/sda:/dev/sda
      - /dev/sdb:/dev/sdb
    volumes:
      - beszel_agent_data:/var/lib/beszel-agent
      - /var/run/docker.sock:/var/run/docker.sock:ro
      # Belegung des Pools zusätzlich zur Systemplatte
      - /mnt/tank01/.beszel:/extra-filesystems/tank01:ro
    environment:
      LISTEN: 45876
      KEY: "ssh-ed25519 AAAA..."
volumes:
  beszel_agent_data:
```

Vorher in der Shell als root den Ordner für die Pool-Belegung anlegen:

```
mkdir -p /mnt/tank01/.beszel
```

Im Hub erscheint das TrueNAS als `truenas` (steht in `beszel_extra_systems`).
Den Zustand des Pools (`zpool status`) prüft weiterhin das TrueNAS-Status-Skript
für Uptime Kuma.

## 7. Alarme an ntfy

**ntfy-Absender anlegen** (in debian-ntfy als root, wie in `ntfy.md`):

```
ntfy user add beszel
ntfy access beszel beszel write-only
ntfy token add --label="Beszel Hub" beszel
```

Token in Vaultwarden ablegen. In der iPhone-App das Thema `beszel`
abonnieren.

**Im Hub** unter **Settings > Notifications** bei **Webhook / Push
notifications** **Add URL** und eintragen (Token einsetzen):

```
ntfy://:tk_...@debian-ntfy.lan/beszel?scheme=http&priority=high
```

Der leere Benutzername vor dem `:` ist Absicht, ntfy nimmt den Token als
Passwort. **Test URL** muss eine Meldung aufs iPhone bringen. **Save**.

**Alarme einstellen**: im Hub bei einem System auf die Glocke. Im Reiter
**All Systems** gilt es für alle Hosts. Vorschlag:

| Alarm | Wert | Dauer |
| --- | --- | --- |
| Status (Host weg) | – | – |
| Disk | 85 % | 10 min |
| Memory | 90 % | 10 min |
| CPU | 90 % | 15 min |
| Temperature (nur Nodes und TrueNAS) | 80 °C | 10 min |

Danach bei hercules den Status-Alarm wieder ausschalten, der ist meistens
absichtlich aus.

## 8. Erreichbarkeit, Kuma, Glance

**NPM**: Proxy Host `beszel.mythenstrasse56.net` → `http` `192.168.1.71` Port
`8090`, **Websockets Support** an, SSL mit dem Wildcard-Zertifikat. Nur im LAN
(Pi-hole zeigt `*.mythenstrasse56.net` auf NPM), **kein** Eintrag im
Cloudflare Tunnel. Ansible setzt diese Adresse als `APP_URL`, damit die Links in
den ntfy-Meldungen stimmen.

**Uptime Kuma**: auf dem Mac in `~/Documents/Code/shell` wie gewohnt
`uptimekuma-sync.py` (erst ohne, dann mit `--apply`). Von Hand geht auch ein
HTTP-Monitor auf `http://debian-beszel.lan:8090/api/health`.

**Glance**: Links und die Versionsanzeige kommen im glance-Repo.

## Updates

Agents und Hub holen sich die neueste Version von GitHub mit `run.sh beszel`,
das im Sonntagslauf (`run.sh updates`) mitläuft. Der TrueNAS-Agent aktualisiert
sich über **Apps** wie die anderen Apps. Der Hub bleibt im Container auch per
`update` (Community Script) aktualisierbar, das ist aber nicht nötig.

## Wenn etwas klemmt

| Meldung | Ursache und Lösung |
| --- | --- |
| System im Hub rot, `beszel` meldet `Check that the hub can reach the agent` | Agent läuft nicht. Auf dem Host: `systemctl status beszel-agent`, `journalctl -u beszel-agent -n 50`. |
| `status=226/NAMESPACE` beim Agent | Der Container kann die Abschottung im Unit-File nicht. In `inventory.yaml` beim Host `beszel_agent_sandbox: false`, dann `run.sh beszel --limit <host>`. |
| Agent läuft, Hub zeigt trotzdem rot | Falscher Schlüssel: `beszel_hub_key` mit dem Public Key im Hub vergleichen (Schritt 4). |
| Keine SMART-Werte auf einem Node | `smartctl --scan` als root auf dem Node. Ist die Liste leer, sieht auch Beszel nichts. |
| `beszel` endet still ohne Änderungen | `beszel_hub_key` ist leer (Schritt 4). |
