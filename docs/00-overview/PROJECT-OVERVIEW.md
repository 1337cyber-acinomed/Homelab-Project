# Project Polaris — Current State Overview (16 October 2026)

Project Polaris is a home lab built and run like a small enterprise. It has three Proxmox nodes, three firewalls, an Active Directory domain with a two-tier PKI, a self-hosted AI agent platform that manages the network under human approval, and a segmented cyber range for offensive and defensive security practice.

## The lab in one table

| Domain | What runs there | Key documents |
|---|---|---|
| Edge | Starlink Gen 3 → **gateway01** (pfSense) → household LAN 192.168.30.0/24 with **pihole01** DNS and Deco APs | NET-001, RUN-004 |
| Homelab | **firewall01** (pfSense) → 192.168.10.0/24: Proxmox nodes, nas01, switch01 (GS324TP), docker01, admin01, jellyfin01 | REG-001, NET-005 |
| Identity | **dc01** (`ad.polaris`), Admin-WS, WS01/WS02, **ROOTCA01** (offline root) + **CA01** (issuing) | 05-identity-pki |
| AI node | Ollama on a 16 GB GPU, n8n + Ansible, Matrix/Element, Foreman, Networking Manager, Documentation and Coding agents, merge-broker | AI-000, AI-PH1–5 |
| Automation | Bash config-backup framework for all devices, scheduled by n8n, archived on nas01 | 09-automation |
| Cyber range | **cyber-fw01** (OPNsense) with 12 VLANs: attack, Windows AD, Linux, web apps, SIEM/BAS/defense-AI, analysis, hybrid capstone, OSCP exam lab, quarantine | RUN-003, GATE-10, SOP-BAS |
| Media | **jellyfin01** with HTTPS, uploads, SMB and Tailscale remote access | jellyfin01 reference |

## Hardware

| Node | CPU / RAM | GPU |
|---|---|---|
| homelab | Ryzen 5 5500 / 48 GB | — |
| cyberrange | Ryzen 7 5800X3D / 64 GB | RX 7700 XT 12 GB + GTX 970 4 GB |
| AI | Ryzen 9 7900X / 32 GB DDR5 | RX 9060 XT 16 GB |
| nas01 | Asustor AS1202T, 4 TB | — |

## Where things stand

- **Done:** home-edge cutover, Starlink cutover, switch upgrade, AD/PKI, cyber-range Gates 1–9 (fail-closed proven 14 Oct), SIEM with AI triage, BAS tooling, hybrid capstone, AI Phases 1–4, Foreman with structural approval control, media server.
- **In progress:** OSCP lab (box 2 of 6), Networking agent write scope for gateway01, interface writes on firewall01.
- **Next:** see [RM-001](../14-roadmap/RM-001-roadmap.md) and [MB-001](../10-operations/MB-001-maintenance-backlog.md).

For the full chronology, see [BUILD-TIMELINE](BUILD-TIMELINE.md).
