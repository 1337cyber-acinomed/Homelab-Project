# Chapter 8 — OSCP Practice Lab and Home Media (October 2026)

## OSCP-style exam lab (Gate 10)

**Goal:** a self-contained network that mirrors the structure of the OSCP exam. That means an Active Directory set plus three standalone machines, 100 points with a pass mark of 70, and `local.txt`/`proof.txt` flags, built so I can practise the full PEN-200 technique range.

| Design choice | Why |
|---|---|
| New **VLAN 80** (external) and **VLAN 81** (internal, pivot-only) | VLAN 81 has no attack pass. It can only be reached by compromising the dual-homed foothold (VM 381) and tunnelling, which is the exam's pivot mechanic |
| **No SIEM** on these zones | Pure offence practice; a deliberate, documented deviation |
| Separate AD forest `oscp.lab` | Isolated from the range's main `corp.cyberrange.local` forest |
| Manual reset only (no 96-hour auto-revert) | So a half-finished attempt is never wiped |
| Temporary build access from the management VM | One scoped rule per box, removed and verified **before** the `oscp-baseline` snapshot |

| Box | Role | Status |
|---|---|---|
| 384 `oscp-linux01` | Web → Linux privesc | ✅ Closed 15 Oct |
| 385 `oscp-win01` | Service exploit → Windows privesc | 🟡 Building |
| 386 `oscp-mix01` | Find, fix and compile a public exploit (the one box where Metasploit is allowed) | Planned |
| 381–383 | AD foothold → workstation → DC (DCSync / pass-the-hash) | Planned |
| 390–399 | Technique annex (BOF, CMS, privesc samplers) | Planned |

[GATE-10 design and build log](../07-cyberrange/GATE-10-oscp-practice-lab-vlan80.md) (flags redacted).

## Home media server (jellyfin01)

A Jellyfin server for the household, built 15 Oct 2026, that also shows how to expose **one** lab service to the home network safely:

- **One port forward** on firewall01, from the home LAN only, to ports 80/443/445. It rewrites the destination only, so the server sees each client's real address. Nothing else on the lab side is reachable from home.
- **Caddy** for HTTPS, using its internal CA on the LAN and a publicly trusted Tailscale certificate remotely. **File Browser** handles uploads (create, no delete), and **Samba** offers a read-only share.
- **Tailscale** remote access: the server is shared to each family member's device, and grants limit them to the media ports only. SSH listens on the LAN address only.
- The 4 TB media disk is excluded from VM backups by design (documented as an accepted single-copy risk).

[jellyfin01 reference](../06-services/media/jellyfin01-media-server-reference.md)

## Skills demonstrated

Offensive lab design mapped to an exam syllabus, AD attack-path design, pivoting and tunnelling scenarios, scoped and time-boxed firewall exceptions; securely publishing a service (reverse proxy, TLS, NAT, zero-trust remote access), Linux service administration.
