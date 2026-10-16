# Project Polaris
# Disaster Recovery Restore Procedure

Version: 1.0
Status: Approved
Applies To:
- Proxmox VE
- NAS Backups
- Infrastructure VMs
- Windows VMs
- Linux VMs

---

# Purpose

This document defines the standard restore procedure used throughout Project Polaris.

A backup SHALL NOT be considered valid until a successful restore validation has been completed.

---

# Recovery Principles

Never overwrite production unless performing an actual disaster recovery event.

All restores shall first be performed into a temporary VM.

Only after validation should production recovery be considered.

---

# Restore Workflow

NAS Backup
        │
        ▼
Select Backup
        │
        ▼
Restore to Temporary VMID
        │
        ▼
Boot Restored VM
        │
        ▼
Validate Functionality
        │
        ▼
Delete Temporary VM

---

# GUI Restore

Datacenter

↓

Storage

↓

NAS-Backups

↓

Backups

↓

Select Backup

↓

Restore

Recommended options:

Restore Storage:
VM

Unique VMID:
Temporary unused VMID

Overwrite Existing:
NO

Start after Restore:
YES

---

# CLI Restore

List available backups:

```bash
pvesm list NAS-Backups
```

Example restore:

```bash
qmrestore \
/mnt/pve/NAS-Backups/dump/vzdump-qemu-105.vma.zst \
905
```

Replace:

905

with an unused VMID.

Never restore over production during validation.

Validation Checklist
VM boots successfully

☐ BIOS loads

☐ Bootloader loads

☐ Operating system starts

Networking

☐ NIC detected

☐ IP assigned

☐ Gateway reachable

☐ DNS functional

Services

Linux

☐ SSH

☐ Docker

☐ Mounted shares

☐ QEMU Agent

Windows

☐ AD Join intact

☐ DNS functioning

☐ Services started

☐ QEMU Agent

Storage

☐ Files present

☐ Files readable

☐ Files writable

Logs

Review:

journalctl

or

Windows Event Viewer

No critical errors.

Success Criteria

The restore is considered successful when:

VM boots
Networking functions
Storage mounts
Services start
Applications function normally
Cleanup

After validation:

Shutdown VM

↓

Delete temporary VM

↓

Delete temporary disks

↓

Leave production unchanged

Disaster Recovery Event

During an actual recovery event:

Restore using original VMID

OR

Restore using temporary VMID

↓

Validate

↓

Switch production over

Only overwrite production if recovery objectives require it.
