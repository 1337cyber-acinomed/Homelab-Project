# ARC-001 — Northstar Architecture Baseline

| Field | Value |
|---|---|
| Document ID | ARC-001 |
| Version | 4.0 |
| Status | Approved baseline — current state |
| Effective | 16 October 2026 |
| Owner | Jesse Breedlove (Project Polaris) |
| Supersedes | ARC-001 v3.2 (21 Aug 2026) and earlier Northstar/baseline documents (private archive) |
| Companion records | [REG-001](../02-network/REG-001-asset-and-network-register.md) · [NET-001](../02-network/NET-001-network-topology.md) · [HW-000](../03-hardware/HW-000-hardware-inventory.md) · [VIRT-001](../04-virtualization/VIRT-001-cluster-and-guest-inventory.md) · [RUN-003](../07-cyberrange/RUN-003-cyberrange-current-state-handoff.md) · [AI-000](../08-ai-platform/AI-000-ai-platform-overview.md) |

## 1. Executive statement

Project Polaris is a three-node Proxmox cluster with a separate Asustor NAS for quorum and recovery, built to run as an enterprise environment would. It is split into four trust domains — **household**, **trusted homelab**, **AI/automation** and an **isolated cyber range** — each with its own firewall authority. Starlink provides Internet access through a home-edge pfSense (gateway01), a second pfSense (firewall01) protects the homelab, and an OPNsense firewall (cyber-fw01) contains the cyber range. Every infrastructure change is gated, backed up first and validated with evidence.

## 2. Classification of statements

| Classification | Meaning | Change rule |
|---|---|---|
| Observed current state | Verified by command output, screenshots or closed gate evidence | Describe as fact |
| Approved target | Accepted end state not yet built | Build only through an approved bounded gate |
| Planned correction | Known deviation | Back up first; validate; keep rollback |
| Accepted constraint | Deliberate risk or exception | Record and review; never silently normalize |

## 3. Physical and logical architecture

| Layer | Observed current state |
|---|---|
| Internet | Starlink Gen 3 router → Ethernet into the homelab node → gateway01 WAN (192.168.1.125). NanoStation bridge retired. |
| Home edge | gateway01 (pfSense 2.9.0, VM 107) routes 192.168.30.0/24; pihole01 (CT 108) at 192.168.30.2 serves household DNS; Decos run in AP mode. Cutover closed 6 Sep 2026. |
| Homelab | firewall01 (pfSense 2.9.0, VM 101) WAN 192.168.30.10 → LAN 192.168.10.0/24 and CYBERMGMT 192.168.20.0/24. |
| Switching | Netgear GS324TP with VLAN 10 (Homelab) and VLAN 30 (Home) as port-based VLANs; management 192.168.10.126. |
| Compute | `homelab` (infrastructure, firewalls, AD/PKI, media), `cyberrange` (cyber range), `AI` (agents) in cluster `polaris`, plus nas01 QDevice. |
| Cyber range | cyber-fw01 (OPNsense, VM 300) WAN 192.168.10.120; VLAN-aware `vmbr1` trunk carrying VLANs 1, 10, 20, 30, 40, 50, 60, 70, 71, 80, 81, 99. |
| Remote access | Tailscale for break-glass admin, the Matrix/Element agent front end and remote Jellyfin. |

The household path is deliberately double-NATed so it can be bypassed to the Starlink router quickly if gateway01 fails. IPv6 is out of scope and disabled.

## 4. Trust boundaries and authorities

| Boundary | Authority | Protected scope | Approved administration |
|---|---|---|---|
| Home edge | gateway01 / pfSense | Household clients, Deco mesh, Pi-hole | Admin hosts; AI Networking agent (gateway01 write scope in progress) |
| Homelab | firewall01 / pfSense | 192.168.10.0/24, `polaris.home.arpa`, CYBERMGMT | admin01, admin-ws; AI Networking Manager via `/approve` only |
| Cyber management | cyber-fw01 / OPNsense | VLAN 1, 10.10.1.0/24 | kali01 primary; admin01 emergency HTTPS to 192.168.10.120; AI agents read-only |
| Cyber workloads | cyber-fw01 / OPNsense | VLANs 10–99 | Documented scenario flows only |
| Directory | dc01 | `ad.polaris` | admin-ws |
| PKI | ROOTCA01 (offline) + CA01 (issuing) | Internal certificates | admin-ws / PKI groups |
| AI change control | n8n Network Change Executor | Live firewall writes | Human `/approve <id>` in Matrix — AI cannot approve |

## 5. Cyber-range design

| VLAN | Subnet | Zone | Use |
|---|---|---|---|
| 1 | 10.10.1.0/24 | Management | kali01 |
| 10 | 10.10.10.0/24 | Attack | Kali02, Parrot01, Attack-AI |
| 20 | 10.10.20.0/24 | Windows | `corp.cyberrange.local` forest |
| 30 | 10.10.30.0/24 | Linux | Six Linux targets |
| 40 | 10.10.40.0/24 | Apps/APIs | DVWA, Juice Shop |
| 50 | 10.10.50.0/24 | SIEM | Wazuh, Caldera, Infection Monkey, Atomic Red Team, defense-AI |
| 60 | 10.10.60.0/24 | Analysis | Analyst workstation |
| 70 / 71 | 10.10.70.0/24, 10.10.71.0/24 | Hybrid capstone | DMZ host + pivot-only internal Windows server |
| 80 / 81 | 10.10.80.0/24, 10.10.81.0/24 | OSCP exam lab | Six-box exam core, pivot-only AD set, no SIEM |
| 99 | 10.10.99.0/24 | Quarantine | No DNS, no Internet |

