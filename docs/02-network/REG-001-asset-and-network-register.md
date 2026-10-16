# REG-001 — Asset and Network Register

| Field | Value |
|---|---|
| Document ID | REG-001 |
| Version | 7.0 |
| Status | Authoritative — current state |
| Effective | 16 October 2026 |
| Owner | Jesse Breedlove (Project Polaris) |
| Supersedes | REG-001 v6.2 (21 Aug 2026), `ip-address-plan.md`, `IP-Address-Plan.md`, `vlan-plan.md` (kept in the private archive) |
| Sources | Operator answers 16 Oct 2026; pfSense/OPNsense/Proxmox/GS324TP screenshots 16 Oct 2026; RUN-003 v1.77; GATE-10 v0.2; jellyfin01 reference 15 Oct 2026 |

This is the single register of networks, VLANs and addresses. Port numbers live in [NET-005 Port Registry](NET-005-port-registry.md), DNS in [NET-004 DNS Registry](NET-004-dns-registry.md), guests and VMIDs in [VIRT-001](../04-virtualization/VIRT-001-cluster-and-guest-inventory.md), physical hardware in [HW-000](../03-hardware/HW-000-hardware-inventory.md).

**Status values:** *Active* = observed in a screenshot or command output. *Building* = partially built, under an open gate. *Reserved* = allocated, nothing deployed. *Retired* = removed from service. *TBC* = believed correct, not yet re-verified.

---

## 1. Trust zones and Layer-3 networks

| Zone | Network | Gateway / authority | VLAN | Purpose | Status |
|---|---|---|---|---|---|
| Internet edge | 192.168.1.0/24 | Starlink Gen 3 router 192.168.1.1 | — | Starlink router LAN; only client is gateway01 WAN (DHCP 192.168.1.125) | Active |
| Home | 192.168.30.0/24 | gateway01 (pfSense) 192.168.30.1 | Switch VLAN 30 "Home" | Household clients, Deco mesh (AP mode), Pi-hole, firewall01 WAN | Active |
| Homelab (trusted) | 192.168.10.0/24 | firewall01 (pfSense) 192.168.10.1 | Switch VLAN 10 "Homelab" | Proxmox nodes, NAS, switch management, infrastructure VMs, AD/PKI, AI containers | Active |
| CYBERMGMT (emergency) | 192.168.20.0/24 | firewall01 OPT1 192.168.20.1 | — (Proxmox bridge) | Emergency/break-glass management path toward the cyberrange | Active |
| Cyber management | 10.10.1.0/24 | cyber-fw01 (OPNsense) 10.10.1.1 | Native/1 on cyberrange `vmbr1` | Kali01 management workstation | Active |
| Cyber zones | 10.10.10.0/24 – 10.10.99.0/24 | cyber-fw01 10.10.x.1 | 10–99 on cyberrange `vmbr1` | See §2 | Active / Building |
| Tailscale overlay | 100.64.0.0/10 | Tailscale coordination | — | Remote admin and remote media access | Active |

Double NAT (Starlink → gateway01 → firewall01) is deliberate: the household can be bypassed back to the Starlink router quickly if gateway01 fails. IPv6 is disabled and out of scope everywhere.

### 1.1 Home network (192.168.30.0/24)

| Range / address | Assignment | Status |
|---|---|---|
| 192.168.30.1 | gateway01 LAN (VM 107) | Active |
| 192.168.30.2 | pihole01 (CT 108) — DNS for home clients and for lab clients that use it | Active |
| 192.168.30.10 | firewall01 WAN (VM 101) — DHCP static mapping on gateway01 | Active |
| 192.168.30.100–199 | Home DHCP clients (gateway01 DHCP, DNS handed out = 192.168.30.2) | Active |
| 192.168.30.200–254 | Future static home infrastructure | Reserved |

### 1.2 Homelab network (192.168.10.0/24)

