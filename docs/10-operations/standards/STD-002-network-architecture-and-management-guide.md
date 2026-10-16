# STD-002: Network Architecture & Management Guide

Document ID: STD-002

Version: 1.0

Status: Production

Owner: Project Polaris

Last Updated: 2026-07-19

---

# Purpose

This document defines the enterprise network architecture used throughout Project Polaris.

It serves as the authoritative reference for:

- Network topology
- Trust boundaries
- Routing philosophy
- Management architecture
- Security layering
- Firewall responsibilities
- Administrative access
- Future expansion

This document describes the intended production architecture rather than temporary implementation states.

---

# Scope

Applies to:

- Home network
- Infrastructure network
- Administrative cluster
- Cyber Range
- Remote administration
- Storage connectivity
- Future cluster expansion

---

# Design Philosophy

Project Polaris follows a layered enterprise architecture.

Every security boundary exists to protect the layer above it.

Infrastructure is designed using the principles of:

- Defense in Depth
- Least Privilege
- Administrative Separation
- Purpose-built Segmentation
- Operational Simplicity
- Disaster Recovery

---

# Enterprise Architecture

                    Internet
                        │
                   Gateway01
              (Perimeter Firewall)
                        │
                Household Network
                 Deco Mesh (AP Mode)
                        │
                  Firewall01
        (Infrastructure Security Boundary)
                        │
        ┌───────────────┴────────────────┐
        │                                │
 Trusted Infrastructure            Administrative Cluster
        │                                │
   homelab                     cyberrange
        │                                │
        └───────────────┬────────────────┘
                        │
                  OPNsense01
             (Cyber Security Boundary)
                        │
      ┌─────────────────┼─────────────────┐
      │                 │                 │
 Offensive Lab    Defensive Lab    Malware Lab

---

# Trust Boundaries

Project Polaris is divided into four trust zones.

---

## Zone 1

Internet

Untrusted.

---

## Zone 2

Home Network

Protected by Gateway01.

Contains:

- Family devices
- Wireless clients
- Personal systems

---

## Zone 3

Trusted Infrastructure

Protected by Firewall01.

Contains:

- homelab
- cyberrange
- Active Directory
- Docker
- NAS
- Administration systems

This network is considered trusted.

---

## Zone 4

Cyber Range

Protected by OPNsense.

Contains intentionally vulnerable systems.

Examples:

- Kali
- BlackArch
- Victim VMs
- Malware Analysis
- Security Monitoring

No trust is assumed.

---

# Firewall Responsibilities

## Gateway01

Purpose

Protects the household from the Internet.

Responsibilities

- NAT
- VPN
- IDS/IPS (future)
- Internet security
- DNS forwarding

Gateway01 does not protect the Cyber Range.

---

## Firewall01

Purpose

Protects trusted infrastructure.

Responsibilities

- Infrastructure firewall
- Administrative routing
- NAS access
- Active Directory
- Cluster communication
- Trusted services

Firewall01 always protects the management plane.

---

## OPNsense01

Purpose

Contains cyber range activity.

Responsibilities

- Internal segmentation
- East-west filtering
- Malware containment
- Attack simulation
- Security experimentation

Failure of OPNsense must never prevent administration of the Cyber Range host.

---

# Administrative Philosophy

The administrative cluster is trusted infrastructure.

Both:

- homelab
- cyberrange

remain permanently on the Trusted Infrastructure network.

Only guest workloads exist behind OPNsense.

This ensures administrative recovery remains possible even if OPNsense fails.

---

# Management Network

Management traffic includes:

- Proxmox
- SSH
- Tailscale
- RustDesk
- Cluster communication
- NAS management
- Active Directory administration

Management traffic never traverses Cyber Range security boundaries.

---

# Administrative Cluster

Cluster Name

```
polaris
```

Members

```
homelab

cyberrange
```

Purpose

Unified administration.

Not workload balancing.

Not high availability.

Not shared compute.

---

# Storage Philosophy

Storage remains local.

Infrastructure workloads remain on:

Node 1

Cyber workloads remain on:

Node 2

Shared storage is not required for administrative clustering.

---

# Remote Administration

Supported methods

Priority

1. Local LAN

2. Tailscale

3. RustDesk

Remote administration must remain available independent of Cyber Range health.

---

# Disaster Recovery Philosophy

Recovery order

1.

Gateway

2.

Firewall01

3.

Trusted Infrastructure

4.

Administrative Cluster

5.

NAS

6.

Active Directory

7.

Docker Services

8.

Cyberrange

9.

OPNsense

10.

Cyber Workloads

The Cyber Range is restored last.

---

# Routing Philosophy

Traffic flows downward through security layers.

Internet

↓

Gateway01

↓

Firewall01

↓

Trusted Infrastructure

↓

OPNsense

↓

Cyber Range

Traffic never bypasses a security layer.

---

# Future Expansion

Future additions include:

- Third Proxmox node
- AI infrastructure
- Additional NAS
- Backup server
- Dedicated monitoring
- VLAN segmentation
- Enterprise switching

Future expansion shall preserve trust boundaries defined in this document.

---

# Validation

Verify:

- Firewall responsibilities remain correct.
- Trust boundaries remain intact.
- Administrative recovery remains possible.
- Cluster communication remains on Trusted Infrastructure.
- Cyber workloads remain isolated.

---

# Lessons Learned

Project Polaris originally considered placing the Cyber Range hypervisor behind OPNsense.

Operational testing demonstrated this unnecessarily complicated disaster recovery.

The validated architecture permanently places hypervisors within the Trusted Infrastructure while isolating only Cyber Range guest workloads.

This significantly improves recoverability without reducing security.

Administrative clustering also demonstrated that local ZFS storage provides a simpler operational model than introducing shared storage solely for clustering.

---

# References

STD-001 – Node Naming Standard

SA-001 – Storage Architecture

Project Polaris IP Address Plan

Project Polaris DNS Registry

PR-001 – Proxmox VE Installation Guide (Planned)

OPS-001 – Cluster Administration Guide (Planned)

---

# Revision History

| Version | Date | Description |
|----------|------|-------------|
| 1.0 | 2026-07-19 | Initial enterprise network architecture standard established during Phase F. |
