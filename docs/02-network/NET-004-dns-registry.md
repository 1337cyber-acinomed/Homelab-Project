# NET-004 — DNS Registry

| Field | Value |
|---|---|
| Document ID | NET-004 |
| Version | 3.0 |
| Status | Authoritative — current state |
| Effective | 16 October 2026 |
| Owner | Jesse Breedlove (Project Polaris) |
| Supersedes | `DNS-registry.md`, `DNS-Registry-v2.md`, `dns-registry(1).md` (private archive) |

## 1. Zones and authorities

| Zone | Authoritative server | Scope | Status |
|---|---|---|---|
| `polaris.home.arpa` | firewall01 (pfSense DNS Resolver host overrides) | Homelab infrastructure names | Active |
| `ad.polaris` | dc01 (AD-integrated DNS) | Domain-joined Windows hosts | Active |
| `home.arpa` (home names) | pihole01 local DNS records; gateway01 host overrides | Household names | Active — stale records, see §4 |
| `internal` | pihole01 | `media.internal` (Android clients do not resolve `.home.arpa`) | Active |
| `<zone>.cyberrange.home.arpa` (attack, windows, linux, apps, siem, analysis, hybrid, hybrid-internal, quarantine) | cyber-fw01: Dnsmasq (DHCP names, 127.0.0.1:53053) behind Unbound; static names as Unbound Host Overrides | Cyber guests | Active |
| `oscp.range.home.arpa` | cyber-fw01 Unbound Host Overrides | OSCP lab VLAN 80 | Building |
| `corp.cyberrange.local` | cyber-DC01 (VM 320) 10.10.20.10 | Cyberrange AD forest (VLAN 20/71) | Active |
| `oscp.lab` | oscp-dc01 (VM 383, planned) | Separate OSCP AD forest on VLAN 81 | Planned |
| Tailnet MagicDNS (`*.ts.net`) | Tailscale | Remote access names | Active |

## 2. Resolution paths

| Client group | First resolver | Next hop | Notes |
|---|---|---|---|
| Home clients (192.168.30.0/24) | pihole01 192.168.30.2 (handed out by gateway01 DHCP) | Upstream per `pihole.toml` — staging snapshot shows 8.8.8.8 / 8.8.4.4 (TBC, re-export the live config) | Ad-blocking for the household |
| Homelab hosts (192.168.10.0/24) | firewall01 192.168.10.1 | 1.1.1.1, 1.0.0.1, 9.9.9.9 (firewall01 dashboard, 16 Oct 2026) | jellyfin01 is the exception: it uses 192.168.30.2 |
| Domain members | dc01 192.168.10.40 | Forwarder (TBC — expected firewall01) | Do not forward `ad.polaris` from firewall01 |
| Cyber guests | `10.10.<vlan>.1` (Unbound on cyber-fw01) | Unbound recursion; zone domains forwarded to Dnsmasq 127.0.0.1:53053 | No `ad.polaris` or parent `cyberrange.home.arpa` forward. Quarantine VLAN 99 has no DNS pass |
| Cyber AD members | cyber-DC01 10.10.20.10 | Forwards to 10.10.20.1 | Same pattern planned for `oscp.lab` via 10.10.81.1 |

## 3. Host records

### 3.1 `polaris.home.arpa`

| Name | Type | Value |
|---|---|---|
| firewall01 | A | 192.168.10.1 |
| proxmox / homelab | A | 192.168.10.2 |
| nas01 | A | 192.168.10.4 |
| docker01 | A | 192.168.10.20 |
| admin01 | A | 192.168.10.30 |
| OPNsense01 | A | 192.168.10.120 |
| git, vault, homepage, status, proxy | A/alias → docker01 | 192.168.10.20 (served by Nginx Proxy Manager) |
| switch01 | A | **Update to 192.168.10.126** (old record points at 192.168.10.3) — MB-001 item |
| cyberrange, ai | A | 192.168.10.119, 192.168.10.124 (`ai` hosts entry proposed in RUN-003 — TBC) |

### 3.2 `ad.polaris`

| Name | Value |
|---|---|
| dc01 | 192.168.10.40 |
| admin-ws | 192.168.10.41 |
| ws01 | 192.168.10.42 |
| ws02 | 192.168.10.43 |
| ca01 | 192.168.10.44 |

### 3.3 Home names (pihole01 / gateway01)

| Name | Value | Notes |
|---|---|---|
| media.internal | 192.168.30.10 | firewall01 WAN; forwarded to jellyfin01 on 80/443/445 |
| media.home.arpa | 192.168.30.10 | Legacy name, still works except on Android |
| gateway01.home.arpa | **should be 192.168.30.1** | Pi-hole still has 192.168.1.1 (staging) |
| pihole01.home.arpa | **should be 192.168.30.2** | Pi-hole still has 192.168.1.2 (staging); Proxmox `/etc/hosts` already has .30.2 |

### 3.4 Cyberrange static names (Unbound Host Overrides)

Static cyber names live in Unbound Host Overrides, **not** Dnsmasq (Dnsmasq's `host-record`/`addn-hosts` did not resolve — RUN-003 §5.3). Examples: `cyber-dmz01` 10.10.70.10, `cyber-corpsrv01` 10.10.71.11, VLAN 80 lab boxes. The full list is in RUN-003 §5.

## 4. Known corrections

1. Update the two stale Pi-hole `hosts` entries (192.168.1.1/.2 → 192.168.30.1/.2).
2. Update `switch01` in `polaris.home.arpa` to 192.168.10.126.
3. Re-export the live `pihole.toml` and confirm the real upstreams.
4. Optional: add `media.internal` as a gateway01 host override to match `media.home.arpa`.

## Revision history

| Version | Date | Summary |
|---|---|---|
| 1–2 | Jul 2026 | `polaris.home.arpa` records and CNAME plan |
| 3.0 | 16 Oct 2026 | Rewrite: all zones and authorities, resolution chains, home/media names, cyberrange and OSCP domains, correction list |
