# Home Media Server Reference (jellyfin01)

Oct 15, 2026 · @my name does not matter

## Overview

jellyfin01 (VM 111 on Proxmox node `homelab`) serves movies, TV and music to the home network from a 4 TB drive. The NAS (nas01) is not part of the media setup; it stays on homelab backups and quorum.

| Address | Service | Purpose | Login |
| --- | --- | --- | --- |
| `https://media.internal` | Jellyfin | Watch and listen | Jellyfin account (household or Guest) |
| `https://media.internal/uploads` | File Browser | Drag-and-drop uploads, no delete | File Browser account (lowercase username) |
| `\\media.internal\Media` | Samba | Read-only file share for people who use their own player | `mediaview` (shared) |
| `https://jellyfin01.example-tailnet.ts.net` | Jellyfin and File Browser over Tailscale | Access away from home | Same accounts, from a device shared into Tailscale |

The `http://` forms, the older `media.home.arpa` name and `http://192.168.30.10` all still work. Android phones need `media.internal`; they will not resolve `media.home.arpa`.

&#91;embedded content: media server architecture · DNS, firewall, services, storage\]

Only firewall01 ports 80, 443 and 445 are open from the home network. Everything else on the lab side stays unreachable from home.

## Network and addressing

Home clients reach jellyfin01 through firewall01's WAN address, 192.168.30.10, which forwards only ports 80, 443 and 445. The forward rewrites the destination only, so Jellyfin and Samba see each client's real 192.168.30.x address.

| Host | Role | Address | Notes |
| --- | --- | --- | --- |
| gateway01 (VM 107) | Home gateway, pfSense 2.9.0 | WAN 192.168.1.125, LAN 192.168.30.1 | Home DHCP hands out DNS 192.168.30.2 |
| pihole01 (CT 108) | DNS for home and lab | 192.168.30.2 | Holds the `media.internal` and `media.home.arpa` records |
| firewall01 (VM 101) | Lab firewall, pfSense 2.9.0 | WAN 192.168.30.10, LAN 192.168.10.1, CYBERMGMT 192.168.20.1 | WAN reserved on gateway01 (MAC BC:24:11:XX:XX:XX); LAN DHCP pool .100–.199 |
| jellyfin01 (VM 111) | Media server | 192.168.10.5 (static) | Gateway 192.168.10.1, DNS 192.168.30.2 |
| nas01 | ASUSTOR AS1202T, backups and quorum | 192.168.10.4 (static) | Not used by the media setup |
| Home clients | Viewers and uploaders | 192.168.30.0/24 | Use `media.internal` |

## firewall01 configuration

One port forward on firewall01's WAN sends home traffic on ports 80, 443 and 445 to jellyfin01; nothing else on the lab side is reachable from home.

**Interfaces → WAN → Reserved Networks**

- Block private networks and loopback addresses: **off** (the WAN sits on the private home subnet)
- Block bogon networks: **on**

**Firewall → Aliases**

| Alias | Type | Value | Used by |
| --- | --- | --- | --- |
| `HOME_NET` | Network | 192.168.30.0/24 | Port forward source |
| `JELLYFIN01` | Host | 192.168.10.5 | Port forward target |
| `MEDIA_PORTS` | Port | 80, 443, 445 | Port forward destination and redirect ports |
| `NAS01` | Host | 192.168.10.4 | Nothing (see Open items) |

**Firewall → NAT → Port Forward**

| Field | Value |
| --- | --- |
| Interface | WAN |
| Protocol | TCP |
| Source | `HOME_NET` |
| Destination | WAN address, ports `MEDIA_PORTS` |
| Redirect target | `JELLYFIN01`, ports `MEDIA_PORTS` |
| Filter rule association | Associated pass rule (auto-created) |

**Firewall → Rules → WAN** holds only the bogon block and the associated pass rule. Jellyfin's 8096, File Browser's 8080, SSH and the NAS's ADM ports are not forwarded. Blocked ports are dropped silently, which is why a browser's automatic https:// attempt timed out before 443 was added.