**Policy (observed, Gate 9 passed 14 Oct 2026):**

- Each active zone uses the same 4-rule template: block the OPNsense control plane, allow DNS/DHCP to `.1`, block `PROTECTED_NETWORKS` (10/8, 172.16/12, 192.168/16, 100.64/10, 169.254/16), allow Internet egress.
- Inter-zone traffic is denied by default. The only exceptions are documented attack paths from CYBER_ATTACK to VLANs 20, 30, 40, 70 and 80, plus scoped SIEM agent passes. VLANs 71 and 81 have no attack pass at all; they are reached only by pivoting through a dual-homed host.
- Internet fails closed when cyber-fw01 is down. No guest has a second NIC, a `vmbr0` attachment, a NAS mount or Tailscale.
- The cyber-range AI (Attack-AI CT 311, defense-AI CT 351) runs only on the cyberrange node and shares the RX 7700 XT. It never talks to the homelab AI node.
- Cyber guests are protected by local snapshots only. Only cyber-fw01's XML configuration leaves the node.

## 6. AI and automation design

| Component | Design decision |
|---|---|
| Inference | Ollama on CT 401 (RX 9060 XT 16 GB, ROCm). LXC rather than VM to avoid the consumer-AMD VFIO reset bug. |
| Orchestration | n8n + Ansible on CT 402; sub-agents are n8n workflows called through "Call n8n Workflow Tool" (no MCP). |
| Chat front end | Self-hosted Matrix (conduwuit, CT 405) + Element; Application Service webhook into n8n; ntfy push. |
| Agents | Foreman (router), Networking Manager (writes), per-firewall Query agents (reads), Documentation agent (CT 403), Coding agent (CT 404 sandbox), merge-broker. |
| Safety | No reasoning agent holds merge, push-to-main or device-write credentials, or any path that can trigger them. Approvals are a deterministic `/approve <id>` command handled outside the AI. Every write is ledgered. |
| Config backup | Bash collector framework (`config-backup`) on the homelab node (`/opt/project-polaris/config-backup`), triggered daily by n8n through Ansible, archived to nas01 with manifests and retention. |

## 7. Identity, PKI and services

- dc01 is the only domain controller, DNS server, global catalog and FSMO holder for `ad.polaris` (RB-010 closed 13 Aug 2026; AD milestone closed 15 Aug 2026).
- ROOTCA01 is an offline standalone root; CA01 is the enterprise issuing CA.
- docker01 hosts Nginx Proxy Manager, Vaultwarden, Homepage, Uptime Kuma, Forgejo, Portainer and the MkDocs site.
- jellyfin01 serves household media through a single firewall01 port forward (80/443/445) and remotely through Tailscale.

## 8. Accepted constraints and open deviations

| ID | Item | Disposition |
|---|---|---|
| ARC-C01 | Single domain controller | Accepted; compensated with System State backups, gold image (VM 106) and rebuild procedure |
| ARC-C02 | nas01 single 4 TB disk | Accepted; SMART monitoring and replacement procedure |
| ARC-C03 | Cross-tier admin account and 12-character / no-expiry passwords | Approved personal-lab exception |
| ARC-C04 | Cyberrange AI guests are LXC (shared kernel) | Accepted for GPU sharing; escape lands on the cyberrange host, which is hardened and peer-isolated |
| ARC-C05 | Cyberrange host management IP on the trusted subnet | Accepted; host management plane audited and hardened (Gate 8G1 step 6) |
| ARC-C06 | jellyfin01 media disk has a single copy | Accepted; second copy of irreplaceable media planned |
| ARC-D01 | `root@pam` API token used by Ansible (CT 402) has full root, no privilege separation | Open — replace with a scoped token (MB-001) |
| ARC-D02 | switch01 management mask is /22 | Open — correct to /24 (MB-001) |
| ARC-D03 | Pi-hole staging host records (192.168.1.x) still present | Open — correct (MB-001) |
| ARC-D04 | homelab `zfs-import@Firewall.service` failed | Carried from v3.2; verify (MB-001) |

Closed since v3.2: home-edge cutover (was ARC-D01), `vmbr1` VLAN-aware (ARC-D02), Kali01 recovery point (ARC-D03).

## Revision history

| Version | Date | Summary |
|---|---|---|
| 3.0 | 16 Aug 2026 | Reconciled home-edge, cluster, AD/PKI, storage and management facts |
| 3.1 | 21 Aug 2026 | Seven-zone cyber segmentation, capacity policy, cutover hold |
| 3.2 | 21 Aug 2026 | VLAN-aligned VMID ranges |
| 4.0 | 16 Oct 2026 | Rewrite to current state: Starlink edge, completed cutover, three-node cluster, AI/agent architecture, VLANs 70/71/80/81, Gate 9 fail-closed result, updated constraints |
