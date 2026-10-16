# Project Polaris

# PR-001
# Proxmox VE 9 Enterprise Installation and Configuration Procedure

Document ID: PR-001

Version: 1.0

Status: Production Baseline

Owner: Project Polaris

Last Updated: 2026-07-19

---

# Purpose

This procedure defines the complete installation and initial configuration process for all Proxmox VE 9 hosts deployed within Project Polaris.

It establishes the standard enterprise baseline used for every virtualization node.

This procedure has been validated during deployment of:

- HW-001 (pve01)
- HW-003 (Cyber Range Host)

---

# Scope

This procedure includes:

- Hardware preparation
- BIOS configuration
- Proxmox installation
- Repository configuration
- System updates
- Desktop installation
- Administrative tool installation
- Remote management
- Storage configuration
- Validation
- Documentation
- Disaster recovery baseline

---

# Prerequisites

Required:

- Supported x86-64 hardware
- Internet connectivity
- Static IP plan
- DNS plan
- Project Polaris naming standards
- Installation media
- Storage plan

---

# Phase 1 - Hardware Preparation

## Verify Hardware

Record:

- Motherboard
- CPU
- Memory
- Network adapters
- Storage devices
- Serial numbers

Verify:

- SMART health
- Correct storage allocation
- BIOS recognizes all hardware

---

# Phase 2 - BIOS Configuration

Configure:

- Intel VT-x / AMD-V Enabled
- VT-d / IOMMU Enabled
- AHCI Enabled
- Secure Boot Disabled
- Boot Order Correct
- UEFI Mode Enabled

Save configuration.

---

# Phase 3 - Install Proxmox VE

Install using the latest supported Proxmox VE 9 ISO.

Configuration:

Hostname:

```
<hostname>.polaris.home.arpa
```

Gateway:

```
192.168.10.1
```

DNS:

```
192.168.10.40
```

Complete installation.

Reboot.

---

# Phase 4 - Initial Validation

Verify:

```bash
hostnamectl

ip addr

ip route

cat /etc/network/interfaces

pveversion

lsblk

zpool status
```

Confirm:

- Networking
- Internet
- Storage
- Hostname
- Gateway

---

# Phase 5 - Repository Configuration

Disable Enterprise repositories.

Rename:

```
pve-enterprise.sources

ceph.sources
```

Enable:

```
pve-no-subscription.sources
```

Update:

```bash
apt update

apt full-upgrade -y

apt autoremove -y

reboot
```

---

# Phase 6 - Desktop Environment

Install:

```bash
apt install task-xfce-desktop lightdm
```

Select:

```
lightdm
```

Reboot.

Verify graphical login.

---

# Phase 7 - Administrative Software

Install:

- Firefox
- Git
- Curl
- Wget
- Nano
- Vim
- Htop
- Btop
- Tree
- Zip
- Unzip
- Rsync
- Smartmontools
- lm-sensors
- pciutils
- usbutils
- lshw
- Fastfetch
- nvme-cli
- hdparm
- iftop
- iotop
- nfs-common
- cifs-utils

Validate:

```
fastfetch
```

---

# Phase 8 - Remote Management

## Tailscale

Install.

Authenticate.

Verify:

```
tailscale status

tailscale ip
```

---

## RustDesk

Install latest stable release.

Verify:

- GUI
- Remote connection
- Unattended access

---

# Phase 9 - Host Configuration

Configure hostname.

Example:

```
cyberrange
```

Update:

```
/etc/hostname

/etc/hosts
```

Reboot.

Verify:

```
hostname

hostnamectl

hostname -f
```

---

# Phase 10 - Storage Configuration

Validate disk.

Check SMART.

Remove existing metadata.

```
wipefs -a

sgdisk --zap-all
```

Create ZFS pool.

Enable:

```
autotrim=on
```

Run initial scrub.

Register storage within Proxmox.

Validate virtual disk creation.

---

# Phase 11 - Documentation

Update:

- Hardware Inventory
- Storage Architecture
- Roadmap
- Maintenance Backlog

Record:

- Hardware
- Serial numbers
- Firmware
- IP addresses
- Storage pools

---

# Phase 12 - Baseline Capture

Export:

```
/etc/network/interfaces

zpool status

zpool list

dpkg --get-selections

pveversion -v
```

Store within backup repository.

---

# Phase 13 - Validation Checklist

Networking

☐ Internet

☐ DNS

☐ SSH

Storage

☐ ZFS

☐ SMART

☐ AutoTrim

☐ Scrub

Remote Management

☐ Tailscale

☐ RustDesk

Documentation

☐ Hardware Inventory

☐ Storage Architecture

☐ Roadmap

☐ Maintenance Backlog

Backups

☐ Baseline Configuration

☐ Package Inventory

☐ Network Configuration

---

# Phase 14 - Disaster Recovery Readiness

Confirm the following exist:

- Hardware documentation
- Installation procedure
- Configuration exports
- Package inventory
- Storage documentation
- Backup location

Objective:

A failed Proxmox boot drive can be rebuilt to production status using this document and the captured configuration.

---

# Lessons Learned

Project Polaris established the following standards during deployment:

- Always update Proxmox immediately after installation.
- Proxmox VE 9 uses `.sources` repository files instead of `.list`.
- Disable Enterprise repositories when using Community Edition.
- Skip Ceph repositories until required.
- Install desktop and remote management before introducing clustering.
- Configure storage only after validating the operating system.
- Document every hardware asset before production use.
- Perform controlled storage maintenance with validation before and after hardware changes.
- Treat documentation as production infrastructure.

---

# Related Documents

HW-001

HW-002

HW-003

SA-001

roadmap_v2.md

maintenance-backlog.md