## DNS

`media.internal` is the main name. It and the older `media.home.arpa` both resolve to 192.168.30.10 (firewall01 WAN) through Pi-hole. Android phones resolve only `media.internal`; their system resolver never sends `.home.arpa` lookups (see Troubleshooting notes).

- **Pi-hole → Settings → Local DNS Records:** `media.internal` → `192.168.30.10` and `media.home.arpa` → `192.168.30.10`
- **gateway01 → Services → DNS Resolver → Host Overrides:** `media.home.arpa` → `192.168.30.10`, a fallback for devices that ask gateway01 directly
- **gateway01 → Services → DHCP Server → LAN → DNS Servers:** `192.168.30.2`
- **Check from a home PC:** `nslookup media.internal` should return 192.168.30.10 from server 192.168.30.2. On Android, use a network tool app such as Network Analyzer; Chrome has its own resolver and is not a fair test.

**From the lab side**, the name still resolves to 192.168.30.10, but the port forward accepts only home traffic. Lab machines use jellyfin01's IP directly: `http://192.168.10.5`, `http://192.168.10.5/uploads`, `\\192.168.10.5\Media`. Caddy answers to the IP as well as the name.

## jellyfin01 VM

jellyfin01 is a minimal Debian 13 (trixie) VM with a static address and the 4 TB media drive passed through whole. Transcoding is CPU-only; the GTX 970 stays on the host for local video output.

**Proxmox settings**

| Setting | Value |
| --- | --- |
| VM ID / name / node | 111 / jellyfin01 / homelab |
| Machine | q35 |
| CPU | 1 socket, 4 cores, type host |
| Memory | 4096 MB |
| OS disk (scsi0) | 32 GB |
| Media disk (scsi1) | `/dev/disk/by-id/ata-ST4000NM0033-9ZM170_SERIAL-REDACTED`, `backup=0` |
| Network | VirtIO on the bridge shared with firewall01's LAN NIC |
| QEMU guest agent | Enabled, `qemu-guest-agent` installed in the guest |
| Start at boot | Yes, ordered after firewall01 |

The media disk was attached from the host shell:

```
qm set 111 -scsi1 /dev/disk/by-id/ata-ST4000NM0033-9ZM170_SERIAL-REDACTED,backup=0
```

**Guest OS**

- Debian 13 netinst, only SSH server and standard system utilities, kernel 6.12
- Admin user `lab-admin` with sudo; root login disabled (blank root password at install)
- Installed packages: `qemu-guest-agent`, `curl`, `parted`, `jellyfin`, `caddy`, `samba`; File Browser binary in `/usr/local/bin`

**/etc/network/interfaces** (the `lo` section above it is unchanged)

```
auto ens18
iface ens18 inet static
    address 192.168.10.5/24
    gateway 192.168.10.1
```

**/etc/resolv.conf**

```
search homelab.local
nameserver 192.168.30.2
```

**/etc/dhcpcd.conf** has `nohook resolv.conf` appended, so dhcpcd never rewrites the DNS file.

## Storage and permissions

All media lives on one ext4 filesystem at `/srv/media`, so moving a file from Uploads into Media is an instant rename.

**Drive**

- Seagate Constellation ES.3 ST4000NM0033, 4 TB, serial SERIAL-REDACTED
- In a CENMATE 4-bay USB enclosure, single-disk (normal) mode; host device `sdg`
- SMART on 2026-10-14: PASSED, 0 reallocated, 0 pending, 0 uncorrectable sectors

**Filesystem**

- `/dev/sdb1` inside the VM: GPT, ext4, label `media`, created with `-m 0` (no root reserve)
- UUID `00000000-0000-0000-0000-000000000024`, 3.6 TB usable

**/etc/fstab line**

