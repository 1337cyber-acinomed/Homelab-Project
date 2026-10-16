# NAS01 Recovery Runbook

**Document ID:** RB-007

**Version:** 1.0 (Draft)

**Status:** Review

**Owner:** Project Polaris

**Last Updated:** 2026-07-31

------------------------------------------------------------------------

# Purpose

Provide a repeatable procedure for recovering the Project Polaris
Network Attached Storage (NAS01) and restoring backup repository
services following hardware failure, storage failure, or disaster
recovery operations.

------------------------------------------------------------------------

# Scope

Applies to recovery of NAS01, storage pools, shared folders, SMB
services, and the centralized backup repository supporting Project
Polaris.

------------------------------------------------------------------------

# Prerequisites

-   pve01 operational.
-   Core networking (gateway01 and firewall01) restored.
-   Replacement or repaired NAS hardware available.
-   Latest validated NAS configuration backup.
-   Backup disks available and healthy.
-   Administrative credentials available.

------------------------------------------------------------------------

# Recovery Procedure

## Phase 1 -- Restore NAS Hardware

1.  Verify replacement hardware.
2.  Install storage drives.
3.  Connect power and network.
4.  Confirm network link.

### Validation

-   NAS powers on.
-   Storage detected.
-   Network connectivity established.

------------------------------------------------------------------------

## Phase 2 -- Restore NAS Configuration

1.  Install the approved NAS operating system version if required.
2.  Restore the saved NAS configuration.
3.  Recreate storage pools if necessary.
4.  Restore shared folders and permissions.

### Validation

-   Configuration restored.
-   Storage pool healthy.
-   Shares accessible.

------------------------------------------------------------------------

## Phase 3 -- Validate Backup Repository

1.  Verify SMB services.
2.  Confirm backup share availability.
3.  Validate Proxmox connectivity.
4.  Validate collector write access.
5.  Confirm available storage capacity.

### Validation

-   Shares reachable.
-   Read/write access successful.
-   Backup repository online.

------------------------------------------------------------------------

## Phase 4 -- Validate Backup Operations

1.  Execute a test backup.
2.  Verify file integrity.
3.  Confirm retention directories.
4.  Review NAS logs for errors.

### Validation

-   Test backup successful.
-   Backup readable.
-   No critical storage or service errors.

------------------------------------------------------------------------

# Recovery Completion Checklist

-   [ ] NAS01 operational
-   [ ] Storage pool healthy
-   [ ] SMB shares restored
-   [ ] Backup repository validated
-   [ ] Test backup completed
-   [ ] Documentation updated
-   [ ] Recovery recorded

------------------------------------------------------------------------

# Related Documents

-   SOP-006 Backup and Restore Operations
-   DR-002 Backup Strategy
-   DR-005 Service Recovery Procedures
-   ADR-018 Backup Strategy
-   GOV-005 Lifecycle Management

------------------------------------------------------------------------

# Revision History

  Version   Date         Description
  --------- ------------ ---------------------------------
  1.0       2026-07-31   Initial NAS01 Recovery Runbook.
