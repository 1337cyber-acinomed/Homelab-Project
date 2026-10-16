# VIRT-001 — Proxmox Cluster and Guest Inventory

| Field | Value |
|---|---|
| Document ID | VIRT-001 |
| Version | 1.0 |
| Status | Authoritative — current state |
| Effective | 16 October 2026 |
| Owner | Jesse Breedlove (Project Polaris) |
| Supersedes | `VM-structure.md`, VM sections of REG-001 v6.2 |
| Evidence | Proxmox Server View screenshots (16 Oct 2026), operator VMID list, RUN-003 v1.77 §4, AI runbooks Phases 1–5 |

## 1. Cluster

| Item | Value |
|---|---|
| Datacenter / cluster | `polaris` |
| Nodes | `homelab` (192.168.10.2), `cyberrange` (192.168.10.119), `AI` (192.168.10.124) |
| Quorum | 3 nodes + nas01 as QDevice (`corosync-qnetd` container, implemented 20 Jul 2026) |
| Version | Proxmox VE 9.2.20, kernel `7.0.14-19-pve` |
| Independence rule | Each node is its own build. The only intended ties are cluster/QDevice membership, the host-level NAS backup mounts and Tailscale break-glass. Anything else is unwanted reach (RUN-003 §10). |

## 2. VMID convention

| Range | Node | Use |
|---|---|---|
| 100–199 | homelab | Edge, infrastructure, templates, media |
| 200–209 | homelab | Windows / AD / PKI (`ad.polaris`) |
| 300–399 | cyberrange | VLAN-aligned: the tens digit is the VLAN (310–319 = VLAN 10, 320–329 = VLAN 20 …); 380–389 OSCP core, 390–399 OSCP annex |
| 400–499 | AI | AI and automation containers |

## 3. homelab node

| VMID | Name | Type | Role | Address |
|---|---|---|---|---|
| 100 | PFSENSE-GOLD | Template | pfSense golden image | — |
| 101 | Firewall01 | VM | Homelab firewall (pfSense 2.9.0) | WAN 192.168.30.10 · LAN 192.168.10.1 · OPT1 192.168.20.1 |
| 102 | tmpl-ubuntu-26.04-v1.0 | Template | Golden Ubuntu 26.04 image (ADR-003) | — |
| 103 | Docker01 | VM | Container host (NPM, Vaultwarden, Homepage, Uptime Kuma, Forgejo, Portainer, MkDocs) | 192.168.10.20 |
| 104 | template-backup | VM | Template backup copy | — |
| 105 | Admin01 | VM | Linux admin host; emergency OPNsense WAN HTTPS source | 192.168.10.30 |
| 106 | DC01-Gold | Template | DC01 golden image | — |
| 107 | gateway01 | VM | Home-edge firewall (pfSense 2.9.0, UEFI) | WAN 192.168.1.125 · LAN 192.168.30.1 |
| 108 | pihole01 | CT | Home DNS / ad-blocking | 192.168.30.2 |
| 109 | ROOTCA01 | VM | Offline standalone root CA (kept powered off) | 192.168.10.45 |
| 110 | ROOTCA01-GOLD | Template | ROOTCA01 rebuild template | — |
| 111 | jellyfin01 | VM | Media server: Jellyfin, File Browser, Caddy, Samba, Tailscale (Debian 13) | 192.168.10.5 |
| 200 | DC01 | VM | AD DS / DNS / GC / FSMO for `ad.polaris` | 192.168.10.40 |
| 201 | Admin-WS | VM | Windows AD/PKI admin workstation | 192.168.10.41 |
| 202 | WS01 | VM | Windows workstation | 192.168.10.42 |
| 203 | WS02 | VM | Windows workstation | 192.168.10.43 |
| 204 | CA01 | VM | Enterprise subordinate issuing CA | 192.168.10.44 |

## 4. AI node