```
UUID=00000000-0000-0000-0000-000000000024  /srv/media  ext4  defaults,noatime,nofail  0  2
```

**Layout**

```
/srv/media
├── Media/      Jellyfin libraries, read-only to the household
│   ├── Movies/
│   ├── Music/
│   └── TV/
└── Uploads/    household uploads, waiting for review
```

**Permissions**

- Every folder: owner `lab-admin`, group `media`, mode `2775`. The setgid bit makes new files inherit the `media` group.
- `media` group members: `lab-admin`, `jellyfin`, `filebrowser`.
- Household users have no Linux accounts. `mediaview` is a no-login account used only by Samba.

**Mount protection.** Jellyfin and File Browser carry `RequiresMountsFor=/srv/media`, so neither starts if the USB drive is missing. Jellyfin's is the drop-in `/etc/systemd/system/jellyfin.service.d/media-mount.conf`:

```
[Unit]
RequiresMountsFor=/srv/media
```

## Jellyfin

Jellyfin is installed from Jellyfin's own Debian repository, listens on 8096 behind Caddy, and treats both the lab and home subnets as local.

- **Installed with:** `curl -fsSL https://repo.jellyfin.org/install-debuntu.sh | sudo bash`
- **Service:** `jellyfin.service`, listening on `0.0.0.0:8096` (only Caddy is forwarded from home)
- **Data:** settings, users and watch history under `/var/lib/jellyfin`, transcode files under `/var/cache/jellyfin`; both are inside VM backups

| Dashboard area | Setting | Value |
| --- | --- | --- |
| General | Server name | Home Media |
| Networking | LAN networks | `192.168.10.0/24, 192.168.30.0/24, 100.64.0.0/10` |
| Networking | Known proxies | `127.0.0.1` |
| Networking | Allow remote connections | Off (see Open items) |
| Playback → Transcoding | Hardware acceleration | None |
| Playback → Transcoding | Allow encoding in HEVC | Off |
| Playback → Transcoding | Tone mapping | Off |
| Playback → Transcoding | Encoding preset | veryfast |
| Playback → Transcoding | Throttle transcodes / Delete segments | On / On |
| Branding | Login disclaimer | Upload link (below) |

**Libraries** (real-time monitoring on, metadata English / United States)

| Library | Content type | Folder |
| --- | --- | --- |
| Movies | Movies | `/srv/media/Media/Movies` |
| Music | Music | `/srv/media/Media/Music` |
| TV | Shows | `/srv/media/Media/TV` |

**Login disclaimer**

```
<a href="/uploads/" target="_blank">Upload media for the library</a>
```

**Users:** `lab-admin` (admin), `Guest` (password protected), three household accounts. Each non-admin user cannot manage the server or delete media, and keeps video transcoding, audio transcoding and remuxing allowed.

## File Browser

File Browser 2.63.23 is the upload page at `/uploads`. Household accounts see only `Uploads` and can add and download files but not delete, rename or overwrite them. The project is in maintenance-only mode (bug and security fixes, no new features), which is acceptable for a LAN-only uploader.

| Setting | Value |
| --- | --- |
| Binary | `/usr/local/bin/filebrowser` |
| Database | `/var/lib/filebrowser/filebrowser.db` |
| Runs as | user `filebrowser`, group `media`, umask 0002 |
| Listens on | `127.0.0.1:8080` (reached only through Caddy) |
| Root / base URL | `/srv/media` / `/uploads` |
| Default scope for new users | `/Uploads` |
| Default permissions for new users | Create and Download on; Delete, Rename, Modify, Share, Execute off |
| Admin account | `lab-admin`: admin, scope `/`, all file permissions |

**/etc/systemd/system/filebrowser.service**

