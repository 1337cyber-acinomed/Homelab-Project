# gateway01 Recovery Runbook

**Document ID:** RB-002

**Version:** 1.0 (Draft)

**Status:** Review

**Owner:** Project Polaris

**Last Updated:** 2026-07-31

------------------------------------------------------------------------

# Purpose

Provide a repeatable procedure for restoring the Project Polaris edge
firewall (gateway01) following hardware failure, virtual machine loss,
configuration corruption, or disaster recovery operations.

------------------------------------------------------------------------

# Scope

Applies to recovery of the production edge firewall responsible for WAN
connectivity and upstream network protection.

------------------------------------------------------------------------

# Prerequisites

-   Proxmox host (pve01) operational.
-   Latest validated gateway01 configuration backup.
-   Access to NAS01 backup repository.
-   Administrative credentials available.
-   Physical network connectivity verified.

------------------------------------------------------------------------

# Recovery Procedure

## Phase 1 -- Restore Virtual Machine

1.  Restore the gateway01 virtual machine.
2.  Verify assigned VMID and virtual hardware.
3.  Confirm WAN and LAN interfaces are mapped correctly.
4.  Start the virtual machine.

### Validation

-   VM boots successfully.
-   Console accessible.
-   Interfaces detected correctly.

------------------------------------------------------------------------

## Phase 2 -- Restore Configuration

1.  Import the latest validated configuration backup.
2.  Verify interface assignments.
3.  Verify gateway configuration.
4.  Verify DHCP (if enabled).
5.  Reboot if required.

### Validation

-   Configuration restored successfully.
-   Interfaces operational.
-   Default gateway present.

------------------------------------------------------------------------

## Phase 3 -- Validate Network Connectivity

1.  Verify WAN connectivity.
2.  Verify LAN connectivity.
3.  Confirm Internet access.
4.  Validate DNS forwarding.
5.  Verify routing to firewall01.

### Validation

-   Internet connectivity restored.
-   DNS resolution successful.
-   Downstream firewall reachable.

------------------------------------------------------------------------

## Phase 4 -- Validate Security

1.  Review firewall rules.
2.  Verify administrative access.
3.  Confirm VPN or remote management (if configured).
4.  Review logs for errors.

### Validation

-   Administrative access operational.
-   No critical firewall errors.
-   Security services functioning normally.

------------------------------------------------------------------------

# Recovery Completion Checklist

-   [ ] gateway01 operational
-   [ ] Configuration restored
-   [ ] WAN and LAN validated
-   [ ] Internet connectivity verified
-   [ ] Downstream connectivity confirmed
-   [ ] Documentation updated
-   [ ] Recovery recorded

------------------------------------------------------------------------

# Related Documents

-   SOP-007 pfSense Firewall Administration
-   SOP-006 Backup and Restore Operations
-   DR-003 Recovery Priorities
-   DR-005 Service Recovery Procedures
-   ADR-015 Network Architecture

------------------------------------------------------------------------

# Revision History

  Version   Date         Description
  --------- ------------ -------------------------------------
  1.0       2026-07-31   Initial gateway01 Recovery Runbook.
