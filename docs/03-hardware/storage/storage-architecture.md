# Project Polaris
# Storage Architecture

**Document ID:** SA-001  
**Version:** 1.2  
**Status:** Production  
**Owner:** Project Polaris  
**Last Updated:** 2026-07-19

---

# Purpose

This document defines the physical and logical storage architecture used throughout Project Polaris.

It serves as the authoritative reference for:

- Physical storage inventory
- Logical storage layout
- Storage ownership
- Storage lifecycle
- Migration planning
- Naming standards
- Future storage expansion

---

# Storage Design Principles

## Enterprise First

- Storage is planned before deployment.
- Every physical disk is inventoried.
- Production storage changes are documented before implementation.
- Storage migrations are planned and validated before execution.
- Backup and restore capability is established before destructive storage changes.

## Resource Efficiency

- Storage devices are assigned roles that maximize useful capacity.
- Dedicated disks are not reserved for narrow purposes when broader shared use is practical.
- Storage placement decisions consider capacity, performance, availability, and operational simplicity.
- Shared repositories are preferred when they reduce duplication and improve access across systems.

## Asset Management

Physical disks are identified by hardware characteristics rather than their current purpose.

Every disk is tracked using:

- Model Number
- Serial Number
- Capacity
- Purpose
- Status
- Physical Location

Purpose may change throughout the life of the project.

Model and Serial Number never change.

---

# Physical Storage Inventory

## Node 1 — pve01

| Model | Serial Number | Capacity | Purpose | Status | Location |
|--------|---------------|---------:|---------|--------|----------|
| Toshiba MQ01ABD100 | SERIAL-REDACTED | 1 TB | Primary Production VM Storage (`VM` ZFS Pool) | Production | Node 1 |
| Toshiba MQ01ABD100 | SERIAL-REDACTED | 1 TB | Proxmox Operating System | Production | Node 1 |
| Samsung HD103UJ | SERIAL-REDACTED | 1 TB | Secondary Production VM Storage (`VM2` ZFS Pool) | Production | Node 1 |
| Toshiba MK6465GSXN | SERIAL-REDACTED | 640 GB | Central ISO Repository (`ISO-Repo`) | Production | DAS |
| Seagate ST2000DM001-1ER164 | SERIAL-REDACTED | 2 TB | WS01 Production System Disk | Production | DAS |
| Toshiba MQ01ABD100V | SERIAL-REDACTED | 1 TB | Available Spare Storage | Available | DAS |

---

## NAS — nas01

| Model | Serial Number | Capacity | Purpose | Status | Location |
|--------|---------------|---------:|---------|--------|----------|
| Seagate IronWolf Pro ST4000VN006-3CW104 | SERIAL-REDACTED | 4 TB | Primary Backup and Shared Storage Repository | Production | NAS Bay 2 |

### Empty Bays

| Bay | Planned Purpose |
|-----|-----------------|
| Bay 1 | Future Expansion |

---

## Cyber Range Host — cyberrange

| Model | Serial Number | Capacity | Purpose | Status | Location |
|--------|---------------|---------:|---------|--------|----------|
| TBD | TBD | 512 GB | Proxmox Operating System | Production | Cyber Range Host |
| Seagate ST4000DM004 | ZW63ZWT6 | 4 TB | Cyber Range Production VM Storage (`Cyber_VM` ZFS Pool) | Production | Cyber Range Host |

---

# Logical Storage Architecture

## Node 1 — pve01

```text
Proxmox OS
        │
        ├── VM
        │   ├── Core Infrastructure VMs
        │   ├── Docker Services
        │   ├── Active Directory
        │   ├── Management Systems
        │   └── Templates
        │
        └── VM2
            ├── Gateway01
            ├── CA01
            ├── Future Infrastructure Expansion
            └── Additional Production VMs
```

---

## ISO Repository

```text
640 GB Toshiba HDD
        │
        ▼
ISO-Repo
        │
        ├── Operating System ISOs
        ├── Hypervisor ISOs
        ├── VirtIO Drivers
        ├── Firmware
        ├── Recovery Media
        └── Utility Images
```

The final location of the shared ISO repository remains under evaluation.

The target architecture must allow simultaneous or practical access from both `pve01` and `cyberrange`.

Candidate locations include:

- Current DAS attachment
- NAS shared repository
- Network-exported storage from a Proxmox node

The final decision will be based on NAS capacity, backup growth, resource efficiency, availability, and administrative simplicity.

---

## NAS Storage

```text
NAS (nas01)
        │
        ├── Backups
        │   ├── Configurations
        │   │   ├── NAS
        │   │   ├── Proxmox
        │   │   ├── pfSense
        │   │   ├── Switch
        │   │   ├── NanoStation
        │   │   └── Gateway01
        │   │
        │   ├── VM-Backups
        │   │   ├── Infrastructure
        │   │   ├── Windows
        │   │   ├── CyberRange
        │   │   └── Templates
        │   │
        │   ├── Docker
        │   │   ├── Compose
        │   │   ├── Volumes
        │   │   └── Databases
        │   │
        │   ├── ActiveDirectory
        │   │   ├── SystemState
        │   │   ├── DNS
        │   │   └── CertificateServices
        │   │
        │   ├── Vaultwarden
        │   ├── Documentation-Exports
        │   └── Restore-Testing
        │
        ├── Documentation
        ├── Shared
        ├── Containers
        ├── VM-Exports
        ├── Scripts
        └── Archive
```

---

## Cyber Range Host

```text
Proxmox OS
        │
        ▼
Cyber_VM
        │
        ├── OPNsense Firewall
        ├── Cyber Range VMs
        ├── Malware Analysis
        ├── Offensive Security Lab
        ├── Defensive Security Lab
        ├── Vulnerable Targets
        ├── Monitoring and SIEM
        └── Isolated Test Networks
```