```
[Unit]
Description=File Browser (media uploads)
After=network-online.target
Wants=network-online.target
RequiresMountsFor=/srv/media

[Service]
User=filebrowser
Group=media
UMask=0002
ExecStart=/usr/local/bin/filebrowser -d /var/lib/filebrowser/filebrowser.db
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

**Command-line changes.** File Browser locks its database while running, so stop it first:

```
sudo systemctl stop filebrowser
DB=/var/lib/filebrowser/filebrowser.db
sudo -u filebrowser filebrowser config cat -d $DB
sudo -u filebrowser filebrowser users ls -d $DB
sudo systemctl start filebrowser
```

Usernames are case-sensitive; keep them lowercase. Day-to-day user management happens in the web page under Settings → User Management.

## Caddy

Caddy 2.6.2 (Debian package) serves HTTPS on 443 with certificates from its own built-in CA, and keeps plain HTTP on 80 as a fallback. It routes `/uploads` to File Browser and everything else to Jellyfin, with no upload size limit.

**/etc/caddy/Caddyfile**

```
{
	skip_install_trust
}

(media_routes) {
	handle /uploads* {
		reverse_proxy 127.0.0.1:8080
	}
	handle {
		reverse_proxy 127.0.0.1:8096
	}
}

# HTTPS, using certificates from Caddy's own CA
media.internal, media.home.arpa {
	tls internal
	import media_routes
}

# Plain HTTP kept as a fallback (apps that won't trust the CA, IP access)
http://media.internal, http://media.home.arpa, http://192.168.10.5, http://192.168.30.10 {
	import media_routes
}

# Remote access over Tailscale (certificate issued by Tailscale)
jellyfin01.example-tailnet.ts.net {
	import media_routes
}
```

- `tls internal` issues and renews certificates for both names automatically.
- `skip_install_trust` stops Caddy from trying to add its CA to the VM's own trust store.
- The explicit `http://` block keeps HTTP working instead of redirecting to HTTPS.

After any edit: `sudo caddy fmt --overwrite /etc/caddy/Caddyfile`, `sudo caddy validate --config /etc/caddy/Caddyfile`, then `sudo systemctl reload caddy`.

**Certificate authority**

- CA files: `/var/lib/caddy/.local/share/caddy/pki/authorities/local/`. Only `root.crt` is ever shared; the `.key` files are the CA's private keys.
- Household copy: `/srv/media/Uploads/home-media-ca.crt`, mode 664, downloadable through File Browser.
- Site and intermediate certificates renew automatically. The root lasts for years, but if `/var/lib/caddy` is lost (for example, the VM is rebuilt without a backup), Caddy makes a new root and every device must trust it again.

**Trusting the root on a device** (once per device; until then HTTPS shows a warning and `http://` still works)

| Device | Steps |
| --- | --- |
| Windows | Double-click the file → Install Certificate → Local Machine → Place all certificates in the following store → Trusted Root Certification Authorities |
| Android | Settings → Security & privacy → More security settings → Encryption & credentials → Install a certificate → CA certificate |
| iPhone / iPad | Open the file to install the profile in Settings, then enable it under General → About → Certificate Trust Settings |

Some Android apps ignore user-installed certificates; if the Jellyfin app refuses `https://media.internal`, use `http://media.internal`.

## Samba

Samba shares only `Media`, read-only for the shared `mediaview` login and writable for `lab-admin`. Uploading is done through the web page, so there is no writable household share.

**Accounts**

```
sudo useradd -M -s /usr/sbin/nologin mediaview
sudo smbpasswd -a mediaview
sudo smbpasswd -a lab-admin
```

SMB passwords are separate from Linux login passwords.

**Share block appended to /etc/samba/smb.conf**

```
[Media]
   path = /srv/media/Media
   browseable = yes
   read only = yes
   guest ok = no
   valid users = lab-admin mediaview
   write list = lab-admin
   force group = media
   create mask = 0664
   directory mask = 2775
```

Check with `testparm -s`, apply with `sudo systemctl restart smbd`. Verified 2026-10-14: `mediaview` can browse but not create folders.

