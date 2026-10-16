# NET-001 — Network Topology

| Field | Value |
|---|---|
| Document ID | NET-001 |
| Version | 1.0 |
| Status | Authoritative — current state |
| Effective | 16 October 2026 |
| Owner | Jesse Breedlove (Project Polaris) |
| Supersedes | `logical-topology.md`, `physical-topology.md`, `network-services.md`, `dependency-mapping.md` (Jul 2026) and the original `Homelab.drawio.png` |

Diagrams are in Mermaid so they render on GitHub and in MkDocs. Addresses come from [REG-001](REG-001-asset-and-network-register.md).

## 1. Physical path

```mermaid
flowchart LR
    SL["Starlink Gen 3 dish"] --> SR["Starlink Gen 3 router<br/>192.168.1.1"]
    SR -- "Ethernet" --> HN["homelab node<br/>Intel 4-port NIC"]
    HN --- SW["switch01<br/>Netgear GS324TP<br/>VLAN 10 Homelab / VLAN 30 Home"]
    SW --- CR["cyberrange node"]
    SW --- AI["AI node"]
    SW --- NAS["nas01<br/>Asustor AS1202T"]
    SW --- DECO["Office Deco (AP mode, mesh main)"]
    DECO -. "wireless backhaul" .- DECO2["Kitchen Deco (mesh satellite)"]
```

- The Ubiquiti NanoStation bridge is **retired**. The Starlink router plugs straight into the homelab node, where gateway01 takes the WAN.
- The kitchen Deco keeps its old cable to the original modem position as an emergency bypass (Starlink router → Deco in router mode).
- switch01 port VLAN membership (VLAN Status page, 16 Oct 2026):

| VLAN | Name | Untagged member ports |
|---|---|---|
| 1 | Default | g9–g22, g25–g26 |
| 10 | Homelab | g3–g6, g23 |
| 30 | Home | g1–g2, g7–g8, g24 |

On this switch **VLAN membership and port PVID are separate settings that do not sync** — set both when moving a port (lesson from the GS324TP build, RUN-004 §1). The per-port device map is not yet recorded (MB-001 item).

## 2. Logical path and trust boundaries

```mermaid
flowchart TB
    INET((Internet)) --> SR["Starlink router<br/>192.168.1.0/24"]
    SR --> GW["gateway01 — pfSense 2.9.0 (VM 107)<br/>WAN 192.168.1.125 · LAN 192.168.30.1"]
    GW --> HOME["Home LAN 192.168.30.0/24<br/>pihole01 .2 · Deco APs · household clients"]
    GW --> FW["firewall01 — pfSense 2.9.0 (VM 101)<br/>WAN 192.168.30.10 · LAN 192.168.10.1 · CYBERMGMT 192.168.20.1"]
    FW --> LAB["Homelab LAN 192.168.10.0/24<br/>Proxmox nodes · nas01 · docker01 · AD/PKI · AI CTs · jellyfin01"]
    FW --> CMG["CYBERMGMT 192.168.20.0/24<br/>emergency path"]
    LAB --> OPN["cyber-fw01 — OPNsense (VM 300)<br/>WAN 192.168.10.120"]
    OPN --> CY["Cyberrange VLANs on cyberrange vmbr1<br/>1, 10, 20, 30, 40, 50, 60, 70, 71, 80, 81, 99"]
    HOME -. "80/443/445 only (port forward)" .-> J["jellyfin01 192.168.10.5"]
```

| Boundary | Enforced by | Rule of thumb |
|---|---|---|
| Internet ↔ home | gateway01 | Double NAT; no inbound forwards from Starlink |
| Home ↔ homelab | firewall01 | Home can reach only jellyfin01 on 80/443/445 via `HOME_NET` → `JELLYFIN01` forward |
| Homelab ↔ cyberrange | cyber-fw01 + cyberrange host design | Cyber guests attach only to `vmbr1`; only cyber-fw01 spans `vmbr0` and `vmbr1`; no guest NAS mounts, second NICs or Tailscale |
| Between cyber zones | cyber-fw01 | Default deny; documented attack-path exceptions only (RUN-003 §7.4) |
| Cyber zones → protected space | cyber-fw01 `PROTECTED_NETWORKS` alias | Blocks 10/8, 172.16/12, 192.168/16, 100.64/10, 169.254/16; public Internet allowed and fails closed if cyber-fw01 is down (Gate 9, 14 Oct 2026) |
| Cyberrange AI ↔ homelab AI | Placement decision | Cyberrange AI runs only on the cyberrange node; it never talks to the AI node |

## 3. Cyberrange segmentation

```mermaid
flowchart LR
    OPN["cyber-fw01"] --- V1["VLAN 1 mgmt<br/>kali01"]
    OPN --- V10["VLAN 10 ATTACK<br/>kali02 · Attack-AI · Parrot01"]
    OPN --- V20["VLAN 20 WINDOWS<br/>cyber-DC01 · WS01 · WS02"]
    OPN --- V30["VLAN 30 LINUX<br/>metasploitable2/3 · ubuntu01/02 · debian01 · alma01"]
    OPN --- V40["VLAN 40 APPS<br/>DVWA · Juice Shop"]
    OPN --- V50["VLAN 50 SIEM<br/>Wazuh · Caldera · Infection Monkey · ART · defense-AI"]
    OPN --- V60["VLAN 60 ANALYSIS<br/>analysisprobe01"]
    OPN --- V70["VLAN 70 HYBRID<br/>cyber-dmz01"]
    OPN --- V71["VLAN 71 HYBRID_INT<br/>cyber-corpsrv01"]
    OPN --- V80["VLAN 80 OSCP<br/>oscp boxes"]
    OPN --- V81["VLAN 81 OSCP_INT<br/>OSCP AD set"]
    OPN --- V99["VLAN 99 QUARANTINE"]
    V10 == "attack-path exceptions" ==> V20 & V30 & V40 & V70 & V80
    V70 -. "dual-homed pivot" .- V71
    V80 -. "dual-homed pivot (VM 381)" .- V81
```

## 4. Remote access

Tailscale gives break-glass access to the Proxmox nodes, the Matrix/Element front end for the AI agents, and remote Jellyfin for family devices. The cyberrange node is peer-isolated by tailnet ACL. Details and IPs: REG-001 §4.

## Revision history

| Version | Date | Summary |
|---|---|---|
| 1.0 | 16 Oct 2026 | First consolidated topology: Starlink edge, gateway01/firewall01 chain, GS324TP VLANs, cyberrange zones including 70/71/80/81 |
