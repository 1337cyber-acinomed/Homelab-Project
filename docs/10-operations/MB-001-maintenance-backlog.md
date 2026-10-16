# MB-001 — Maintenance Backlog

| Field | Value |
|---|---|
| Document ID | MB-001 |
| Version | 6.0 |
| Status | Active backlog |
| Effective | 16 October 2026 |
| Owner | Jesse Breedlove (Project Polaris) |
| Supersedes | MB-001 v5.1 (21 Aug 2026) and maintenance backlogs v0–v4 (private archive) |
| Sources | MB-001 v5.1, RUN-003 v1.77 §10, AI-PH5 open items, jellyfin01 open items, findings from the 16 Oct 2026 documentation review |

**Priority key:** P0 security/control-plane blocker · P1 high operational risk · P2 hygiene/lifecycle · P3 enhancement.

## 1. Open items

| ID | Pri | Area | Issue | Planned correction |
|---|---|---|---|---|
| SEC-001 | P1 | Proxmox / AI | `root@pam!ansible` API token on CT 402 has full root and no privilege separation; reachable from LLM-triggered playbooks | Create a least-privilege role and token per playbook; exclude the cyberrange node/pool; rotate the old token |
| SEC-002 | P1 | Secrets | A Proxmox API token secret and a short password were written in a personal notes document (private notes file) | Rotate both; keep secrets only in Vaultwarden. The Polaris-Organized copy is redacted |
| SEC-003 | P2 | AI | Foreman webhook is not authenticated at the n8n level | Add a header token check on the Matrix Application Service webhook |
| SEC-004 | P2 | Proxmox | `proxcenter@pve` account: near-Administrator, purpose not recalled | Identify the owner and purpose before disabling (RUN-003 §3.4.1) |
| SEC-005 | P2 | SIEM | Wazuh default credentials (`admin`, `kibanaserver`, `wazuh-wui`) not rotated | Run `wazuh-passwords-tool.sh` on VM 350 |
| SEC-006 | P3 | Cyber AI | Open-WebUI on CT 351 is HTTP on the internal hop; signup still enabled | Set `ENABLE_SIGNUP=false`; optional TLS reverse proxy |
| NET-101 | P1 | Switch | switch01 management mask is 255.255.252.0 (/22) on a /24 network | Correct to 255.255.255.0; re-export config |
| NET-102 | P2 | Switch | Per-port device map for the GS324TP not recorded | Record port → device in NET-001 §1 |
| NET-103 | P2 | DNS | Pi-hole `hosts` still has staging records 192.168.1.1/.2 for gateway01/pihole01 | Change to 192.168.30.1/.2; re-export `pihole.toml` |
| NET-104 | P2 | DNS | `switch01.polaris.home.arpa` still points at 192.168.10.3 | Update to 192.168.10.126 |
| NET-105 | P2 | Edge | Starlink mode not documented (gateway01 WAN gets 192.168.1.125, which means router mode, not bypass) | Confirm and record the intended mode; decide whether to enable bypass |
| NET-106 | P2 | Edge | Migrate gateway01 and firewall01 DHCP from ISC to Kea | Migrate; confirm static mappings (including firewall01 WAN reservation) survive |
| NET-107 | P3 | Edge | Unused `NAS01` alias on firewall01 | Delete |
| NET-108 | P3 | Edge | Unused gateway01 `net2` NIC on `vmbr1` (PFSENSE-GOLD clone leftover) | Remove |
| STO-001 | P1 | Storage | homelab `zfs-import@Firewall.service` failed (carried from v5.1) | Verify whether still failing; do not import nested pfSense pools on the host |
| STO-002 | P2 | Storage | homelab disk → storage (`VM`, `VM2`, `local-lvm`) mapping not recorded; boot device model unknown | Record in HW-000 §2.1 |
| STO-003 | P2 | Media | jellyfin01 4 TB media disk exists in one copy (`backup=0`) | Plan a second copy for irreplaceable media |
| NAS-001 | P2 | Storage | nas01 single 4 TB disk | SMART monitoring; replacement procedure; second disk when possible |
| PVE-002 | P2 | Proxmox | Cyberrange GUI depends on the homelab node being up (carried) | Diagnose separately |
| PVE-003 | P3 | Proxmox | Broken kernel `7.0.14-14-pve` still installed on cyberrange (neutralized by the pin) | Purge the package |
| VM-001 | P2 | Proxmox | VMID 104 `template-backup` purpose unclear (carried) | Review recovery points, then remove or document |
| VM-002 | P3 | PKI | ROOTCA01 VMID 109 → 205 renumber (carried) | Do during the next recurring rebuild |
| LIFE-001 | P1 | Windows | Evaluation licences on ROOTCA01, DC01, CA01 (and cyber Windows hosts) | Recurring rebuild from gold images before expiry |
| CR-101 | P2 | Cyber range | 96-hour auto-revert built and dry-run validated but not armed | `systemctl enable --now cyberrange-autorevert.timer` when ready |
| CR-102 | P2 | Cyber range | Atomic Red Team OPNsense rules documented but not created | Create the five disabled `ART-*` rules on first atomic run |
| CR-103 | P3 | Cyber range | defense-AI over-calls false positives | Add known-FP context to the poller prompt |
| CR-104 | P3 | Cyber range | `ai-analysis` saved dashboard not built | Build severity + recent-analysis dashboard |
| CR-105 | P3 | Cyber range | `rocm-smi` crashes on the RX 7700 XT (cosmetic) | Monitor via `rocminfo`/Ollama logs instead |
| AI-101 | P2 | AI | Interface assignment `modify`/`delete`/static `create` untested; static create does not require `ipaddr`/`subnet` | Build and test; add validation |
| AI-102 | P2 | AI | Check whether alias/rule/interface `id` values are live array indexes (as VLAN ids are) | Test; re-resolve by stable key before apply if so |
| AI-103 | P2 | AI | No monitoring if `matrix-homeserver` goes down | Add an Uptime Kuma check + ntfy alert |
| AI-104 | P3 | AI | Can `gpt-oss:20b` and the coding model share CT 401's GPU without load delays? | Measure |
| AI-105 | P3 | AI | Cleanup: test Matrix account, stale `polaris-foreman` sessions, `/tmp` cert files on CT 405, merge-broker test branches/PRs | Remove |
| AI-106 | P3 | AI | Foreman/Documentation agent cannot accept file uploads in chat; Foreman once re-ran the coding agent instead of asking the documentation agent to move a file | Add file transfer; tighten routing |
| DOC-101 | P2 | Docs | RUN-003 Appendix A (new-chat prompt) is stale | Refresh |
| DOC-102 | P3 | Docs | ws01/ws02 and Admin-WS power-state policy not documented | Record which Windows hosts are always-on |