---

# Backup Storage Architecture

## Proxmox Backup Repositories

| Storage ID | Purpose | Schedule | Retention |
|------------|---------|----------|-----------|
| NAS-Infrastructure | Core infrastructure VM backups | Daily at 01:00 | Keep Last 2 |
| NAS-Windows | Windows infrastructure backups | Daily at 03:00 | Keep Last 2 |
| NAS-Templates | Golden template backups | Weekly Sunday at 05:00 | Keep Last 2 |
| NAS-CyberRange | Future cyber range VM backups | Deferred | Deferred |

Backup retention and automated deletion remain subject to restore validation and future capacity review.

---

# Storage Lifecycle

```text
Hardware Procurement
        │
        ▼
Inventory
        │
        ▼
Assign Purpose
        │
        ▼
Production Deployment
        │
        ▼
Validation
        │
        ▼
Backup Protection
        │
        ▼
Migration or Expansion
        │
        ▼
Retirement
        │
        ▼
Archive or Disposal
```

---

# Completed Storage Migrations

## Migration 1 — WS01 Storage Migration

**Status:** Complete

```text
Original 4 TB WS01 Disk
        │
        ▼
Rescuezilla Clone to 2 TB Disk
        │
        ▼
Boot and Domain Validation
        │
        ▼
Operational Burn-In
        │
        ▼
Release 4 TB Disk for Cyber Range Host
```

Result:

- WS01 runs from the 2 TB Seagate disk.
- Original 4 TB disk was released for the Cyber Range host.
- AD trust, networking, applications, and operating system functionality were preserved.

---

## Migration 2 — Node 1 Storage Expansion

**Status:** Complete

```text
Legacy Samsung 1 TB ZFS Disk
        │
        ▼
Legacy Metadata Removal
        │
        ▼
Create VM2 ZFS Pool
        │
        ▼
Enable AutoTrim
        │
        ▼
Scrub and Functional Validation
```

Result:

- `VM2` provides secondary production VM capacity on `pve01`.
- The primary pool was renamed from `Firewall` to `VM`.

---

## Migration 3 — Cyber Range Storage Deployment

**Status:** Complete

```text
Install 4 TB HDD
        │
        ▼
Remove NTFS and Legacy Metadata
        │
        ▼
Create Cyber_VM ZFS Pool
        │
        ▼
Enable AutoTrim
        │
        ▼
Initial Scrub
        │
        ▼
Register and Validate Proxmox Storage
```

---

# Storage Naming Standards

## ZFS Pools

| Platform | Purpose | ZFS Pool Name |
|----------|---------|---------------|
| pve01 | Primary Production VM Storage | VM |
| pve01 | Secondary Production VM Storage | VM2 |
| cyberrange | Cyber Range Production VM Storage | Cyber_VM |

---

## Proxmox Storage IDs

| Resource | Storage ID |
|----------|------------|
| Node 1 Primary VM Storage | VM |
| Node 1 Secondary VM Storage | VM2 |
| Cyber Range VM Storage | Cyber_VM |
| ISO Repository | ISO-Repo |
| Infrastructure Backups | NAS-Infrastructure |
| Windows Backups | NAS-Windows |
| Template Backups | NAS-Templates |
| Cyber Range Backups | NAS-CyberRange |

---

## NAS Shares

| Share | Purpose |
|-------|---------|
| Backups | Production backup hierarchy |
| Documentation | Controlled system documentation |
| Shared | General production user data |
| Containers | Future Docker data |
| VM-Exports | Virtual machine exports |
| Scripts | Administrative scripts |
| Archive | Long-term storage |

---

# Storage Ownership

| Platform | Primary Purpose |
|----------|-----------------|
| pve01 | Enterprise Infrastructure Services |
| nas01 | Backup and Shared Storage |
| cyberrange | Cyber Range Infrastructure |

---

# Future Expansion

Planned future storage enhancements include:

- Determine the final shared ISO repository location.
- Evaluate NAS capacity after multiple backup cycles.
- Expand NAS capacity using Bay 1.
- Configure Cyber Range backup schedules.
- Validate Linux and Windows restore procedures.
- Measure RTO and RPO.
- Evaluate replication.
- Evaluate cluster-aware storage only when it supports roadmap goals.
- Replace aging disks when health or capacity requires it.

---

# Design Decisions

## Infrastructure and Backup Separation

Production backups are stored independently from virtualization hosts.

This protects backup data from host-level failure and supports disaster recovery.

---

## Cyber Range Separation

Cyber Range VM storage is maintained independently from trusted infrastructure storage.

This minimizes operational risk and supports isolation.

---

## Shared Repository Efficiency

The central ISO and utility repository must be accessible to both Proxmox hosts while avoiding unnecessary duplication or wasted capacity.

Its final placement will be selected after evaluating actual NAS utilization and operational requirements.

---

## Hardware Identity

Hardware is referenced by model number and serial number rather than device names such as `/dev/sda`.

Linux device enumeration may change between boots, but hardware identity remains constant.

---

## Future Cluster Readiness

The storage architecture supports future multi-node operation while avoiding premature complexity.

Clustering, replication, and shared storage will be implemented only when they directly support Project Polaris operational goals.

---

# Revision History

| Version | Date | Description |
|---------|------|-------------|
| 1.0 | 2026-07-16 | Initial enterprise storage architecture baseline established during Milestone 2A Phase D. |
| 1.1 | 2026-07-18 | Added VM2, completed WS01 migration, renamed primary Node 1 pool to VM, and documented NAS backup automation. |
| 1.2 | 2026-07-19 | Added Cyber Range host, Cyber_VM pool, Proxmox backup schedules, shared ISO repository evaluation, and updated production storage inventory. |
