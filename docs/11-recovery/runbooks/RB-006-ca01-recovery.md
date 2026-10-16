# CA01 Recovery Runbook

**Document ID:** RB-006

**Version:** 1.0 (Draft)

**Status:** Review

**Owner:** Project Polaris

**Last Updated:** 2026-07-31

------------------------------------------------------------------------

# Purpose

Provide a repeatable procedure for recovering the Project Polaris
Certificate Authority (CA01) and restoring Public Key Infrastructure
(PKI) services following virtual machine failure, certificate service
corruption, or disaster recovery operations.

------------------------------------------------------------------------

# Scope

Applies to recovery of CA01, Active Directory Certificate Services (AD
CS), certificate templates, issued certificates, and the internal Public
Key Infrastructure supporting Project Polaris.

------------------------------------------------------------------------

# Prerequisites

-   pve01 operational.
-   gateway01 and firewall01 restored.
-   DC01 fully operational and validated.
-   Latest validated CA01 backup available.
-   Access to NAS01 backup repository.
-   Administrative credentials available.

------------------------------------------------------------------------

# Recovery Procedure

## Phase 1 -- Restore Virtual Machine

1.  Restore the CA01 virtual machine.
2.  Verify VM configuration and networking.
3.  Start the virtual machine.
4.  Confirm successful operating system startup.

### Validation

-   VM boots successfully.
-   Static IP configuration verified.
-   Administrative logon successful.

------------------------------------------------------------------------

## Phase 2 -- Validate Certificate Services

1.  Verify Active Directory Certificate Services are running.
2.  Confirm the Certification Authority is online.
3.  Verify CA database integrity.
4.  Confirm certificate templates are available.

### Validation

-   AD CS operational.
-   CA responding normally.
-   Templates available.

------------------------------------------------------------------------

## Phase 3 -- Validate PKI

1.  Issue a test certificate.
2.  Verify certificate chain.
3.  Validate certificate revocation configuration.
4.  Confirm internal trust.

### Validation

-   Test certificate issued successfully.
-   Trust chain validated.
-   No PKI errors reported.

------------------------------------------------------------------------

## Phase 4 -- Validate Integrated Services

1.  Verify TLS certificates used by internal services.
2.  Confirm secure administrative access.
3.  Review event logs for warnings or errors.
4.  Verify backup connectivity to NAS01.

### Validation

-   Internal certificates trusted.
-   Secure services functioning.
-   No unresolved critical errors.

------------------------------------------------------------------------

# Recovery Completion Checklist

-   [ ] CA01 operational
-   [ ] AD CS validated
-   [ ] Certificate templates verified
-   [ ] Test certificate issued
-   [ ] Internal trust confirmed
-   [ ] Documentation updated
-   [ ] Recovery recorded

------------------------------------------------------------------------

# Related Documents

-   SOP-006 Backup and Restore Operations
-   SOP-009 Windows Server Administration
-   SEC-007 Secrets and Certificate Management
-   DR-005 Service Recovery Procedures
-   ADR-020 Security Architecture

------------------------------------------------------------------------

# Revision History

  Version   Date         Description
  --------- ------------ --------------------------------
  1.0       2026-07-31   Initial CA01 Recovery Runbook.
