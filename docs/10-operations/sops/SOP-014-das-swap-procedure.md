# DAS-HotSwap-Procedure.md

# Project Polaris
## DAS Storage Maintenance Procedure

### Purpose

Safely remove or install disks in the USB DAS without interrupting Proxmox services or risking filesystem corruption.

---

# Scope

Applies to all storage devices connected through the USB DAS, including:

- ISO Repository
- Future temporary migration disks
- Offline archive drives

This procedure does **not** apply to production VM passthrough disks that are actively attached to running virtual machines.

---

# Preconditions

- No VM is actively using the disk being serviced.
- All backups or transfers have completed.
- Administrator access to Proxmox host.

---

# Step 1 – Verify Storage Usage

Confirm no VM is using the storage.

Example:

```bash
qm list
```

Confirm any VM using the storage is powered off.

---

# Step 2 – Verify Current Mount

```bash
findmnt /mnt/ISO-Repo
```

Document the current mount status.

---

# Step 3 – Gracefully Unmount

Example:

```bash
umount /mnt/ISO-Repo
```

Verify:

```bash
findmnt /mnt/ISO-Repo
```

No output should be returned.

---

# Step 4 – Shut Down DAS

Power off the DAS.

Wait 10–15 seconds for USB devices to disconnect.

---

# Step 5 – Perform Hardware Changes

Install or remove disks.

Verify:

- Proper seating
- Cabling
- Drive bay assignment

---

# Step 6 – Power On DAS

Power on the DAS.

Wait 30 seconds for USB enumeration.

---

# Step 7 – Verify Drive Detection

```bash
lsblk
```

Confirm the expected device appears.

---

# Step 8 – Verify Device Identity

Example:

```bash
blkid
```

or

```bash
ls -l /dev/disk/by-id/
```

Confirm:

- Correct model
- Correct serial number
- Correct UUID

---

# Step 9 – Mount Filesystem

Example:

```bash
mount /mnt/ISO-Repo
```

Verify:

```bash
findmnt /mnt/ISO-Repo
```

Expected:

```
TARGET         SOURCE      FSTYPE
/mnt/ISO-Repo  /dev/sdd1   ext4
```

---

# Step 10 – Verify Files

Example:

```bash
find /mnt/ISO-Repo -type f | head
```

Confirm expected files are present.

---

# Step 11 – Verify Proxmox

Refresh the GUI.

Confirm:

- Storage Active
- Files visible
- No storage errors

---

# Step 12 – Resume Operations

Storage may now be used normally.

---

# Recovery

If the filesystem does not mount:

1. Do not format the disk.
2. Review:

```bash
journalctl -b
```

3. Verify UUID:

```bash
blkid
```

4. Verify `/etc/fstab`

5. Mount manually.

Only proceed after successful validation.

---

# Notes

This procedure was created after validating Project Polaris storage migration during Phase D.

It prevents filesystem journal interruptions caused by powering down the USB DAS while mounted.
