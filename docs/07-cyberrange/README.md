# 07 — Cyber Range

The cyber range runs on the `cyberrange` Proxmox node behind its own OPNsense firewall (cyber-fw01, VM 300). It is used for offensive practice (manual and AI-assisted), defensive detection engineering, and OSCP-style exam preparation.

## Documents in this folder

| Document | Use |
|---|---|
| [RUN-003 — Current State and Continuation Handoff](RUN-003-cyberrange-current-state-handoff.md) | **Master record** (v1.77, 14 Oct 2026). Architecture, every VM, firewall policy, gates 1–9, validation commands, open items |
| [RUN-002 — Segmentation Runbook](RUN-002-cyberrange-segmentation-runbook.md) | Original gated segmentation procedure (v1.23). RUN-003 supersedes it where they conflict |
| [GATE-10 — OSCP Practice Lab](GATE-10-oscp-practice-lab-vlan80.md) | VLAN 80/81 exam lab design, box roster, flag/scoring model, build-access SOP |
| [SOP-BAS — Breach and Attack Simulation Scenarios](SOP-BAS-breach-and-attack-simulation-scenarios.md) | How to run Caldera, Infection Monkey and Atomic Red Team against monitored zones |
| [Linux guest hardening and validation steps](linux-guest-hardening-and-validation-steps.md) | Per-guest hardening and isolation checks |
| `build-records/` | Gate summaries, VM371 closure, Aug 2026 capacity snapshot |

## At a glance (16 Oct 2026)

| Zone | Hosts | Purpose |
|---|---|---|
| VLAN 10 Attack | Kali02 (GTX 970 hashcat), Parrot01, Attack-AI (Ollama + Open-WebUI driving Kali02 tools over a scoped SSH bridge) | Offense |
| VLAN 20 Windows | cyber-DC01, WS01 (Win 11), WS02 (Win 10) — `corp.cyberrange.local` | AD attacks |
| VLAN 30 Linux | metasploitable2/3, ubuntu01/02, debian01 (Jenkins + GitLab), alma01 (Samba pivot) | Linux exploitation and privesc |
| VLAN 40 Apps | DVWA, Juice Shop | Web exploitation |
| VLAN 50 SIEM | Wazuh (agents + auditd + Sysmon), Caldera, Infection Monkey, Atomic Red Team, defense-AI triage (`deepseek-r1:14b`) | Detection and response |
| VLAN 60 Analysis | analysisprobe01 | Analyst desktop (Wazuh dashboard, Open-WebUI) |
| VLAN 70/71 Hybrid | cyber-dmz01 → chisel pivot → cyber-corpsrv01 | Capstone: web foothold → internal Windows |
| VLAN 80/81 OSCP | oscp-linux01 (done), oscp-win01 (building), four more planned | Exam simulation, no SIEM |
| VLAN 99 Quarantine | — | Containment |

Key results: inter-zone default deny with documented attack paths; `PROTECTED_NETWORKS` block; **fail-closed proven 14 Oct 2026 (Gate 9)**; monitored targets carry `monitored-baseline` snapshots and revert every 96 hours.