## 2. Closed since v5.1

| ID (v5.1) | Closed | Evidence |
|---|---|---|
| CR-BKP-001 Kali01 recovery gap | 21 Aug 2026 | RUN-002 Gate 2 |
| CR-BKP-002 OPNsense recovery | 22 Sep 2026 | Post-correction XML hash recorded (RUN-003 §9) |
| CR-HOST-001 Host bridge checkpoint | Aug 2026 | Gate 4 archive |
| CR-NET-001 `vmbr1` VLAN-aware | Aug 2026 | Gate 5 |
| CR-NET-002 Cyber zones | 28 Aug 2026 → Oct 2026 | Gate 6 + VLANs 70/71/80/81 |
| CR-FW-001 Default-deny policy | Sep 2026 | PROTECTED_NETWORKS + per-zone template |
| CR-DNS-001 Per-zone DHCP/DNS | 1 Sep 2026 | Gates 7.2–7.3 |
| CR-VAL-001 Isolation matrix | 14 Oct 2026 | Gate 9 fail-closed PASS |
| NET-001/002/004, CUT-001 (household cutover holds) | 6 Sep 2026 | RUN-004 Gateway01 cutover closed; NanoStations retired with Starlink |
| PVE-001 Homelab updates/reboot | Before Sep 2026 cutover | Homelab on PVE 9.2.20 |
| CR-OPS-001 24 GiB runtime ceiling | 26 Sep 2026 | Superseded by the 64 GB hardware upgrade |
| Tailscale peer isolation (RUN-003) | 22 Sep 2026 | Implemented and verified with live traffic |
| GTX 970 role | 13 Oct 2026 | vfio passthrough to Kali02, hashcat 11.6 GH/s |
| Wazuh API down after VM 350 reboot | 14 Oct 2026 | Start-order race fixed |

## Revision history

| Version | Date | Summary |
|---|---|---|
| 5.0–5.1 | Aug 2026 | Cyberrange pre-change protection and household holds |
| 6.0 | 16 Oct 2026 | Rewrite: closed segmentation/cutover items; added security, switch, DNS, AI-agent and cyber-range follow-ons |