| Address | Host | VMID / type | Node | Role | Status |
|---|---|---|---|---|---|
| 192.168.10.1 | firewall01 | VM 101 (pfSense 2.9.0) | homelab | Homelab gateway, DNS authority for `polaris.home.arpa` | Active |
| 192.168.10.2 | homelab | Proxmox node | — | Proxmox node 1 | Active |
| 192.168.10.3 | *(old switch01, TL-SG608E)* | — | — | Retired; address free for reuse | Retired |
| 192.168.10.4 | nas01 | Asustor AS1202T | — | Backups, ISO repo, config archive, cluster QDevice | Active |
| 192.168.10.5 | jellyfin01 | VM 111 | homelab | Home media server (static) | Active |
| 192.168.10.20 | docker01 | VM 103 | homelab | Container services (see NET-005) | Active |
| 192.168.10.30 | admin01 | VM 105 | homelab | Linux admin host; emergency OPNsense WAN HTTPS source | Active |
| 192.168.10.40 | dc01.ad.polaris | VM 200 | homelab | AD DS, AD DNS, GC, all FSMO roles | Active |
| 192.168.10.41 | admin-ws.ad.polaris | VM 201 | homelab | Windows AD/PKI admin workstation | Active |
| 192.168.10.42 | ws01.ad.polaris | VM 202 | homelab | Windows user workstation | Active |
| 192.168.10.43 | ws02.ad.polaris | VM 203 | homelab | Windows user workstation | Active |
| 192.168.10.44 | ca01.ad.polaris | VM 204 | homelab | Enterprise subordinate (issuing) CA | Active |
| 192.168.10.45 | rootca01 | VM 109 | homelab | Offline standalone root CA (powered off except for CRL/issuance ceremonies) | Active (offline) |
| 192.168.10.100–199 | DHCP pool | — | — | firewall01 LAN DHCP | Active |
| 192.168.10.119 | cyberrange | Proxmox node | — | Proxmox node 2 (management only; guests never touch this subnet) | Active |
| 192.168.10.120 | cyber-fw01 WAN | VM 300 (OPNsense) | cyberrange | OPNsense WAN / emergency GUI from admin01 | Active |
| 192.168.10.124 | AI | Proxmox node | — | Proxmox node 3 (AI) | Active |
| 192.168.10.126 | switch01 | Netgear GS324TP | — | Managed switch, management VLAN 10 | Active (see note) |
| 192.168.10.200 | AI-Brain | CT 401 | AI | Ollama + ROCm GPU inference | Active |
| 192.168.10.201 | orchestrator-n8n | CT 402 | AI | n8n, Ansible, Network Change Executor, change ledger | Active |
| 192.168.10.202 | documentation-agent | CT 403 | AI | Documentation agent workspace | Active |
| 192.168.10.203 | coding-agent | CT 404 | AI | Sandboxed coding agent (egress closed by default) | Active |
| 192.168.10.204 | matrix-homeserver | CT 405 | AI | Matrix (conduwuit) homeserver for the Element chat front end | Active |

> **switch01 note:** the GS324TP text-configuration export shows `network parms 192.168.10.126 255.255.252.0 192.168.10.1` — a **/22 mask** on a /24 network. Logged in MB-001 for correction to 255.255.255.0.

### 1.3 CYBERMGMT (192.168.20.0/24)

| Address | Assignment | Status |
|---|---|---|
| 192.168.20.1 | firewall01 OPT1 "CYBERMGMT" | Active |
| Other hosts | Not recorded in current docs | TBC |

---

## 2. Cyberrange VLANs (behind cyber-fw01 / OPNsense, cyberrange node `vmbr1`)

All gateways are `10.10.<vlan>.1`. All DHCP pools are `.100–.199` unless noted. Domain for each zone is `<zone>.cyberrange.home.arpa`.

| VLAN | Subnet | OPNsense interface | Purpose | VMID family | Status |
|---|---|---|---|---|---|
| Native/1 | 10.10.1.0/24 | LAN | Cyber management (kali01 static 10.10.1.85) | 300–309 | Active |
| 10 | 10.10.10.0/24 | CYBER_ATTACK | Attack hosts and attack-AI | 310–319 | Active |
| 20 | 10.10.20.0/24 | CYBER_WINDOWS | Windows AD targets (`corp.cyberrange.local`) | 320–329 | Active |
| 30 | 10.10.30.0/24 | CYBER_LINUX | Linux targets | 330–339 | Active |
| 40 | 10.10.40.0/24 | CYBER_APPS | Vulnerable web apps / APIs | 340–349 | Active |
| 50 | 10.10.50.0/24 | CYBER_SIEM | Wazuh SIEM, BAS tools, defense-AI | 350–359 | Active |
| 60 | 10.10.60.0/24 | CYBER_ANALYSIS | Analyst workstation | 360–369 | Active |
| 70 | 10.10.70.0/24 | CYBER_HYBRID | Hybrid capstone DMZ | 370–379 | Active |
| 71 | 10.10.71.0/24 | CYBER_HYBRID_INTERNAL | Pivot-only internal segment (no CYBER_ATTACK pass) | 370–379 | Active |
| 80 | 10.10.80.0/24 | CYBER_OSCP | OSCP-style exam lab, external segment (no SIEM by design) | 380–389 (annex 390–399) | Building |
| 81 | 10.10.81.0/24 | CYBER_OSCP_INT | OSCP AD set, pivot-only, static addressing, no DHCP pool | 380–389 | Building |
| 99 | 10.10.99.0/24 | CYBER_QUARANTINE | Quarantine — no DNS pass, no Internet, implicit deny | Keep existing VMID | Active (closed) |

