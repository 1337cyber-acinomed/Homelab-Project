# Project Polaris
# Backup & Disaster Recovery Policy

**Document ID:** GOV-001

**Version:** 1.0 (Draft)

**Status:** Review

**Owner:** Project Polaris

**Last Updated:** 2026-07-22

---

# Purpose

This policy establishes the backup, retention, validation, and disaster recovery standards for Project Polaris.

The objective of this policy is to maximize recoverability while respecting the current hardware and storage limitations of the environment. Backup requirements are intentionally risk-based rather than uniform across all systems.

Project Polaris is an enterprise-inspired homelab intended for education, infrastructure engineering, cybersecurity, and operational experience. As such, the backup strategy balances enterprise best practices with practical resource management.

---

# Guiding Principles

Project Polaris follows these backup principles:

- Recoverability is more important than redundancy.
- **Configuration and documentation are the most valuable recovery assets. Operating systems and virtual machines can be rebuilt; documented configurations preserve operational state and significantly reduce recovery time.**
- Automation should be used whenever practical.
- Backup frequency should reflect rebuild cost and operational importance.
- Backups should not unnecessarily interfere with normal lab operation.
- Policies shall evolve alongside the infrastructure.

---

# Recovery Objectives

## Recovery Point Objective (RPO)

**24 Hours**

Critical infrastructure should never be more than one day behind the current operational state.

---

## Recovery Time Objective (RTO)

**1–4 Hours**

Core infrastructure should be recoverable within several hours using documented procedures.

---

# Backup Classification

## Tier 1 — Critical Infrastructure

These systems protect the operation of the environment itself and therefore receive the highest backup priority.

### Protected Systems

- Gateway01 (Future)
- Firewall01
- Cyber-FW01

### Backup Frequency

Daily

### Retention

Maintain the **two most recent backups**.

### Purpose

These systems contain firewall policies, routing configuration, VPN configuration, and network security rules that would require significant manual effort to recreate.

---

## Tier 2 — Enterprise Infrastructure

These systems contain configuration that is difficult or time-consuming to recreate.

### Protected Systems

- DC01
- CA01

### Backup Frequency

Monthly

### Retention

Maintain the **two most recent backups**.

### Purpose

Although these servers can be rebuilt from the approved golden templates, Windows Server Evaluation licensing expires after approximately 180 days. Monthly backups primarily protect the operational configuration and significantly reduce rebuild time.

---

## Tier 3 — Production Infrastructure

These systems provide enterprise services but can be rebuilt with relatively little effort.

### Protected Systems

- Docker01
- Admin01
- Future Enterprise Service VMs

### Backup Frequency

Monthly

### Retention

Maintain **one current backup**.

### Purpose

These virtual machines typically consume significantly more storage while remaining relatively straightforward to rebuild using documented procedures and configuration repositories.

---

## Tier 4 — Disposable Learning Systems

Learning environments are intentionally considered disposable.

### Examples

- Offensive Security VMs
- Defensive Lab VMs
- Research Systems
- Malware Analysis Systems
- Temporary Test Machines

### Backup Frequency

As Needed

### Retention

Administrator Discretion

### Purpose

These systems are designed to be rebuilt as part of normal learning activities and generally do not require scheduled backups.

---

# Configuration Backup Policy

Configuration backups are independent of virtual machine backups and shall be maintained as operational recovery artifacts.

Configuration backups preserve the operational state of critical infrastructure and are considered Tier 1 recovery assets due to their importance in rapidly restoring services.

Configuration backups are intended to protect the configuration of infrastructure components rather than the operating systems or virtual machines themselves.

---

## Protected Configurations

The following configurations shall be protected:

- Proxmox Host Configuration
- Proxmox Cluster Configuration
- pfSense Configurations
- OPNsense Configurations
- TP-Link Switch Configuration
- Ubiquiti NanoStation Configuration
- NAS01 Configuration

---

## Configuration Backup Triggers

Configuration backups shall be created:

- Immediately following the initial deployment of a new infrastructure component.
- Prior to operating system updates.
- Prior to firmware updates.
- Prior to hardware replacement or migration.
- Prior to significant configuration changes.
- Immediately following successful validation of major configuration changes.
- Prior to disaster recovery exercises.
- Following completion of infrastructure rebuilds.

These triggers ensure that every major infrastructure change has both a known-good configuration before the change and a validated recovery point after successful implementation.

---

Configuration backups shall be performed in accordance with SOP-002 Configuration Backups.

---

## Configuration Backup Validation

Configuration backups shall be periodically validated as part of normal disaster recovery testing.

Firewall configuration validation shall always be performed using disposable test virtual machines.