## Remote access (Tailscale)

Away from home, family reach the server at `https://jellyfin01.example-tailnet.ts.net` (uploads at `/uploads`). jellyfin01 sits in your tailnet and is shared with each family member, who can see only that machine and only its media ports. Local access is unchanged.

| Item | Value |
| --- | --- |
| Tailnet | `example-tailnet.ts.net` |
| jellyfin01 Tailscale IP | `100.64.0.15` |
| Remote address | `https://jellyfin01.example-tailnet.ts.net` |
| Certificate | Publicly trusted, issued by Tailscale; Caddy obtains and renews it |
| Key expiry | Disabled in the admin console |
| Installed with | `curl -fsSL https://tailscale.com/install.sh \| sh`, then `sudo tailscale up --hostname=jellyfin01` |

**Server-side changes**

- `/etc/default/tailscaled` has `TS_PERMIT_CERT_UID=caddy`, so Caddy can request the `ts.net` certificate.
- The Caddyfile has a `jellyfin01.example-tailnet.ts.net { import media_routes }` block, with no `tls` line.
- `/etc/ssh/sshd_config.d/10-lan-only.conf` holds `ListenAddress 192.168.10.5`, so over Tailscale only 80, 443, 445 and 8096 answer.
- Jellyfin's LAN networks include `100.64.0.0/10`; without it, remote connections are refused.

**Tailscale policy additions.** Shared users are governed by your tailnet's policy. Without a rule naming them, their device shows jellyfin01 as connected but every connection times out.

```
"hosts": {
  "jellyfin01": "100.64.0.15"
},

"grants": [
  {
    "src": ["family-member@example.com"],
    "dst": ["jellyfin01"],
    "ip":  ["tcp:80", "tcp:443", "tcp:445"]
  }
]
```

**Adding a family member**

1. Admin console → Machines → jellyfin01 → ⋯ → Share, and send them the invite link.
2. They install Tailscale, sign in with their own account, and accept the invite.
3. Add their login email to the grant's `src` list and save the policy.
4. In the Jellyfin app they add `https://jellyfin01.example-tailnet.ts.net` and log in with their existing Jellyfin account.

The `ts.net` address also works at home while Tailscale is running. Roku and other TVs can't run Tailscale and stay on local addresses. Remote streams are limited by the home upload speed, so lower the playback quality on slow connections.

## Accounts and access

Each household member has matching Jellyfin and File Browser logins; SMB uses one shared read-only login. No passwords are recorded here.

| Account | Jellyfin | File Browser | SMB | Linux |
| --- | --- | --- | --- | --- |
| lab-admin | Admin | Admin, whole drive, all permissions | Read/write via `lab-admin` | Sudo admin |
| Household members | User, transcoding allowed | `/Uploads`: create and download only | Read-only via `mediaview` | None |
| Guest | User, password protected | None unless added | Read-only via `mediaview` | None |
| mediaview | None | None | Read-only on `Media` | No-login account |
| jellyfin, filebrowser | Service accounts | Service accounts | None | Members of `media` |

## Operations

**Adding media**

1. A household member uploads at `https://media.internal/uploads`.
2. You log in to File Browser as `lab-admin` and review the file in `Uploads`.
3. Rename it to Jellyfin's naming and move it into the right folder under `Media`. Same filesystem, so the move is instant.
4. Jellyfin's real-time monitoring adds it to the library within about a minute; reload the web page to see it. Delete rejected uploads from `Uploads`.

```
Movies/The Matrix (1999)/The Matrix (1999).mkv
TV/Show Name/Season 01/Show Name S01E01.mkv
Music/Artist/Album/01 - Track Title.flac
```

**Updates** (on jellyfin01)

- Jellyfin, Caddy, Samba and Debian: `sudo apt update && sudo apt full-upgrade -y`
- File Browser (not in apt): `sudo systemctl stop filebrowser`, re-run `curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | sudo bash`, `sudo systemctl start filebrowser`

