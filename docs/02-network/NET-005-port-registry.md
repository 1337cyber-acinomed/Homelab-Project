# NET-005 — Port Registry

| Field | Value |
|---|---|
| Document ID | NET-005 |
| Version | 4.0 |
| Status | Authoritative — current state |
| Effective | 16 October 2026 |
| Owner | Jesse Breedlove (Project Polaris) |
| Supersedes | `PORT-REGISTRY.md`, `PORT-REGISTRY-v2.md`, `port-registry(1).md` (NET-006 v3) |

Every listening service that matters for firewall rules, monitoring or troubleshooting. Addresses are in [REG-001](REG-001-asset-and-network-register.md). "Exposure" says who is allowed to reach the port, not just where it listens.

**Exposure key:** *LAN* = homelab 192.168.10.0/24 · *Home* = 192.168.30.0/24 · *Admin* = admin01 / admin-ws / operator laptop only · *Zone* = inside one cyber VLAN · *Loopback* = 127.0.0.1 only · *TS* = Tailscale only.

## 1. Edge and firewalls

| Host | Port/proto | Service | Exposure | Notes |
|---|---|---|---|---|
| gateway01 192.168.30.1 | 443/tcp | pfSense web GUI + REST API v2 | Admin | Read/write by the AI Networking agent (gateway01 write scope in progress) |
| gateway01 | 53/tcp+udp, 67/udp | DNS resolver, DHCP (home) | Home | DHCP hands out DNS 192.168.30.2 |
| firewall01 192.168.10.1 | 443/tcp | pfSense web GUI + REST API v2 | Admin | Write access only through the Network Change Executor |
| firewall01 | 53/tcp+udp, 67/udp | DNS resolver (authoritative `polaris.home.arpa`), DHCP | LAN | — |
| firewall01 WAN 192.168.30.10 | 80, 443, 445/tcp | Port forward → jellyfin01 | Home (`HOME_NET` alias) | Only inbound path from home to lab |
| cyber-fw01 192.168.10.120 (WAN) | 443/tcp | OPNsense GUI | admin01 only | Emergency path |
| cyber-fw01 10.10.1.1 (LAN) | 443/tcp | OPNsense GUI + API | kali01 | Primary management path; API read-only for the AI agents |
| cyber-fw01 10.10.x.1 | 53/tcp+udp | Unbound (client-facing DNS) | Zone | All other control-plane ports blocked from zones |
| cyber-fw01 | 53053/tcp+udp | Dnsmasq (DHCP-registered names) | Loopback | Unbound forwards zone domains here |
| cyber-fw01 10.10.x.1 | 67/udp | Dnsmasq DHCP | Zone | No DHCP on VLAN 81 |

## 2. Proxmox cluster, storage and switching

| Host | Port/proto | Service | Exposure | Notes |
|---|---|---|---|---|
| homelab .2, cyberrange .119, AI .124 | 8006/tcp | Proxmox web GUI / API | LAN, TS | Collectors use least-privilege API tokens |
| Proxmox nodes | 22/tcp | SSH | Admin, TS | — |
| Proxmox nodes | 5405–5412/udp | Corosync cluster traffic | LAN (nodes only) | Cluster `polaris` |
| nas01 192.168.10.4 | 5403/tcp | corosync-qnetd (QDevice) container | Proxmox nodes | Custom arm64 image, see `04-virtualization/qdevice/` |
| nas01 | 8000/tcp, 8001/tcp | ADM web UI (HTTP/HTTPS) | Admin | — |
| nas01 | 139, 445/tcp | SMB shares (backups, ISO repo, configs) | Proxmox nodes, dc01 | Never reachable from cyber guests |
| switch01 192.168.10.126 | 80/tcp | GS324TP web UI | Admin | Config collector drives this UI with Playwright (no CLI/SSH on this model) |

## 3. Homelab services

| Host | Port/proto | Service | Exposure | Notes |
|---|---|---|---|---|
| docker01 192.168.10.20 | 80, 443/tcp | Nginx Proxy Manager (proxy) | LAN | Internal TLS from the AD PKI |
| docker01 | 81/tcp | NPM admin UI | Admin | — |
| docker01 | 3000/tcp | Homepage dashboard | LAN | — |
| docker01 | 3001/tcp | Forgejo HTTP | LAN | Git server for all Polaris repos |
| docker01 | 2222/tcp | Forgejo SSH | LAN | Deploy keys for collectors and agents |
| docker01 | 3002/tcp | Uptime Kuma | LAN | Container port 3001 |
| docker01 | 3003/tcp | Vaultwarden | LAN (via NPM) | Container port 80 |
| docker01 | 8000, 9443/tcp | Portainer (edge, HTTPS UI) | Admin | — |
| docker01 | TBC | MkDocs documentation site | LAN | Auto-rebuilds on push; port not recorded |
| jellyfin01 192.168.10.5 | 80, 443/tcp | Caddy (Jellyfin + File Browser at `/uploads`) | Home (via forward), LAN, TS | HTTPS from Caddy's internal CA; Tailscale cert on `ts.net` name |
| jellyfin01 | 445/tcp | Samba read-only `Media` share | Home, LAN, TS | — |
| jellyfin01 | 8096/tcp | Jellyfin (direct) | TS, LAN | Normally reached through Caddy |
| jellyfin01 | 22/tcp | SSH | LAN only (`ListenAddress 192.168.10.5`) | Not reachable over Tailscale |
| pihole01 192.168.30.2 | 53/tcp+udp | DNS | Home, LAN | Upstreams in `pihole.toml` snapshot are 8.8.8.8/8.8.4.4 (staging — TBC) |
| pihole01 | 80, 443/tcp | Pi-hole admin | Admin | — |
| pihole01 | 123/udp | NTP (FTL) | Home | Enabled in config |

