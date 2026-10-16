# Proxmox Host Recovery Runbook

**Document ID:** RB-001

**Version:** 1.0 (Draft)

**Status:** Review

**Owner:** Project Polaris

**Last Updated:** 2026-07-31

------------------------------------------------------------------------

# Purpose

Provide a detailed, repeatable procedure for recovering the Project
Polaris Proxmox host (pve01) following hardware failure, operating
system failure, or configuration loss.

------------------------------------------------------------------------

# Scope

This runbook applies to recovery of the production Proxmox host and
restoration of virtualization services supporting Project Polaris.

------------------------------------------------------------------------

# Prerequisites

-   Replacement or repaired hardware available.
-   Proxmox installation media.
-   Access to NAS01 backup repository.
-   Administrative credentials available.
-   Latest validated configuration backups available.

------------------------------------------------------------------------

# Recovery Procedure

## Phase 1 -- Prepare Hardware

1.  Verify hardware integrity.
2.  Connect all production network interfaces.
3.  Verify storage devices are installed.
4.  Record hardware changes.

### Validation

-   Hardware powers on.
-   Storage detected.
-   Network links active.

------------------------------------------------------------------------

## Phase 2 -- Install Proxmox VE

1.  Install the approved Proxmox version.
2.  Configure hostname as **pve01**.
3.  Configure management networking.
4.  Apply updates.
5.  Enable required repositories.

### Validation

-   Web interface accessible.
-   SSH operational.
-   Management network functioning.

------------------------------------------------------------------------

## Phase 3 -- Restore Host Configuration

1.  Restore host configuration.
2.  Recreate storage definitions.
3.  Restore bridges and networking.
4.  Verify repositories and scheduled tasks.

### Validation

-   Storage online.
-   Bridges operational.
-   Configuration restored.

------------------------------------------------------------------------

## Phase 4 -- Restore Virtual Machines

Restore in dependency order:

1.  gateway01
2.  firewall01
3.  DC01
4.  docker01
5.  Remaining production VMs
6.  Administrative workstations

### Validation

-   All required VMs boot.
-   No critical startup errors.

------------------------------------------------------------------------

## Phase 5 -- Validate Infrastructure

1.  Verify Internet connectivity.
2.  Validate DNS.
3.  Validate Active Directory.
4.  Validate Docker services.
5.  Verify NAS01 connectivity.
6.  Review logs.

### Validation

-   Core services operational.
-   Monitoring healthy.
-   No critical errors.

------------------------------------------------------------------------

# Recovery Completion Checklist

-   [ ] Proxmox operational
-   [ ] Storage verified
-   [ ] Networking restored
-   [ ] Production VMs restored
-   [ ] Core services validated
-   [ ] Documentation updated
-   [ ] Recovery recorded

------------------------------------------------------------------------

# Related Documents

-   SOP-004
-   SOP-006
-   DR-003
-   DR-005
-   ADR-017

------------------------------------------------------------------------

# Revision History

  Version   Date         Description
  --------- ------------ ----------------------------------------
  1.0       2026-07-31   Initial Proxmox Host Recovery Runbook.
