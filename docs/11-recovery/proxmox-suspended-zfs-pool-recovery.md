# Proxmox Suspended ZFS Pool Recovery Procedure

## Purpose

This procedure documents recovery steps for a Proxmox host when a retired or failed ZFS pool remains referenced by VM configurations or Proxmox storage definitions.

## When to Use

Use this procedure when Proxmox reports:

```text
zfs error: cannot open '<pool>': pool I/O is currently suspended
or when VM backups/start operations fail because Proxmox is attempting to access an unavailable storage backend.

Recovery Steps
1. Identify Pool Health
zpool status -v
zpool list
2. Identify Proxmox Storage Definitions
cat /etc/pve/storage.cfg
pvesm status
3. Search for Stale VM References
grep -R "OLD_STORAGE_NAME:" /etc/pve
Example:

grep -R "VM:" /etc/pve
4. Review Affected VM Configurations
qm config <VMID>

Look for stale references in:

scsi*
sata*
virtio*
efidisk*
ide*
unused*
5. Move or Recreate Metadata Disks

Preferred locations:

EFI disks: local-lvm
Cloud-init disks: local-lvm

Cloud-init disks may need to be removed and recreated rather than moved.
6. Remove Unused Disk References

For stale unused disks:

qm set <VMID> --delete unused0

Repeat for unused1, unused2, etc., if applicable.

7. Remove Failed Storage Backend

If the storage backend is no longer required:

pvesm remove OLD_STORAGE_NAME

If that fails or hangs, edit:

nano /etc/pve/storage.cfg

Remove only the failed storage block.
8. Restart Services or Reboot

Restart services if possible:

systemctl restart pvestatd
systemctl restart pvedaemon
systemctl restart pveproxy

If services hang or report stale FUSE/pmxcfs errors, perform a controlled reboot.

reboot
9. Validate After Recovery
zpool status -v
pvesm status
qm list
journalctl -p err -b
grep -R "OLD_STORAGE_NAME:" /etc/pve
10. Resume Backups

After validation, rerun the failed backup:

vzdump <VMID> \
  --mode snapshot \
  --compress zstd \
  --dumpdir /mnt/storage01/Backups/Infrastructure/Proxmox/VM-Backups/<VMName>
Notes

Do not destroy or export a failed ZFS pool until all VM references and storage definitions have been removed or migrated.

Do not assume a VM has fully migrated just because its main OS disk moved successfully. Always check EFI, cloud-init, and unused disk references.
