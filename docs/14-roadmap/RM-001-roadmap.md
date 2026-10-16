# RM-001 — Project Polaris Roadmap

| Field | Value |
|---|---|
| Document ID | RM-001 |
| Version | 7.0 |
| Status | Approved sequence — current state |
| Effective | 16 October 2026 |
| Owner | Jesse Breedlove (Project Polaris) |
| Supersedes | RM-001 v6.2 (21 Aug 2026) and roadmaps v1–v5 (private archive) |

## 1. Principles

1. One bounded gate at a time. Each gate states its purpose, precaution, procedure, expected result, failure action, validation and stop conditions.
2. Back up before any bridge, firewall, identity, storage, GPU or power change.
3. Evidence closes a gate, not intent. Screenshots, command output and hashes are recorded.
4. Fix design debt in documentation as soon as a gate closes.

## 2. Milestone status

| Milestone | Status | Outcome |
|---|---|---|
| M1 Core infrastructure | ✅ Complete (Jul 2026) | Proxmox, storage, Docker services, admin01, nas01, standards |
| M2 AD / PKI | ✅ Complete (13–15 Aug 2026) | dc01, ROOTCA01 + CA01, GPOs, OU/groups, System State backups |
| M3 Architecture reconciliation | ✅ Complete (21 Aug 2026) | ARC-001 v3.2 / REG-001 v6.2 baseline |
| M4 Homelab maintenance before cutover | ✅ Complete | Platform findings resolved before the household change |
| M5–M7 Home-edge cutover and observation | ✅ Complete (4–6 Sep 2026) | gateway01 + pihole01 in production, Decos in AP mode, firewall01 isolated behind gateway01 |
| M7a Starlink cutover | ✅ Complete (Sep 2026) | Starlink Gen 3 straight into the homelab node; NanoStations retired; GS324TP replaces TL-SG608E |
| M8 Cyberrange segmentation | ✅ Complete (Gates 1–9, closed 14 Oct 2026) | VLAN-aware fabric, per-zone policy, fail-closed proven |
| M9 Cyber workload platform | ✅ Core complete (Oct 2026) | Attack, Windows, Linux, Apps, SIEM/BAS, Analysis, Hybrid capstone zones built and monitored |
| M10 Lifecycle operations | 🔁 Recurring | Backups, patching, documentation, auto-revert |
| M11 AI platform (Phases 1–4) | ✅ Complete (7–27 Sep 2026) | GPU Ollama, n8n/Ansible, config-backup automation, Documentation and Coding agents |
| M12 Foreman agent (Phase 5) | 🟡 Active | Foreman, Matrix/Element, Approval Command Architecture done; Networking Manager write scope expanding |
| M13 OSCP practice lab (Gate 10) | 🟡 Active | Phase A infra done; box 1 (VM 384) closed 15 Oct; box 2 (VM 385) in build |
| M14 Home media | ✅ Complete (15 Oct 2026) | jellyfin01 with HTTPS, uploads, SMB and Tailscale remote access |
| M15 Portfolio publication | 🟡 Active | Polaris-Organized + Polaris-GitHub created 16 Oct 2026 |

## 3. Active work, in order

### M13 — OSCP practice lab (GATE-10)

| Phase | Scope | Status |
|---|---|---|
| A | VLAN 80/81 interfaces, DHCP/DNS, firewall policy, CYBER_ATTACK → CYBER_OSCP pass, pivot-only 81, no SIEM | ✅ Done |
| B | Standalones: 384 oscp-linux01 → 385 oscp-win01 → 386 oscp-mix01 | 384 ✅ · 385 🟡 · 386 ⏳ |
| C | AD set: 381 oscp-ext01 (dual-homed foothold) → 382 oscp-ws01 → 383 oscp-dc01 (`oscp.lab`) | ⏳ |
| D | Pivot validation and scorecard (100 points, pass ≥ 70) | ⏳ |
| E | Technique annex 390–399 (BOF, CMS, privesc samplers) | ⏳ |

### M12 — Foreman / Networking agent (Phase 5, step 7b)

1. firewall01 interface assignment layer: `modify`, `delete`, static `create`; check whether `id` is a live array index.
2. gateway01 write scope (aliases, rules, VLANs, interfaces) — **being built**.
3. Proxmox node write scope (interfaces, VLANs) for the AI and homelab nodes.
4. SearXNG self-hosted web search for the Foreman (switch recommendations; no direct switch access).
5. cyber-fw01 stays read-only. Drift tracking already covers all three firewalls.

### M9 follow-ons (cyber range)

1. Arm the 96-hour auto-revert timer.
2. Build the disabled-by-default Atomic Red Team OPNsense rules when atomics are run.
3. Tune defense-AI false positives; build the `ai-analysis` dashboard.
4. Evaluate a no-cost vulnerability scanner (Greenbone/OpenVAS) for VLAN 60.
5. C2 framework (Sliver and/or Covenant) on its own host — explicitly last.

## 4. Recurring lifecycle

| Cadence | Scope |
|---|---|
| Daily (07:00) | Config-backup run: firewalls, switch, Proxmox nodes, Docker, admin hosts, Pi-hole → nas01 |
| Every 96 h | Revert disposable cyber targets to `monitored-baseline` (when armed) |
| Monthly | Package updates, Proxmox updates (pin kernels on the cyberrange node), SMART review, restore test of one backup |
| Per change | Update REG-001 / NET-004 / NET-005 / VIRT-001 in the same change |

## Revision history

| Version | Date | Summary |
|---|---|---|
| 6.0–6.2 | Aug 2026 | Cyberrange segmentation sequence; household milestones on hold |
| 7.0 | 16 Oct 2026 | Rewrite: M4–M9 and M11 closed, Starlink and media milestones added, active OSCP lab and Foreman work sequenced |