### 2.1 Fixed cyberrange addresses

| Address | Host | VMID | Notes |
|---|---|---|---|
| 10.10.1.85 | kali01 | VM 301 | Static; primary OPNsense management |
| 10.10.10.177 | kali02 (`kali-attack`) | VM 310 | DHCP; GTX 970 passed through for hashcat |
| 10.10.10.102 | Attack-AI | CT 311 | DHCP |
| 10.10.10.115 | Parrot01 | VM 312 | DHCP |
| 10.10.20.10 | cyber-DC01 | VM 320 | Static; DNS for `corp.cyberrange.local` |
| 10.10.30.179 / .152 / .105 / .147 / .150 / .141 | metasploitable2 / metasploitable3 / cyber-ubuntu01 / cyber-ubuntu02 / cyber-debian01 / cyber-alma01 | VM 330–335 | DHCP leases observed at build |
| 10.10.40.121 | cyber-apps01 | VM 340 | DHCP (DVWA, Juice Shop) |
| 10.10.50.149 | cyber-siem01 | VM 350 | DHCP static reservation |
| 10.10.50.144 | cyber-defense-ai01 | CT 351 | DHCP static reservation |
| 10.10.60.141 | analysisprobe01 | VM 360 | DHCP static reservation |
| 10.10.70.10 / 10.10.71.10 | cyber-dmz01 | VM 370 | Static, dual-homed |
| 10.10.71.11 | cyber-corpsrv01 | VM 371 | Static, VLAN 71 only |
| 10.10.80.11 | cyber-oscp-linux01 (lab hostname `webdev01`) | VM 384 | Closed 15 Oct 2026 |
| VLAN 80 (TBC) | cyber-oscp-win01 | VM 385 | Being built |

---

## 3. Proxmox bridges

| Node | Bridge | Address | Carries | Notes |
|---|---|---|---|---|
| homelab | vmbr0 | none | Starlink uplink → gateway01 WAN | Raw WAN (TBC: physical port after the Starlink cutover) |
| homelab | vmbr1 | none | CYBERMGMT 192.168.20.0/24 → firewall01 OPT1 | Emergency link |
| homelab | vmbr2 | 192.168.10.2 (host mgmt — TBC bridge) | Homelab LAN → firewall01 LAN | Must stay exclusive to firewall01's protected LAN |
| homelab | vmbr3 | none | Home LAN: gateway01 LAN, pihole01, firewall01 WAN | Bound to `nic1` (the `nic2` port is dead) |
| cyberrange | vmbr0 | 192.168.10.119/24 | Host management + cyber-fw01 WAN | Cyber guests must never attach |
| cyberrange | vmbr1 | none | VLAN-aware cyber fabric (1, 10–81, 99) | Only cyber-fw01 is on both bridges |
| AI | vmbr0 | 192.168.10.124/24 | Host + all AI containers | — |

---

## 4. Remote access overlay (Tailscale)

Tailscale provides break-glass access to the Proxmox nodes, the Matrix/Element front end for the AI agents (`tailscale serve`), ntfy push notifications, and remote Jellyfin for family devices (shared device, grants limited to tcp 80/443/445). The cyberrange node is tagged and peer-isolated by grant policy. Device addresses are omitted from the public copy.

## 5. Retired addressing (for reading old documents)

| Old value | Meaning | Replaced by |
|---|---|---|
| 192.168.68.0/24, 192.168.68.70 | Original ISP router network and old homelab vmbr0 address | Starlink + gateway01 |
| 192.168.0.0/24, 192.168.0.90 | Interim ISP network seen during the Gateway01 cutover | Starlink 192.168.1.0/24 |
| 192.168.68.51 / .55 | Ubiquiti NanoStation bridge endpoints | Retired — Starlink plugs straight into the homelab node |
| 192.168.1.1 / .2 as gateway01 / pihole01 | Pre-cutover staging addresses (still present in the Pi-hole `hosts` list) | 192.168.30.1 / .2 |
| 192.168.10.3 switch01 (TP-Link TL-SG608E) | Original 8-port switch | Netgear GS324TP at 192.168.10.126 |

## Revision history

| Version | Date | Summary |
|---|---|---|
| 6.0 | 16 Aug 2026 | Reconciled address, VM, bridge, storage, DNS, port and backup data |
| 6.1 | 21 Aug 2026 | Added approved cyber VLANs/subnets and runtime-only capacity policy |
| 6.2 | 21 Aug 2026 | Added VLAN-aligned VMID ranges |
| 7.0 | 16 Oct 2026 | Full rewrite: Starlink edge, completed gateway01/Pi-hole cutover, GS324TP switch with VLANs 10/30, AI node and CT 401–405, jellyfin01, VLANs 70/71/80/81, NanoStations retired, Tailscale overlay |
