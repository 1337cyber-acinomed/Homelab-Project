# firewall01 Recovery Runbook

**Document ID:** RB-003

**Version:** 1.0 (Draft)

**Status:** Review

**Owner:** Project Polaris

**Last Updated:** 2026-07-31

------------------------------------------------------------------------

# Purpose

Provide a repeatable procedure for restoring the Project Polaris
internal production firewall (firewall01) following virtual machine
failure, configuration corruption, or disaster recovery operations.

------------------------------------------------------------------------

# Scope

Applies to recovery of the production pfSense firewall responsible for
protecting the homelab, providing internal routing, DNS, DHCP, and
access to production infrastructure.

------------------------------------------------------------------------

# Prerequisites

-   pve01 operational.
-   gateway01 fully restored and validated.
-   Latest validated firewall01 configuration backup.
-   Access to NAS01 backup repository.
-   Administrative credentials available.

------------------------------------------------------------------------

# Recovery Procedure

## Phase 1 -- Restore Virtual Machine

1.  Restore the firewall01 virtual machine.
2.  Verify the correct VMID and virtual hardware.
3.  Confirm WAN, LAN, and additional interfaces are mapped correctly.
4.  Start the virtual machine.

### Validation

-   VM boots successfully.
-   pfSense console available.
-   Network interfaces detected correctly.

------------------------------------------------------------------------

## Phase 2 -- Restore Configuration

1.  Restore the latest validated configuration backup.
2.  Verify interface assignments.
3.  Verify LAN addressing.
4.  Verify DHCP configuration.
5.  Verify DNS Resolver configuration.
6.  Reboot if required.

### Validation

-   Configuration restored successfully.
-   DHCP and DNS services running.
-   Interface configuration correct.

------------------------------------------------------------------------

## Phase 3 -- Validate Network Services

1.  Verify routing to gateway01.
2.  Validate LAN client connectivity.
3.  Verify DNS resolution.
4.  Confirm Internet access from the production network.
5.  Validate communication with DC01 and docker01.

### Validation

-   Production clients receive IP addresses.
-   DNS resolution successful.
-   Internet connectivity restored.
-   Core infrastructure reachable.

------------------------------------------------------------------------

## Phase 4 -- Validate Security

1.  Review firewall rules.
2.  Verify NAT configuration.
3.  Validate administrative access.
4.  Review logs for warnings or errors.

### Validation

-   Firewall policy functioning correctly.
-   Administrative access operational.
-   No unresolved critical errors.

------------------------------------------------------------------------

# Recovery Completion Checklist

-   [ ] firewall01 operational
-   [ ] Configuration restored
-   [ ] WAN/LAN verified
-   [ ] DHCP validated
-   [ ] DNS validated
-   [ ] Production connectivity restored
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
  --------- ------------ --------------------------------------
  1.0       2026-07-31   Initial firewall01 Recovery Runbook.
