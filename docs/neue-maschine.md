# Neue Maschine in Ansible aufnehmen

Kurzanleitung für einen neuen LXC (Debian oder Alpine). Danach ist er bei den
wöchentlichen Updates und Health-Checks automatisch dabei.

Nie etwas auf **proxmox-n03** anlegen, das ist nur der Raspberry Pi fürs Quorum.

## 1. LXC anlegen (Proxmox-Weboberfläche oder community-script)

Notieren:
- **CTID**, z. B. `118`
- **Node**, z. B. `proxmox-n01`
- **Hostname**, nach dem Schema `debian-<name>`, z. B. `debian-foo`

Im UniFi-Controller eine feste IP (Fixed IP) für den Container setzen, damit der
DNS-Name `debian-foo.lan` stabil bleibt. Der Container muss laufen.

## 2. Ansible-Zugang einrichten (auf debian-ansible, als transport)

```
/home/transport/clone.sh
/home/transport/ansible/run.sh bootstrap --limit proxmox-n01 -e ctid=118
```

Das geht über den Proxmox-Node per `pct exec` in den Container und richtet ein:
sudo, python3, sshd, den User transport, den Ansible-Key (nur von
debian-ansible erlaubt) und sudo ohne Passwort für transport.

## 3. Ins Inventory eintragen

In `inventory.yaml` unter `debianservers` (oder `alpineservers`):

```yaml
    foo:
      ansible_host: debian-foo.lan
```

Committen und pushen (oder Claude darum bitten), dann auf debian-ansible:

```
/home/transport/clone.sh
```

## 4. Erste Verbindung testen (auf debian-ansible, als transport)

Einmal den Host-Key bestätigen (mit `yes`) und dann per Ansible pingen:

```
ssh -4 transport@debian-foo.lan exit
ansible foo -i /home/transport/ansible/inventory.yaml -m ping
```

Erwartet: `"ping": "pong"`.

## 5. Grundsetup (nur Debian)

```
/home/transport/ansible/run.sh newserver --limit foo
```

Installiert die Standardpakete, legt gato an, setzt zsh, micro und das motd.
Bei Alpine diesen Schritt auslassen.

Danach auf dem Proxmox-Node (als root) ein Passwort für gato setzen, sonst
kann gato kein sudo:

```
pct exec 118 -- passwd gato
```

## Fertig

- Updates: läuft ab jetzt mit `run.sh updates` und im Sonntags-Cronjob mit.
- Optional: in Uptime Kuma einen Monitor für den Dienst anlegen.

## Wenn etwas klemmt

| Meldung | Ursache und Lösung |
| --- | --- |
| `needs --limit` | `bootstrap` braucht `--limit proxmox-n0X`, `newserver` braucht `--limit <name>`. |
| `container ... not running` bzw. `status` | Falscher Node oder Container gestoppt. `pct list` auf dem Node prüfen. |
| `Host key verification failed` | Schritt 4 (`ssh -4 …`) vergessen. |
| `Permission denied (publickey)` | Bootstrap nochmals laufen lassen. Im Container prüfen: `pct exec 118 -- cat /home/transport/.ssh/authorized_keys`. |