Production firewall instances shall never be used for configuration restore testing.

---

## Configuration Backup Objectives

Configuration backups are intended to:

- Preserve critical infrastructure settings.
- Minimize infrastructure recovery time.
- Reduce configuration drift.
- Provide rapid rollback capability following failed changes.
- Support disaster recovery procedures.
- Complement VM backups and snapshots without replacing either.

Configuration backups are considered a core component of the Project Polaris recovery strategy.

---

# Backup Destinations

## Primary Repository

**NAS01**

NAS01 serves as both:

- Primary backup repository
- Proxmox Cluster QDevice

---

## Future Secondary Repository

When additional storage becomes available, backups may also be replicated to:

- External encrypted storage
- Off-site storage
- Cloud archive (when operationally justified)

---

# Encryption Policy

All backup archives containing infrastructure or configuration data shall be encrypted whenever supported by the platform.

Encryption protects:

- Active Directory
- Certificates
- Credentials
- Firewall configurations
- Infrastructure documentation

---

# Operational Considerations

Project Polaris is both a production-inspired environment and an active learning platform.

Backup schedules are intentionally designed to:

- Minimize interruption during normal learning activities.
- Reduce unnecessary storage consumption.
- Avoid excessive system overhead.
- Preserve overall usability while maintaining recoverability.

This policy intentionally favors efficient, risk-based backups over aggressive backup schedules in order to maximize available system resources while still protecting critical infrastructure.

---

# Snapshot Policy

Snapshots are **not** backups.

Snapshots shall be created:

- Immediately after creation of every new virtual machine.
- Prior to major configuration changes.
- Prior to operating system upgrades.
- Prior to application upgrades.
- Prior to infrastructure migrations.

Snapshots should be removed after successful validation unless intentionally retained for a documented project milestone.

---

# Backup Validation

A backup is not considered valid until recovery has been successfully demonstrated.

---

## Configuration Validation

Configuration backups shall be validated periodically.

Firewall configuration validation shall always be performed using disposable test virtual machines.

Production firewall instances shall never be used for configuration restore testing.

---

## Enterprise VM Validation

Scheduled rebuilds of:

- DC01
- CA01

serve as the formal restore validation process for these systems.

These rebuilds simultaneously validate:

- Golden templates
- Backup integrity
- Recovery documentation
- Operational recovery procedures

---

## Disaster Recovery Validation

Complete disaster recovery exercises shall be performed within the Cyber Range.

The Cyber Range provides a safe environment for validating recovery procedures without impacting:

- Home networking
- Homelab production infrastructure
- Internet connectivity

---

# Backup Exclusions

The following items are intentionally excluded from scheduled backup operations:

- ISO repositories
- Temporary downloads
- Disposable Cyber Range workloads
- AI model caches (Future)
- Swap files
- Temporary log files beyond retention requirements
- Forgejo repositories

Forgejo repositories are excluded because repository integrity is maintained through distributed Git synchronization between:

- Docker01
- Windows Administration Workstation
- Forgejo Server

Git replication provides multiple authoritative copies without requiring scheduled virtual machine backups for repository protection.

---

# Monitoring

Backup operations shall be reviewed regularly.

Monitoring includes:

- Failed backup jobs
- Backup completion status
- Storage utilization
- Retention compliance
- Backup repository health

Failed backup operations should be investigated promptly.

---

# Recovery Documentation

Every production service shall maintain a corresponding recovery procedure within the Project Polaris Forgejo repository.

Examples include:

- Proxmox Recovery
- Gateway01 Recovery
- Firewall01 Recovery
- Docker01 Recovery
- DC01 Recovery
- CA01 Recovery
- NAS01 Recovery

Recovery documentation should enable the environment to be rebuilt from documented procedures with minimal assumptions.

---

# Periodic Policy Review

This Backup & Disaster Recovery Policy shall be reviewed:

- After completion of each roadmap milestone.
- Following significant infrastructure additions.
- After storage architecture changes.
- Following hardware expansion.
- After any disaster recovery exercise.
- At least annually.

Policy revisions shall reflect changes in infrastructure, available resources, and operational requirements.

---

# Future Growth

As Project Polaris expands, this policy is intended to scale to include:

- Additional Proxmox nodes
- Increased storage capacity
- Off-site replication
- AI infrastructure
- Expanded enterprise services

The principles of this policy shall remain consistent while implementation details evolve.

---

# Revision History

| Version | Date | Description |
|----------|------------|------------------------------------------------------------|
| 1.0 | 2026-07-22 | Initial Backup & Disaster Recovery Policy for Project Polaris. |