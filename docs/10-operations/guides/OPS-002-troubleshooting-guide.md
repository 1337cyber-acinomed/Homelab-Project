# OPS-002: Cluster Troubleshooting Guide

Document ID: OPS-002

Version: 1.0

Status: Production

Owner: Project Polaris

Last Updated: 2026-07-19

---

# Purpose

This guide provides standardized troubleshooting procedures for the Project Polaris Proxmox administrative cluster.

It documents known operational behaviors, common failure scenarios, validated recovery procedures, and implementation lessons learned throughout the development of Project Polaris.

This document is intended to reduce troubleshooting time while promoting consistent recovery procedures.

---

# Scope

Applies to:

- homelab
- cyberrange
- Future Project Polaris Proxmox nodes

This guide assumes PR-001 and PR-002 have been successfully completed.

---

# References

STD-001 – Node Naming Standard

STD-002 – Network Architecture & Management Guide

PR-001 – Proxmox VE 9 Installation Guide

PR-002 – Administrative Cluster Build Guide

OPS-001 – Cluster Administration Guide

Project Polaris Storage Architecture

Project Polaris Disaster Recovery Plan

---

# Table of Contents

1. Troubleshooting Methodology

2. Cluster Issues

3. Storage Issues

4. Networking Issues

5. Administrative Access Issues

6. Service Issues

7. Hostname and Certificate Issues

8. Recovery Procedures

9. Expected Behaviors

10. Lessons Learned

Appendix A – Diagnostic Commands

Appendix B – Service Reference

Appendix C – Recovery Flowcharts

Appendix D – Emergency Checklist

---

# 1. Troubleshooting Methodology

Always troubleshoot in the following order:

1. Identify symptoms.

2. Verify recent changes.

3. Review logs.

4. Confirm documentation.

5. Isolate the failure.

6. Implement corrective action.

7. Validate recovery.

8. Update documentation.

Never make multiple configuration changes simultaneously.

---

# 2. Cluster Issues

## Cluster Does Not Form

### Symptoms

- Node join fails.
- No quorum.
- Corosync errors.

### Diagnostics

```bash
pvecm status

systemctl status corosync

journalctl -u corosync
```

### Resolution

Verify:

- Hostnames
- Time synchronization
- Management network
- Firewall connectivity

Reattempt cluster join only after root cause has been identified.

---

## Node Does Not Rejoin

Diagnostics:

```bash
systemctl status pve-cluster

journalctl -u pve-cluster
```

Verify:

- Network
- Corosync
- PMXCFS

---

# 3. Storage Issues

## ZFS Pool Offline

Diagnostics

```bash
zpool status
```

Verify:

- Device availability
- SMART
- Cabling
- Pool status

---

## Storage Missing From GUI

Diagnostics

```bash
pvesm status
```

Verify:

- Storage registration
- Pool imported
- Node assignment

---

## ISO Repository Unavailable

Verify:

- Mount status
- Network share (if applicable)
- Storage registration
- Permissions

Reference:

Storage Architecture

---

# 4. Networking Issues

## Loss of Connectivity

Diagnostics

```bash
ip addr

ip route

ping <gateway>

ping 8.8.8.8

ping google.com
```

Verify:

- Interface state
- Static IP
- Gateway
- DNS

---

## Management Interface Incorrect

Verify:

```bash
cat /etc/network/interfaces
```

Compare against:

Project Polaris IP Address Plan

---

# 5. Administrative Access Issues

## SSH Failure

Verify:

```bash
systemctl status ssh
```

Attempt:

```bash
ssh root@<host>
```

---

## Proxmox GUI Unavailable

Verify:

```bash
systemctl status pveproxy
```

Confirm:

```
https://<host>:8006
```

---

## Tailscale

Verify:

```bash
tailscale status
```

```bash
tailscale ping <peer>
```

---

## RustDesk

Verify:

- Service running
- ID assigned
- Remote connection

---

# 6. Service Issues

Verify:

```bash
systemctl --failed
```

Review:

```bash
journalctl -p err -b
```

Restart services only after identifying the root cause.

---

# 7. Hostname and Certificate Issues

Hostname changes after commissioning require additional validation.

Verify:

```bash
hostnamectl

cat /etc/hostname

cat /etc/hosts
```

Confirm:

- Permanent hostname
- FQDN
- No legacy names

If hostname changes are required after cluster formation:

Reference:

PR-001 Appendix B

---

# 8. Recovery Procedures

Recover in the following order:

1. Hardware

2. Network

3. Operating System

4. Cluster

5. Storage

6. Services

7. Virtual Machines

Validate each layer before proceeding.

---

# 9. Expected Behaviors

The following behaviors are expected and should not be interpreted as faults.

### Local Storage

Remote-local ZFS pools display:

```
disabled
```

This is expected.

---

### qm list

Displays only VMs owned by the local node.

---

### pvesh get /cluster/resources

Displays all cluster resources.

---

### PMXCFS

VM configuration files synchronize across nodes.

Storage does not.

---

### Two-Node Cluster

Temporary loss of quorum while one node is offline is expected unless a quorum device is configured.

---

### Administrative Cluster

Project Polaris uses an administrative cluster.

Shared storage and High Availability are intentionally not configured.

---

# 10. Lessons Learned

The following architectural decisions were validated during implementation.

- Administrative clustering is simpler and more maintainable than shared-storage clustering for Project Polaris.

- Hypervisors remain on the Trusted Infrastructure network.

- OPNsense protects Cyber Range guest workloads, not hypervisor management.

- Purpose-driven naming greatly simplifies future hardware replacement.

- Documentation significantly reduced troubleshooting effort throughout implementation.

- Standardized validation procedures prevented configuration drift.

---

# Appendix A

Common Diagnostic Commands

```bash
pvecm status

pvecm nodes

pvesh get /cluster/resources

pvesm status

zpool status

systemctl --failed

journalctl -p err -b

ip addr

ip route

hostnamectl

timedatectl
```

---

# Appendix B

Critical Services

| Service | Purpose |
|----------|----------|
| corosync | Cluster communication |
| pve-cluster | PMXCFS |
| pvedaemon | API daemon |
| pveproxy | Web interface |
| ssh | Remote shell |
| lightdm | Administrative desktop |

---

# Appendix C

Recovery Flowcharts

Recommended:

Create Draw.io recovery flowcharts for:

- Cluster failure
- Storage failure
- Network failure
- Host replacement
- Disaster recovery

---

# Appendix D

Emergency Checklist

1. Protect data.

2. Verify backups.

3. Identify scope.

4. Restore infrastructure.

5. Restore services.

6. Restore workloads.

7. Validate.

8. Document.

---

# Revision History

| Version | Date | Description |
|----------|------|-------------|
| 1.0 | 2026-07-19 | Initial Cluster Troubleshooting Guide established. |

