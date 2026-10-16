# DC01 Recovery Runbook

**Document ID:** RB-005

**Version:** 1.0 (Draft)

**Status:** Review

**Owner:** Project Polaris

**Last Updated:** 2026-07-31

------------------------------------------------------------------------

# Purpose

Provide a repeatable procedure for restoring the Project Polaris Active
Directory Domain Controller (DC01) following virtual machine failure,
directory corruption, or disaster recovery operations.

------------------------------------------------------------------------

# Scope

Applies to recovery of DC01, including Active Directory Domain Services
(AD DS), DNS, and core identity services supporting the production
environment.

------------------------------------------------------------------------

# Prerequisites

-   pve01 operational.
-   gateway01 and firewall01 fully restored.
-   Stable network connectivity.
-   Latest validated DC01 backup available.
-   Access to NAS01 backup repository.
-   Administrative credentials available.

------------------------------------------------------------------------

# Recovery Procedure

## Phase 1 -- Restore Virtual Machine

1.  Restore the DC01 virtual machine.
2.  Verify VMID, CPU, memory, storage, and networking.
3.  Start the virtual machine.
4.  Confirm the operating system boots successfully.

### Validation

-   VM starts normally.
-   Static IP configuration present.
-   Administrative logon successful.

------------------------------------------------------------------------

## Phase 2 -- Validate Active Directory

1.  Verify Active Directory Domain Services are running.
2.  Confirm SYSVOL and NETLOGON shares exist.
3.  Verify domain health.
4.  Confirm FSMO roles are available.

### Validation

-   AD DS operational.
-   SYSVOL and NETLOGON shared.
-   Domain services healthy.

------------------------------------------------------------------------

## Phase 3 -- Validate DNS

1.  Verify DNS Server service.
2.  Confirm forward lookup zones.
3.  Confirm reverse lookup zones.
4.  Test internal name resolution.
5.  Validate client registration.

### Validation

-   DNS responds correctly.
-   Forward and reverse lookups succeed.
-   Domain records present.

------------------------------------------------------------------------

## Phase 4 -- Validate Authentication

1.  Confirm domain administrator authentication.
2.  Verify workstation logon.
3.  Validate Group Policy processing.
4.  Confirm communication with firewall01 and docker01.

### Validation

-   Domain authentication successful.
-   Group Policy applied.
-   Infrastructure services reachable.

------------------------------------------------------------------------

# Recovery Completion Checklist

-   [ ] DC01 operational
-   [ ] Active Directory validated
-   [ ] DNS validated
-   [ ] Authentication verified
-   [ ] Infrastructure communication confirmed
-   [ ] Documentation updated
-   [ ] Recovery recorded

------------------------------------------------------------------------

# Related Documents

-   SOP-006 Backup and Restore Operations
-   SOP-009 Windows Server Administration
-   DR-005 Service Recovery Procedures
-   ADR-017 Virtualization Architecture
-   ADR-018 Backup Strategy

------------------------------------------------------------------------

# Revision History

  Version   Date         Description
  --------- ------------ --------------------------------
  1.0       2026-07-31   Initial DC01 Recovery Runbook.
