# Build Timeline — 28 June to 16 October 2026

Dates come from document headers, git history, gate records and runbook logs. "≈" marks a date inferred from surrounding evidence.

## Phase 0 — Firewall-first foundation (late June – early July)

| Date | Milestone |
|---|---|
| 28 Jun | Project starts: plan to put a virtual pfSense between the Deco mesh and the lab on a single Proxmox host with an Intel 4-port NIC and a TP-Link TL-SG608E. |
| ≈ 29 Jun – 2 Jul | First pfSense VM's package database corrupts; it is rebuilt cleanly as VM 101 (firewall01) and the config restored. The PFSENSE-GOLD template follows. |
| 3 Jul | `homelab-infrastructure` git repo created in Forgejo; v1.1 baseline committed. |
| 4 Jul | Storage domain services; milestone-2 repo structure; inventory records; identity domain foundation; **Vaultwarden** deployed with temporary internal TLS; Homepage and port registry. |
| 5 Jul | Maintenance backlog; Disaster Recovery Kit; incident: suspended ZFS pool with stale VM references. |
| 6 Jul | storage01 backup validated; recovery SOPs; **Windows Active Directory architecture** designed. |
| 10 Jul | Incident: pfSense vs Proxmox firewall conflict. |
| 15–16 Jul | Hardware inventory v1.0 baseline; nas01 configuration backup; roadmap and architecture revision. |
| 20 Jul | **Proxmox QDevice** on nas01 (custom arm64 `corosync-qnetd` container). |
| 25 Jul | Incident: Proxmox unreachable after the WAN migration. |
| ≈ late Jul | Second node (`cyberrange`) joins the cluster; cyber-fw01 (OPNsense) and Kali01 are built. |

## Phase 1 — Identity, PKI and architecture baseline (August)

| Date | Milestone |
|---|---|
| 13 Aug | **RB-010 closed**: offline ROOTCA01 recovered and implemented; CA01 issuing CA. |
| 15 Aug | **Active Directory milestone closed**: dc01, GPOs, OU/group model, System State backups to nas01. |
| 16–21 Aug | ARC-001 v3.0–3.2, REG-001 v6.0–6.2, RM-001 v6.x, MB-001 v5.x reconcile the whole lab; VLAN-aligned VMIDs adopted. |
| 21 Aug | Cyberrange RUN-002 Gate 2: Kali01 recovery point validated. |
| 28 Aug | Gate 6: cyber VLANs 10/20/30/40/50/60/99 created on OPNsense. |
| 29 Aug – 3 Sep | Gates 7.x: per-zone DHCP, DNS (Unbound + Dnsmasq), isolation, quarantine closed. |

## Phase 2 — Home edge, Starlink and the switch (September)

| Date | Milestone |
|---|---|
| 4–6 Sep | **gateway01 home-edge cutover** completed: gateway01 + pihole01 on new `vmbr3` / 192.168.30.0/24; firewall01 WAN moved behind gateway01; Decos to AP mode. |
| ≈ 9 Sep | **Netgear GS324TP** replaces the TL-SG608E (Playwright switch collector verified the same day). |
| ≈ Sep | **Starlink Gen 3** replaces the ISP connection. The Ubiquiti NanoStation bridge is retired and the Starlink router is cabled straight into the homelab node. |
| 3–9 Sep | Cyber Gates 8A–8E: VM360 analysis probe built offline; trunk corrected; policy validated. |

## Phase 3 — AI node and automation (September)

| Date | Milestone |
|---|---|
| 7 Sep | **AI Phase 1**: third node `AI` (Ryzen 9 7900X, RX 9060 XT); CT 401 GPU-accelerated Ollama via ROCm. |
| 8 Sep | **AI Phase 2**: CT 402 n8n + Ansible; chat → AI agent → Ansible → Proxmox API proven. |
| 9 Sep | config-backup framework committed to git (Phase 3 begins). |
| 11–12 Sep | Ansible + n8n orchestration; gateway01 and pihole01 collectors; n8n becomes the sole scheduler (`0 7 * * *`). |
| 13 Sep | Retention guard (never delete last copy); SSH multiplexing; Forgejo self-merge findings. |
| 14 Sep | **Merge-broker** proven ("AI proposes, human commits"); AI node backup orchestrator. |
| 16–17 Sep | Cyberrange node collector and orchestrator (API-only). |
| 17–27 Sep | **AI Phase 4**: documentation agent (CT 403), MkDocs site, Matrix homeserver plan, coding agent (CT 404) with a real execution sandbox (27 Sep). |
| 22 Sep | Cyber Gate 8G1 closed: PROTECTED_NETWORKS typo fix, host management-plane audit, Tailscale peer isolation. Cyberrange AI is confined to the cyberrange node. |
| 23 Sep | VM310 rebuilt from BlackArch to Kali02. |
| 26 Sep | **Cyberrange hardware upgrade** (5800X3D, X570 Taichi, 64 GB, RX 7700 XT + GTX 970). Gate 8G2 closed: Attack-AI GPU inference, Parrot01. |
| 27 Sep | **AI Phase 5** planning: Foreman agent, Matrix + Element. |

## Phase 4 — Full cyber range and the Foreman (October)

| Date | Milestone |
|---|---|
| 1 Oct | cyber-DC01 hardening and AD content population closed. |
| 2 Oct | Foreman build steps 1–6 complete (coding agent, merge-broker status, documentation agent). Linux zone VM330–333 built. |
| 3 Oct | VM334/335 (Jenkins/GitLab, Samba pivot); first attack-path exception (ATTACK → LINUX). |
| 4 Oct | Apps zone (DVWA, Juice Shop); VLAN 70/71 hybrid infrastructure; ATTACK → WINDOWS/APPS/HYBRID exceptions. |
| 5 Oct | VM370 cyber-dmz01 web layer closed. |
| 6 Oct | Networking Manager built; firewall01 write pipeline proven. |
| 7 Oct | **Approval Command Architecture**: AI approval removed; `/approve <id>` only. VM371 closure summary. GTX 970 freed. |
| 8 Oct | **SIEM core closed** (Wazuh on VM350). Firewall rules write capability closed. |
| 9 Oct | Alias create/delete closed. SOP-BAS scenarios (Caldera, Infection Monkey, ART). |
| 10 Oct | VLAN write workflow (live-index bug found and fixed). auditd + Sysmon on all monitored targets; `monitored-baseline` snapshots. |
| 11 Oct | **defense-AI** CT 351: deepseek-r1 + llama-guard3, Wazuh → AI triage pipeline. |
| 13 Oct | GTX 970 → Kali02 hashcat (11.6 GH/s); 96 h auto-revert built; Attack-AI agentic tool bridge; Wazuh Docker listener. |
| 14 Oct | **Gate 9 PASS — the cyber range fails closed.** Core build arc (Gates 1–9) complete. RUN-003 v1.77. |
| 15 Oct | **jellyfin01** media server with Tailscale remote access. **GATE-10 OSCP lab**: VLAN 80/81 Phase A; box 1 `oscp-linux01` closed. |
| 16 Oct | `oscp-win01` (VM 385) in build. gateway01 agent write scope in progress. Documentation reorganized into Polaris-Organized and Polaris-GitHub. |