## 4. Identity and PKI (ad.polaris)

| Host | Port/proto | Service | Exposure | Notes |
|---|---|---|---|---|
| dc01 192.168.10.40 | 53 | AD-integrated DNS (`ad.polaris`) | LAN | — |
| dc01 | 88, 464 | Kerberos | LAN | — |
| dc01 | 135, 49152–65535/tcp | RPC endpoint mapper + dynamic RPC | LAN | — |
| dc01 | 389/tcp+udp, 3268/tcp | LDAP, Global Catalog | LAN | — |
| dc01 | 636, 3269/tcp | LDAPS, GC over TLS | LAN | Planned |
| dc01 | 445/tcp | SMB (SYSVOL/NETLOGON) | LAN | — |
| ca01 192.168.10.44 | 80/tcp | AIA / CRL distribution | LAN | TBC |
| admin-ws 192.168.10.41 | 22/tcp | OpenSSH (backup collector) | admin01 | SSH multiplexing used by the collector |
| Windows hosts | 3389/tcp | RDP | Admin | Restricted |
| Windows hosts | 5985/5986/tcp | WinRM | Admin | Planned |

## 5. AI node (192.168.10.200–204)

| Host | Port/proto | Service | Exposure | Notes |
|---|---|---|---|---|
| CT 401 AI-Brain .200 | 11434/tcp | Ollama API (`gpt-oss:20b`, `qwen3:14b`, `qwen3-vl:8b`) | CT 402–404 | GPU: RX 9060 XT 16 GB |
| CT 402 orchestrator-n8n .201 | 5678/tcp | n8n (Foreman, Networking Manager, Coding/Documentation agents, backup scheduler) | LAN | — |
| CT 402 | TBC/tcp | ntfy push service | TS (bound to 100.64.0.12) | Phone notifications |
| CT 403 documentation-agent .202 | 22/tcp | SSH workspace (called by n8n) | CT 402 | — |
| CT 404 coding-agent .203 | 22/tcp | SSH sandbox (`ws-*` dispatch) | CT 402 | Outbound Internet closed except during approved windows |
| CT 405 matrix-homeserver .204 | 8008/tcp | Matrix client-server API (conduwuit) | LAN | Bound directly on the LAN |
| CT 405 | 443/tcp | `tailscale serve` TLS front for Element | TS | — |

## 6. Cyberrange workloads

| Host | Port/proto | Service | Exposure | Notes |
|---|---|---|---|---|
| cyber-siem01 10.10.50.149 | 443/tcp | Wazuh dashboard | VLAN 60 (analyst) | — |
| cyber-siem01 | 1514, 1515/tcp | Wazuh agent events / enrollment | Monitored zones (Gate 8H scoped passes) | No agents in VLAN 80/81 by design |
| cyber-siem01 | 55000/tcp | Wazuh API | Zone | — |
| cyber-siem01 | 9200/tcp | Wazuh indexer | VM351 | Indexer binds 0.0.0.0 for the AI pipeline |
| cyber-siem01 | 8888/tcp | MITRE Caldera | Targets via disabled-by-default `BAS-CALDERA-*` rules | Enabled only while a scenario runs |
| cyber-siem01 | 5000/tcp | Infection Monkey island | Targets during scenarios | — |
| cyber-siem01 | 4200/tcp | ATT&CK Navigator | Loopback | Viewed on-box only |
| cyber-defense-ai01 10.10.50.144 | 8080/tcp | Open-WebUI | VM360 only | HTTP on an internal hop — accepted risk |
| cyber-defense-ai01 | 11434/tcp | Ollama (`deepseek-r1:14b`, `llama-guard3:8b`) | Loopback | Shares RX 7700 XT |
| Attack-AI 10.10.10.102 | 11434/tcp, 8080/tcp (TBC) | Ollama + Open-WebUI (agentic tool bridge to kali02) | VLAN 10 | Scoped SSH to kali02 as `aiagent` |
| cyber-apps01 10.10.40.121 | 80/tcp | DVWA | CYBER_ATTACK | Intentionally vulnerable |
| cyber-apps01 | 3000/tcp | OWASP Juice Shop | CYBER_ATTACK | Intentionally vulnerable |
| cyber-dmz01 10.10.70.10 | 80, 8080/tcp | nginx/Docker web stack (Meridian site, decoy WordPress, SQLi app) | CYBER_ATTACK | Pivot host into VLAN 71 (chisel) |
| cyber-corpsrv01 10.10.71.11 | 5985/tcp | WinRM | VLAN 71 only | Reachable only through VM370 |
| ART targets | 5985/tcp (Windows), 22/tcp (Linux) | Atomic Red Team execution from VM350 | Pre-built, disabled `ART-*` OPNsense rules | Created when atomics run |

## Revision history

| Version | Date | Summary |
|---|---|---|
| 1–2 | Jul 2026 | Docker01 and NAS ports only |
| 3 | Jul 2026 | NET-006 generic core-service table |
| 4.0 | 16 Oct 2026 | Full rewrite: firewalls, cluster/QDevice, switch, jellyfin01, Pi-hole, AD, AI node, cyberrange SIEM/BAS/AI and targets |
