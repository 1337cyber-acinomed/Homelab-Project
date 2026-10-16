# PR-002: Administrative Cluster Build Guide

Document ID: PR-002

Version: 1.0

Status: Production

Owner: Project Polaris

Last Updated: 2026-07-19

---

# Purpose

This procedure defines the standardized process for building the Project Polaris administrative Proxmox cluster.

Following this procedure results in a fully operational administrative cluster suitable for centralized management of Project Polaris infrastructure.

This guide assumes each Proxmox host has already been installed and validated using PR-001.

---

# Scope

Applies to:

- homelab
- cyberrange
- Future Project Polaris infrastructure nodes

This procedure covers:

- Cluster preparation
- Cluster creation
- Node joining
- Validation
- Operational acceptance

This procedure does **not** cover:

- Proxmox installation
- Storage configuration
- Network architecture
- Virtual machine deployment

Those procedures are documented elsewhere.

---

# References

STD-001 – Node Naming Standard

STD-002 – Network Architecture & Management Guide

PR-001 – Proxmox VE 9 Installation Guide

OPS-001 – Cluster Administration Guide

OPS-002 – Cluster Troubleshooting Guide

Project Polaris IP Address Plan

Project Polaris DNS Registry

---

# Table of Contents

1. Prerequisites

2. Cluster Preparation

3. Cluster Creation

4. Joining Additional Nodes

5. Cluster Validation

6. Production Acceptance

Appendix A – Common Commands

Appendix B – Node Replacement

Appendix C – Cluster Recovery

Appendix D – Troubleshooting

---

# 1. Prerequisites

## 1.1 Objective

Verify all requirements have been satisfied before creating the administrative cluster.

---

## 1.2 Required Conditions

Every node shall:

□ Successfully complete PR-001.

□ Have static management networking.

□ Have permanent hostname assigned.

□ Have synchronized time.

□ Have Proxmox fully updated.

□ Have SSH operational.

□ Have Tailscale operational.

□ Have RustDesk operational.

□ Have storage configured.

---

## 1.3 Network Requirements

Nodes shall communicate across the Trusted Infrastructure management network.

Cluster traffic shall never traverse the Cyber Range.

Reference:

STD-002

---

# 2. Cluster Preparation

## 2.1 Verify Connectivity

On each node verify:

```bash
ping <peer>

ssh <peer>

```

Verify bidirectional communication.

---

## 2.2 Verify Hostnames

Run:

```bash
hostnamectl
```

Confirm:

- Permanent hostname
- FQDN
- No legacy hostnames

If hostname changes are required, complete them before continuing.

---

## 2.3 Verify /etc/hosts

Confirm both nodes contain:

- Local hostname
- Peer hostname
- Correct management IP addresses

Example:

```text
192.168.10.2      homelab

192.168.20.2      cyberrange
```

---

## 2.4 Verify Time

```bash
timedatectl
```

Both nodes shall report synchronized clocks.

---

## 2.5 Backup Configuration

Create configuration backups of:

```text
/etc/network/interfaces

/etc/hostname

/etc/hosts
```

---

# 3. Cluster Creation

## 3.1 Create Cluster

On:

```
homelab
```

Run:

```bash
pvecm create polaris --link0 192.168.10.2
```

Verify:

```bash
pvecm status
```

---

## 3.2 Verify Cluster

Expected:

- Cluster Name: polaris

- Nodes: 1

- Quorate: Yes

---

# 4. Joining Additional Nodes

## 4.1 Verify Node Preparation

On:

```
cyberrange
```

Confirm:

- Not already clustered

```bash
pvecm status
```

Expected:

```
Standalone node
```

---

## 4.2 Join Cluster

Run:

```bash
pvecm add 192.168.10.2
```

Authenticate using the root credentials of the existing cluster.

Accept the certificate fingerprint.

---

## 4.3 Verify Join

Run:

```bash
pvecm status

pvecm nodes
```

Expected:

```
homelab

cyberrange
```

---

# 5. Cluster Validation

## 5.1 Cluster Health

```bash
pvecm status
```

Verify:

□ Quorate

□ Two nodes

□ No communication errors

---

## 5.2 PMXCFS

```bash
ls /etc/pve/nodes
```

Expected:

```
homelab

cyberrange
```

---

## 5.3 Cluster Resources

```bash
pvesh get /cluster/resources
```

Verify:

- Both nodes
- All virtual machines
- Storage definitions

---

## 5.4 Storage

```bash
pvesm status
```

Expected:

Local pools remain local.

Remote-local pools display as disabled.

This is expected behavior.

---

## 5.5 Cross-Node Configuration

Verify:

```bash
cat /etc/pve/nodes/homelab/qemu-server/<vmid>.conf
```

from:

```
cyberrange
```

Confirm PMXCFS synchronization.

---

## 5.6 GUI Validation

Verify:

□ Both nodes visible.

□ Green status.

□ No failed tasks.

□ Cross-node shell available.

---

## 5.7 Operational Validation

Verify:

□ SSH

□ GUI

□ Tailscale

□ RustDesk

remain operational.

---

# 6. Production Acceptance

Confirm:

□ Cluster healthy.

□ PMXCFS synchronized.

□ Administrative access verified.

□ Documentation updated.

□ Configuration backups completed.

The administrative cluster is now accepted into production.

---

# Lessons Learned

Project Polaris demonstrated that an administrative-only cluster provides centralized management without introducing unnecessary complexity associated with shared storage or high availability.

Separating hypervisor management from Cyber Range workloads significantly improves disaster recovery while preserving security boundaries.

Using explicit management network addresses during cluster creation simplifies troubleshooting and avoids hostname resolution dependencies during initial deployment.

---

# Appendices

Appendix A

Common Cluster Commands

Appendix B

Replacing a Failed Node

Appendix C

Cluster Recovery

Appendix D

Troubleshooting

---

# Revision History

| Version | Date | Description |
|----------|------|-------------|
| 1.0 | 2026-07-19 | Initial Administrative Cluster Build Guide created. |

