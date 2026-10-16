# The Build Story — Project Polaris, June to October 2026

This is the start-to-finish account of how the lab was built: what I set out to do, what broke, how I diagnosed it, and the decisions I made. Each chapter ends with the skills it demonstrates and links to the detailed engineering records.

| # | Chapter | Period | Focus |
|---|---|---|---|
| 1 | [Foundation: firewall-first Proxmox](01-foundation.md) | Late Jun – Jul | Virtualized pfSense, storage, Docker services, git-backed docs, clustering and QDevice |
| 2 | [Network: home edge, Starlink and switching](02-network-edge-and-switching.md) | Aug – Sep | gateway01 cutover, Pi-hole, Starlink, GS324TP VLANs, double-NAT bypass design |
| 3 | [Identity and PKI](03-identity-and-pki.md) | Jul – Aug | AD forest, OU/GPO baseline, offline root CA + issuing CA |
| 4 | [Building the cyber range](04-cyber-range.md) | Aug – Oct | OPNsense segmentation, 12 VLANs, attack paths, pivot-only zones, fail-closed test |
| 5 | [Detection engineering and adversary emulation](05-detection-engineering.md) | Oct | Wazuh + Sysmon/auditd, Caldera, Infection Monkey, Atomic Red Team, AI triage |
| 6 | [Automation: the config-backup framework](06-automation-config-backup.md) | Sep | Bash framework, manifests, quarantine, retention, n8n/Ansible, merge-broker |
| 7 | [The AI agent platform](07-ai-agent-platform.md) | Sep – Oct | Local LLMs, n8n agents, Matrix, sandboxed coding agent, structural approval control |
| 8 | [OSCP lab and home media](08-oscp-lab-and-media.md) | Oct | Exam-style lab design, Jellyfin with Tailscale remote access |
| 9 | [Lessons learned](09-lessons-learned.md) | — | What I'd tell the next person |

A dated, day-by-day table is in [BUILD-TIMELINE](../00-overview/BUILD-TIMELINE.md).

## How I worked

- **Gated changes.** Every infrastructure change is a "bounded gate": purpose, precaution, exact procedure, expected result, failure action, validation and stop conditions. A gate that finds a misconfiguration does not fix it on the spot; the fix becomes its own approved step.
- **Back up first.** Snapshot or export before any bridge, firewall, identity, storage or GPU change.
- **Evidence over assumption.** Gates close on screenshots, command output and SHA-256 hashes, not on "it should work".
- **Documentation as code.** Everything lives in Forgejo. Architecture decisions are ADRs, and the register, roadmap and backlog are updated whenever a gate closes.
- **AI as a pair engineer, not an authority.** I used ChatGPT and Claude heavily for research, design review and drafting. I ran every command myself and validated the result (see [AI-assisted engineering](../15-ai-assisted-engineering/README.md)).