| VMID | Name | Type | Resources | Role |
|---|---|---|---|---|
| 401 | AI-Brain | CT (privileged, Ubuntu 26.04) | 8 cores, 16 GB, 1 TB, GPU RX 9060 XT | Ollama + ROCm; models `gpt-oss:20b` (primary), `qwen3:14b` (backup), `qwen3-vl:8b` (vision) |
| 402 | orchestrator-n8n | CT (privileged, Ubuntu 26.04) | 2 cores, 4 GB | n8n (Docker) + Ansible; Foreman, Networking Manager, Network Change Executor, change ledger `/opt/networking-agent/`, backup schedule, ntfy |
| 403 | documentation-agent | CT | 2 GB, 16 GB | Documentation agent workspace (Forgejo docs, MkDocs) |
| 404 | coding-agent | CT (unprivileged) | 2 cores, 4 GB, 32 GB | Sandboxed coding agent; `ws-*` dispatch scripts; Internet egress closed by default |
| 405 | matrix-homeserver | CT | — | conduwuit Matrix homeserver for the Element front end; Application Service webhook into n8n |

## 5. cyberrange node

| VMID | Name | Type | Zone | Notes |
|---|---|---|---|---|
| 300 | cyber-fw01 | VM | WAN + trunk | OPNsense 26.7.x; only guest on both `vmbr0` and `vmbr1` |
| 301 | kali01 | VM | VLAN 1 | Management workstation, 10.10.1.85 |
| 310 | Kali02 | VM | VLAN 10 | Primary attack host (Kali 2026.2); GTX 970 passthrough |
| 311 | Attack-AI | CT (Ubuntu 24.04) | VLAN 10 | 8 vCPU / 8 GiB / 200 GB; Ollama on RX 7700 XT; Open-WebUI tool bridge to Kali02 |
| 312 | Parrot01 | VM | VLAN 10 | Parrot Security 7.3 |
| 320 | cyber-DC01 | VM | VLAN 20 | `corp.cyberrange.local` DC, 10.10.20.10 |
| 321 | cyber-WS01 | VM | VLAN 20 | Windows 11 Pro, domain-joined |
| 322 | cyber-WS02 | VM | VLAN 20 | Windows 10, domain-joined |
| 330 | metasploitable2 | VM | VLAN 30 | Vulnerable by design |
| 331 | metasploitable3 | VM | VLAN 30 | Vulnerable by design |
| 332 | cyber-ubuntu01 | VM | VLAN 30 | Hardened general-purpose target |
| 333 | cyber-ubuntu02 | VM | VLAN 30 | Hardened + injected privesc |
| 334 | cyber-debian01 | VM | VLAN 30 | Jenkins + GitLab CE |
| 335 | cyber-alma01 | VM | VLAN 30 | Samba lateral-movement pivot |
| 340 | cyber-apps01 | VM | VLAN 40 | DVWA + Juice Shop (Docker) |
| 350 | cyber-siem01 | VM | VLAN 50 | Wazuh SIEM + Caldera + Infection Monkey + ART; 6 cores / 16 GiB / 120 GiB |
| 351 | cyber-defense-ai01 | CT | VLAN 50 | `deepseek-r1:14b` + `llama-guard3:8b`, Open-WebUI, Wazuh → AI triage pipeline |
| 360 | analysisprobe01 | VM | VLAN 60 | Ubuntu Desktop 26.04 analyst workstation |
| 370 | cyber-dmz01 | VM | VLAN 70 + 71 | Dual-homed DMZ web host / pivot |
| 371 | cyber-corpsrv01 | VM | VLAN 71 | Windows Server 2022, domain-joined |
| 384 | cyber-oscp-linux01 | VM | VLAN 80 | OSCP box 1 (Debian 12), closed 15 Oct 2026 |
| 385 | cyber-oscp-win01 | VM | VLAN 80 | OSCP box 2, being built |
| 381–383, 386 | oscp-ext01, oscp-ws01, oscp-dc01, oscp-mix01 | Planned | 80/81 | Remaining OSCP exam core (GATE-10) |

**Protection model.** Cyber guests get local snapshots only (`hardened-baseline`, `monitored-baseline`, `oscp-baseline`); no cyber guest is backed up to nas01. cyber-fw01's config is protected by OPNsense XML exports kept off-box. Disposable targets (330–335, 340, 370, …) are reverted every 96 hours by `cyberrange-autorevert.timer` on the host (built and dry-run validated 13 Oct 2026; arm when ready).

## Revision history

| Version | Date | Summary |
|---|---|---|
| 1.0 | 16 Oct 2026 | First consolidated cluster and guest inventory for all three nodes |
