# switch01 — Netgear GS324TP S350

| Item | Value |
|---|---|
| Model | GS324TP S350 Series, 24 × 1 GbE PoE+ (190 W), 2 × SFP |
| Management | 192.168.10.126 on management VLAN 10, gateway 192.168.10.1. **Mask in the export is 255.255.252.0 — correct to /24** (MB-001 NET-101) |
| Interface | Web UI only (no SSH/CLI). Configuration is backed up by a Playwright-driven collector (`09-automation/config-backup/collectors/switch/`) that exports the text configuration |
| Replaced | TP-Link TL-SG608E (old switch01, 192.168.10.3), ≈ 9 Sep 2026 |

## VLANs (VLAN Status page, 16 Oct 2026)

| VLAN | Name | Member ports |
|---|---|---|
| 1 | Default | g9–g22, g25–g26 |
| 10 | Homelab | g3–g6, g23 |
| 30 | Home | g1–g2, g7–g8, g24 |
| 4089 | Auto-Video | — |

All of these are untagged access ports: the home and homelab networks are separated by port. Routing between them happens only through gateway01 and firewall01.

## Lesson learned

On this switch, **VLAN Membership** (which VLAN a port's outgoing untagged frames belong to) and **Port PVID** (which VLAN incoming untagged frames are put into) are independent settings that do not sync. When you move a port, set both. This cost significant debugging time during the cutover (RUN-004 §1).

## Evidence

Text-configuration exports, `show tech-support` output and collector debugging screenshots are kept in the private working set.

## Open

- Record which device is on each port (MB-001 NET-102).
