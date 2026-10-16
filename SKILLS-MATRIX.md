# Skills Matrix — Evidence by Target Role

Roles are listed in order of preference. Each skill links to the place in this repo where it can be seen.

## 1. Penetration Tester

| Skill | Evidence |
|---|---|
| Attack-lab design (AD, Linux, web, pivoting) | [Cyber range chapter](docs/00-build-story/04-cyber-range.md), [RUN-003 §4, §11](docs/07-cyberrange/RUN-003-cyberrange-current-state-handoff.md) |
| OSCP methodology (enumeration, web exploitation, privesc, AD attacks, tunnelling) | [GATE-10 OSCP lab](docs/07-cyberrange/GATE-10-oscp-practice-lab-vlan80.md) |
| Pivot scenarios (dual-homed foothold, chisel, pivot-only segments) | VLAN 70/71 and 80/81 design in [ARC-001 §5](docs/01-architecture/ARC-001-northstar-architecture.md) |
| Deliberate vulnerability injection on hardened hosts | RUN-003 §11.3 (Linux zone builds) |
| GPU password cracking (hashcat via vfio passthrough, 11.6 GH/s NTLM) | [Hardware inventory](docs/03-hardware/HW-000-hardware-inventory.md), RUN-003 §10 |
| Kali, Parrot, LLM-assisted tooling | [VIRT-001](docs/04-virtualization/VIRT-001-cluster-and-guest-inventory.md) |

## 2. SOC / Cybersecurity Analyst

| Skill | Evidence |
|---|---|
| SIEM deployment and tuning (Wazuh) | [Detection engineering chapter](docs/00-build-story/05-detection-engineering.md) |
| Endpoint telemetry (Sysmon, auditd) and detection validation | Same; [SOP-BAS](docs/07-cyberrange/SOP-BAS-breach-and-attack-simulation-scenarios.md) |
| Adversary emulation (Caldera, Infection Monkey, Atomic Red Team), MITRE ATT&CK | SOP-BAS |
| AI-assisted alert triage with guardrails | [AI-000 §4](docs/08-ai-platform/AI-000-ai-platform-overview.md), RUN-003 §11.3.1k |
| Security standards and governance | [SEC-001…007](docs/13-security/), [GOV-001…009](docs/10-operations/governance/) |
| Incident response and root-cause analysis | [SOP-011](docs/10-operations/sops/SOP-011-incident-response.md), [troubleshooting write-ups](docs/12-troubleshooting/) |

## 3. Network Engineer / NOC

| Skill | Evidence |
|---|---|
| Multi-firewall design (2 × pfSense, OPNsense), NAT, aliases, port forwards | [Network chapter](docs/00-build-story/02-network-edge-and-switching.md), [NET-001](docs/02-network/NET-001-network-topology.md) |
| VLANs (managed switch, VLAN-aware Linux bridges, 802.1Q trunk to OPNsense) | [switch01](docs/02-network/switch/switch01-gs324tp.md), [REG-001](docs/02-network/REG-001-asset-and-network-register.md) |
| DNS (pfSense resolver, Pi-hole, AD DNS, Unbound + Dnsmasq) | [NET-004](docs/02-network/NET-004-dns-registry.md) |
| IP address management, port registry | [REG-001](docs/02-network/REG-001-asset-and-network-register.md), [NET-005](docs/02-network/NET-005-port-registry.md) |
| Planned cutovers with rollback | [RUN-004 gateway01 cutover](docs/02-network/firewalls/RUN-004-gateway01-home-edge-cutover-runbook.md) |
| Troubleshooting (routing, DHCP, source-address selection, NIC offload) | [TS-006](docs/12-troubleshooting/TS-006-2026-07-10-pfsense-proxmox-firewall-conflict.md), [TS-007](docs/12-troubleshooting/TS-007-2026-07-25-proxmox-unreachable-after-wan-migration.md), [NIC offload notes](docs/02-network/firewalls/nic-offload-features-explained.md) |
| Firewall API automation (pfSense REST API v2) | [Privilege mapping](docs/02-network/firewalls/pfsense-rest-api-privilege-mapping.md), [AI-PH5](docs/08-ai-platform/runbooks/AI-PH5-foreman-agent.md) |
| Zero-trust remote access (Tailscale grants, tags, peer isolation) | [Cyber range chapter](docs/00-build-story/04-cyber-range.md) |

## 4. DevOps / Automation

| Skill | Evidence |
|---|---|
| Bash framework engineering | [code/config-backup](code/config-backup/), [automation chapter](docs/00-build-story/06-automation-config-backup.md) |
| Ansible, n8n, scheduled orchestration | `code/config-backup/orchestration/` |
| Git workflow, branch protection, review gates (Forgejo merge-broker) | [AI-PH3 runbook](docs/09-automation/AI-PH3-nas01-config-backup-automation-runbook.md) |
| Docker Compose services, reverse proxy | [code/docker-compose](code/docker-compose/) |
| Python and Playwright web automation | [switch-export.py](code/config-backup/collectors/switch/switch-export.py) |
| LLM agent orchestration with structural safety | [AI agent chapter](docs/00-build-story/07-ai-agent-platform.md) |
| Sandboxed CI-style code execution | [code/coding-agent-workspace](code/coding-agent-workspace/) |

## 5. Systems Administrator

| Skill | Evidence |
|---|---|
| Proxmox VE clustering, QDevice, ZFS, LXC, templates | [VIRT-001](docs/04-virtualization/VIRT-001-cluster-and-guest-inventory.md), [Proxmox install guide](docs/04-virtualization/proxmox-installation-guide.md) |
| Active Directory, GPO, ADCS two-tier PKI | [Identity chapter](docs/00-build-story/03-identity-and-pki.md) |
| Backup, DR and recovery runbooks | [11-recovery](docs/11-recovery/), [GOV-001](docs/10-operations/governance/GOV-001-backup-policy.md) |
| SOPs and change management | [10-operations/sops](docs/10-operations/sops/), [GOV-004](docs/10-operations/governance/GOV-004-change-governance.md) |
| Linux hardening | [Guest hardening steps](docs/07-cyberrange/linux-guest-hardening-and-validation-steps.md), [SEC-004](docs/13-security/SEC-004-system-hardening-standards.md) |

## 6. Computer Hardware

| Skill | Evidence |
|---|---|
| Platform builds and upgrades (AM4 and AM5, DDR4 and DDR5, multi-GPU) | [HW-000](docs/03-hardware/HW-000-hardware-inventory.md) |
| GPU compute (ROCm on RDNA3/RDNA4), PCIe passthrough, IOMMU, BIOS constraints | [AI-PH1](docs/08-ai-platform/runbooks/AI-PH1-gpu-ollama-ai-host.md), RUN-003 §3.3 |
| Storage (ZFS, LVM-thin, NAS, disk swap procedure) | [Storage architecture](docs/03-hardware/storage/storage-architecture.md), [SOP-014](docs/10-operations/sops/SOP-014-das-swap-procedure.md) |
| NIC and port diagnosis (dead port isolation) | [RUN-004 §1](docs/02-network/firewalls/RUN-004-gateway01-home-edge-cutover-runbook.md) |
