# Proxmox Suspended ZFS Pool and Stale VM References

**Date:** 2026-07-05  
**System:** Proxmox / Storage / VM Management  
**Severity:** High  
**Status:** Resolved  

## Summary

During Wave 1 backup validation, Docker01 failed to back up and later failed to start. The initial error indicated that Proxmox could not access storage on the old `VM` ZFS pool because the pool was in a suspended I/O state.

## Symptoms

- `vzdump` for Docker01 failed.
- Docker01 initially failed with references to `VM/vm-103-disk-0`.
- Proxmox reported:

```text
zfs error: cannot open 'VM': pool I/O is currently suspended
pvestatd repeatedly logged errors against the old VM pool.
zpool import hung.
pvesm status showed the old VM storage as inactive or errored.
Docker01 hung during VM start while displaying:generating cloud-init ISO

Root Cause

The old VM ZFS pool had entered a suspended I/O state after disk I/O failures. Although production VM disks had been migrated to the healthy Firewall ZFS pool, some VM configurations still contained stale references to the old VM storage.

Remaining references included:

VM 102 EFI and cloud-init disks
VM 104 EFI and cloud-init disks
VM 202 disk reference
VM 103 unused disk reference
VM 100 unused disk reference

The active Proxmox storage configuration also still contained the old VM storage backend, causing Proxmox services to repeatedly attempt to enumerate an unavailable ZFS pool.

Diagnosis Commands
zpool status -v
zpool list
zfs list
pvesm status
cat /etc/pve/storage.cfg
grep -R "VM:" /etc/pve
qm config 103
qm cloudinit dump 103 user
qm cloudinit dump 103 network
qm cloudinit dump 103 meta
qm cloudinit update 103
pvesm path local-lvm:vm-103-cloudinit

Important Findings
Production VM disks were on the healthy Firewall pool.
Docker01 main disk was healthy:
Firewall/vm-103-disk-0
Cloud-init was successfully recreated on local-lvm.
EFI and cloud-init disks left on old storage can block VM start, backup, or management tasks.
Proxmox may appear to hang at generating cloud-init ISO even when the real issue is stale or unavailable storage metadata.
Resolution
Removed the old VM storage backend from Proxmox.
Cleaned stale VM references where safe.
Recreated Docker01 cloud-init disk on local-lvm.
Recreated Docker01 EFI disk on local-lvm.
Rebooted the Proxmox host to clear stale management-service state.
Verified all production VMs started successfully after reboot.
Verified storage health after reboot.

Validation

Post-recovery checks completed successfully:

zpool status -v
pvesm status
qm list
journalctl -p err -b

All production VMs booted successfully.

Lessons Learned
Always verify all VM disks, EFI disks, cloud-init disks, and unused disk references after migrating storage.
grep -R "OLD_STORAGE_NAME:" /etc/pve is essential after storage migration.
Do not rely only on the main VM disk location when validating storage migration.
Proxmox management services may continue to hold stale state after removing a failed storage backend.
A controlled reboot may be appropriate after correcting storage configuration and stale references.
EFI disks and cloud-init disks should be stored on local-lvm unless there is a specific reason otherwise.

Future Standard

For Project Polaris:

VM OS/data disks should reside on the primary healthy VM storage pool.
EFI disks should reside on local-lvm.
Cloud-init disks should reside on local-lvm.
After storage migrations, run:
grep -R "OLD_STORAGE_NAME:" /etc/pve
pvesm status
zpool status -v

before considering the migration complete.
