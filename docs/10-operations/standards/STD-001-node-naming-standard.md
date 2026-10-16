# STD-001: Node Naming Standard

Document ID: STD-001

Version: 1.0

Status: Production

Owner: Project Polaris

Last Updated: 2026-07-19

---

# Purpose

This standard defines the naming conventions used throughout Project Polaris.

Consistent naming simplifies administration, troubleshooting, automation, documentation, disaster recovery, and future expansion. Every infrastructure component shall follow this standard unless an approved architectural decision supersedes it.

This document serves as the authoritative naming reference for all current and future Project Polaris infrastructure.

---

# Scope

This standard applies to:

- Physical hardware
- Hypervisors
- Virtual machines
- Network devices
- Firewalls
- Storage
- DNS
- Active Directory
- Documentation
- Backup repositories
- Future cluster expansion

---

# Design Philosophy

Project Polaris uses **purpose-driven naming** rather than hardware-driven naming.

A device's purpose remains recognizable regardless of hardware replacement.

Hardware identifiers are documented separately within the Hardware Inventory.

---

# Naming Principles

All names shall be:

- Short
- Descriptive
- Unique
- Lowercase where supported
- Easy to remember
- Easy to document
- Easy to automate

Avoid:

- Spaces
- Special characters
- Hostnames based on hardware models
- Temporary names
- Personal names

---

# Hardware Naming

Physical hardware is identified by node number.

| Hardware | Name |
|----------|------|
| Primary Infrastructure Host | Node 1 |
| Cyber Range Host | Node 2 |
| Future Expansion Host | Node 3 |
| Additional Hosts | Sequential |

Node numbers identify physical hardware only.

Node numbers never identify virtualization hosts.

---

# Hypervisor Naming

Hypervisors are named according to their operational purpose.

| Hostname | Purpose |
|----------|----------|
| homelab | Trusted Infrastructure |
| cyberrange | Cyber Range Infrastructure |

Future expansion shall continue using purpose-driven names.

Examples:

- ai
- backup
- storage
- automation

Hostnames should never reference hardware generations.

---

# DNS Naming

Fully Qualified Domain Names (FQDNs) follow:

```
hostname.polaris.home.arpa
```

Examples:

```
homelab.polaris.home.arpa

cyberrange.polaris.home.arpa

firewall01.polaris.home.arpa
```

---

# Active Directory Naming

Internal Active Directory domain:

```
polaris.home.arpa
```

NetBIOS:

```
POLARIS
```

---

# Virtual Machine Naming

Virtual machines use descriptive service names.

Examples:

| VM | Purpose |
|----|----------|
| firewall01 | Infrastructure Firewall |
| gateway01 | Home Gateway Firewall |
| docker01 | Docker Services |
| admin01 | Linux Administration |
| dc01 | Active Directory |
| ca01 | Certificate Authority |
| wazuh01 | Security Monitoring |
| monitor01 | Monitoring Platform |
| ansible01 | Automation |
| git01 | Source Control |

Windows workstations:

```
admin-ws

ws01

ws02
```

Future workstations continue sequential numbering.

---

# Firewall Naming

| Host | Purpose |
|-------|----------|
| gateway01 | Home Perimeter Firewall |
| firewall01 | Infrastructure Firewall |
| opnsense01 *(future)* | Cyber Range Security Boundary |

Firewall names identify function rather than software.

---

# Storage Naming

Storage pools use short functional names.

## Node 1

| Pool | Purpose |
|------|----------|
| VM | Primary Infrastructure Storage |
| VM2 | Secondary Infrastructure Storage |

## Node 2

| Pool | Purpose |
|------|----------|
| Cyber_VM | Cyber Range Storage |

NAS shares retain descriptive names.

Examples:

```
Backups

Documentation

Containers

Scripts

Archive

VM-Exports

Shared
```

---

# Network Device Naming

| Device | Name |
|----------|------|
| Home Gateway | gateway01 *(future)* |
| Infrastructure Firewall | firewall01 |
| Cyber Firewall | opnsense01 *(future)* |
| Core Switch | switch01 |
| NAS | nas01 |

Wireless bridge devices:

```
nanostation-ap

nanostation-sta
```

---

# Network Bridge Naming

Proxmox bridges identify their function.

## Node 1

| Bridge | Purpose |
|---------|----------|
| vmbr0 | WAN / Upstream |
| vmbr1 | Internal Transit |
| vmbr2 | Trusted Infrastructure |

## Node 2

Current:

| Bridge | Purpose |
|---------|----------|
| vmbr0 | Trusted Infrastructure |

Future bridges:

| Bridge | Purpose |
|---------|----------|
| vmbr1 | OPNsense Transit |
| vmbr2 | Cyber Range Internal |
| vmbr3 | Optional Isolated Networks |

---

# Documentation Naming

Documentation identifiers use prefixes.

| Prefix | Meaning |
|---------|----------|
| STD | Standard |
| PR | Procedure |
| OPS | Operational Guide |
| HW | Hardware Inventory |
| SA | Storage Architecture |
| ADR | Architecture Decision Record |

Examples:

```
STD-001

PR-001

OPS-002

HW-006
```

---

# Backup Naming

Backups follow consistent naming.

Examples:

```
homelab-config

firewall01-config

dc01-systemstate

docker01-backup

cluster-foundation

pre-cluster-backup
```

Backup filenames should include:

- System
- Backup Type
- Date

Example:

```
homelab-config-20260719.tar.gz
```

---

# Future Expansion

Future infrastructure shall continue these conventions.

Examples:

Infrastructure:

```
backup01

storage01

automation01
```

Cyber Range:

```
kali01

blackarch01

victim01

victim02

siem01
```

---

# Naming Rules

Names should never change unless:

- Purpose changes permanently.
- Hardware is repurposed.
- Approved through architecture review.

Hardware replacement alone shall not require hostname changes.

---

# Validation

Verify:

- Hostnames resolve correctly.
- DNS matches documentation.
- VM names match intended purpose.
- Documentation references remain current.
- Backup names follow the standard.

---

# Lessons Learned

Purpose-driven naming proved significantly more maintainable than hardware-driven naming during Phase F.

The migration from **homelab** to **homelab** demonstrated the importance of establishing permanent naming conventions before cluster formation.

Separating hardware identity (Node 1, Node 2) from operational identity (homelab, cyberrange) simplifies hardware replacement while preserving documentation consistency.

---

# References

PR-001 – Proxmox VE 9 Installation Guide *(Planned)*

PR-002 – Administrative Cluster Build Guide *(Planned)*

STD-002 – Network Architecture & Management Guide *(Planned)*

Project Polaris Hardware Inventory

Project Polaris IP Address Plan

Project Polaris Storage Architecture

---

# Revision History

| Version | Date | Description |
|----------|------|-------------|
| 1.0 | 2026-07-19 | Initial enterprise node naming standard established during Phase F.4. |

