# OPS-001: Cluster Administration Guide

Document ID: OPS-001

Version: 1.0

Status: Production

Owner: Project Polaris

Last Updated: 2026-07-19

---

# Purpose

This guide defines the standard operational procedures for administering the Project Polaris Proxmox administrative cluster.

It establishes routine maintenance practices, operational standards, monitoring requirements, backup procedures, update workflows, and disaster recovery preparation to ensure long-term stability and consistency across the virtualization platform.

---

# Scope

Applies to:

- homelab
- cyberrange
- Future Project Polaris Proxmox nodes

This document governs day-to-day cluster administration after commissioning has been completed.

---

# References

STD-001 – Node Naming Standard

STD-002 – Network Architecture & Management Guide

PR-001 – Proxmox VE 9 Installation Guide

PR-002 – Administrative Cluster Build Guide

OPS-002 – Cluster Troubleshooting Guide

Project Polaris Storage Architecture

Project Polaris Maintenance Backlog

Project Polaris Disaster Recovery Plan

---

# Table of Contents

1. Operational Philosophy

2. Daily Operations

3. Weekly Operations

4. Monthly Operations

5. Software Updates

6. Backup Management

7. Cluster Health

8. Planned Maintenance

9. Disaster Recovery

10. Operational Acceptance

Appendix A – Administrative Commands

Appendix B – Maintenance Checklists

Appendix C – Backup Verification

Appendix D – Recovery Validation

---

# 1. Operational Philosophy

## 1.1 Objective

Provide consistent operational practices for maintaining the Project Polaris administrative cluster.

Infrastructure stability takes priority over feature implementation.

Operational changes shall follow the Project Polaris change lifecycle:

- Plan
- Implement
- Validate
- Document
- Protect

---

## 1.2 Administrative Principles

Cluster administration shall prioritize:

- Stability
- Predictability
- Documentation
- Security
- Recoverability
- Simplicity

Changes should never be introduced without understanding their operational impact.

---

# 2. Daily Operations

## 2.1 Cluster Health

Verify:

```bash
pvecm status
```

Confirm:

- Quorate
- Expected nodes
- No communication errors

---

## 2.2 Node Status

Review:

- CPU utilization
- Memory utilization
- Storage utilization
- Running services

Verify no unexpected warnings exist.

---

## 2.3 Task Review

Review:

Datacenter

↓

Tasks

Confirm:

- No failed tasks
- No repeated failures
- No unexpected activity

---

## 2.4 Backup Verification

Confirm scheduled backups completed successfully.

Investigate all failures.

---

## 2.5 Security Review

Review:

- Failed login attempts
- SSH activity
- Administrative access
- Tailscale status

---

# 3. Weekly Operations

Perform:

□ Verify ZFS health

```bash
zpool status
```

□ Verify storage utilization

```bash
pvesm status
```

□ Review cluster logs

□ Review hardware alerts

□ Review SMART status

□ Confirm documentation remains current

---

# 4. Monthly Operations

Perform:

- Test configuration backups
- Review storage capacity
- Verify UPS functionality (future)
- Review update availability
- Validate remote administration
- Review disaster recovery documentation

---

# 5. Software Updates

## 5.1 Update Philosophy

Project Polaris updates nodes individually.

The administrative cluster shall remain stable throughout maintenance.

---

## 5.2 Update Order

Standard order:

1. cyberrange

2. Validation

3. homelab

Infrastructure is always updated last.

---

## 5.3 Update Procedure

1.

Verify:

```bash
pvecm status
```

2.

Create configuration backup.

3.

Update:

```bash
apt update

apt full-upgrade
```

4.

Reboot.

5.

Validate.

6.

Repeat on remaining nodes.

---

# 6. Backup Management

Required backups include:

- VM backups
- Configuration backups
- Cluster configuration
- Firewall configuration
- NAS configuration
- Switch configuration
- Documentation repository

Backups shall be periodically tested.

A backup that cannot be restored shall not be considered valid.

---

# 7. Cluster Health

Regularly verify:

```bash
pvecm status

pvecm nodes

pvesh get /cluster/resources

pvesm status
```

Expected:

- Stable quorum
- Expected membership
- Healthy storage
- No communication errors

---

# 8. Planned Maintenance

Before maintenance:

□ Confirm backups.

□ Verify cluster health.

□ Notify users (if applicable).

□ Record maintenance objective.

After maintenance:

□ Validate services.

□ Validate cluster.

□ Update documentation.

□ Record observations.

---

# 9. Disaster Recovery

Recovery priority:

1.

Gateway

2.

Firewall01

3.

homelab

4.

Administrative Cluster

5.

NAS

6.

Domain Services

7.

Docker Services

8.

cyberrange

9.

Cyber Range workloads

This priority shall remain consistent unless superseded by an approved architectural decision.

---

# 10. Operational Acceptance

The cluster is considered operational when:

□ Cluster healthy

□ Storage healthy

□ Backups healthy

□ Documentation current

□ Monitoring operational

□ Administrative access available

□ Disaster recovery documentation current

---

# Lessons Learned

Administrative discipline contributes more to long-term infrastructure stability than introducing additional technology.

Routine validation significantly reduces troubleshooting effort and minimizes technical debt.

Maintaining accurate documentation alongside routine operations improves recoverability and ensures that operational procedures remain aligned with the production environment.

---

# Appendices

Appendix A – Administrative Commands

Appendix B – Maintenance Checklists

Appendix C – Backup Verification

Appendix D – Recovery Validation

---

# Revision History

| Version | Date | Description |
|----------|------|-------------|
| 1.0 | 2026-07-19 | Initial Cluster Administration Guide established. |