**Backups**

- Proxmox backups of VM 111 cover the OS disk, including Jellyfin's settings, users and watch history, and File Browser's database.
- The 4 TB media disk is excluded (`backup=0`) and exists in one copy. Keep a second copy of anything irreplaceable, such as personal music or home video.

**If the USB drive disconnects**

Jellyfin and File Browser refuse to start without `/srv/media`. After reconnecting the drive:

```
sudo mount -a
df -h /srv/media
sudo systemctl restart jellyfin filebrowser
```

**Health checks**

- Drive health, on the Proxmox host: `smartctl -a -d sat /dev/sdg | grep -i -E "reallocated|pending|uncorrect|result"`. The `sdg` name can change; `ls -l /dev/disk/by-id/ | grep SERIAL-REDACTED` shows the current one.
- Free space, on jellyfin01: `df -h /srv/media`, or the usage bar in File Browser's sidebar. Watch `Uploads`, since household users can add but not remove files.
- Service status: `systemctl status jellyfin filebrowser caddy smbd --no-pager`

## Troubleshooting notes

Problems hit during the build, with the cause and fix for each.

| Symptom | Cause | Fix |
| --- | --- | --- |
| Android apps can't reach `media.home.arpa`; nothing reaches Pi-hole | Android's system resolver never sends `.home.arpa` lookups (Chrome's own resolver does) | Use `media.internal` as the main name |
| Phone Chrome times out on `http://media.home.arpa`, IP works | Chrome tries https:// first for names; 443 was dropped silently | HTTPS on Caddy and 443 in `MEDIA_PORTS` |
| File Browser returns 500 on a file copied in with `sudo cp` | The copy kept a `600` mode, so the `filebrowser` user can't read it | `sudo chown lab-admin:media <file>` and `sudo chmod 664 <file>`, or `cp --no-preserve=mode` |
| New item missing in Jellyfin's web page | The page doesn't refresh itself | Reload the page, or ⋯ → Scan library |
| `resolv.conf` emptied after the first reboot | dhcpcd released the old DHCP lease at shutdown and cleared the file | Static interface, `nohook resolv.conf` in `/etc/dhcpcd.conf`, rewrite the file |
| Jellyfin installer: insufficient free space for `/tmp` | Debian 13 `/tmp` is RAM-backed, sized at half of 4 GB | `sudo mount -o remount,size=3G /tmp`, then re-run; resets at reboot |
| `curl -sI` returns 404 from File Browser | It answers GET, not HEAD, for its pages | Test with `curl -s -o /dev/null -w "%{http_code}\n" <url>` |
| `filebrowser` commands fail or hang | The service holds a lock on its database | `sudo systemctl stop filebrowser` first |
| Windows SMB connects as the wrong user | Saved credentials | `net use * /delete`, reconnect, log in as `mediaview` |
| The name fails from a lab machine | The forward accepts only home traffic | Use `http://192.168.10.5` from the lab side |

## Open items

- [ ] Install the CA root on each household device and move bookmarks to `https://media.internal`
- [ ] Optional: add a `media.internal` host override on gateway01 to match the `media.home.arpa` one
- [ ] Delete the unused `NAS01` alias on firewall01
- [ ] Confirm Jellyfin's "Allow remote connections to this server" is unchecked
- [ ] Rename File Browser accounts to lowercase
- [ ] Check the Pi-hole records `gateway01.home.arpa` (192.168.1.1) and `pihole01.home.arpa` (192.168.1.2) against the current addresses 192.168.30.1 and 192.168.30.2
- [ ] Record which Proxmox bridge jellyfin01 uses
- [ ] Plan a second copy for irreplaceable media
- [ ] Migrate both pfSense boxes from ISC DHCP to Kea, then confirm the static mappings survived
- [ ] Share jellyfin01 with the remaining family members and add each login to the Tailscale grant
