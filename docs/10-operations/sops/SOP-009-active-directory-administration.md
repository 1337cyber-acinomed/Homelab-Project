# SOP-009: Active Directory Administration

**Document ID:** SOP-009\
**Status:** Validated\
**Version:** 1.0

## Purpose

Provide repeatable procedures for administering the Project Polaris
Active Directory environment while maintaining authentication,
authorization, and directory service integrity.

## Prerequisites

-   Perform administration from an authorized domain management
    workstation.
-   Administrative access using an approved domain administrator
    account.
-   Verify current system state and backup exist before significant
    changes.
-   Schedule production changes during an approved maintenance window.

## Procedure 1 - Verify Domain Controller Health

1.  Sign in to DC01 or an approved administrative workstation.
2.  Verify the Domain Controller is online.
3.  Confirm Active Directory Domain Services and DNS services are
    running.
4.  Review Event Viewer for critical errors.
5.  Verify SYSVOL and NETLOGON shares are available.

## Procedure 2 - Perform Directory Administration

1.  Verify the requested change has been approved.
2.  Create, modify, or remove users, groups, computers, or
    organizational units as required.
3.  Apply Group Policy changes only after validation.
4.  Replicate and verify changes if additional domain controllers exist.
5.  Record significant directory changes.

## Procedure 3 - Validate Directory Services

1.  Verify domain authentication succeeds.
2.  Confirm DNS name resolution functions correctly.
3.  Verify Group Policy applies successfully.
4.  Confirm client systems can access required network resources.
5.  Update documentation and the changelog.

## Notes

-   Apply the principle of least privilege.
-   Prefer security groups over assigning permissions directly to user
    accounts.
-   Document permanent changes to directory structure, Group Policy, or
    delegated permissions.

## Validation Checklist

-   [ ] Domain Controller healthy
-   [ ] AD DS and DNS operational
-   [ ] Authentication verified
-   [ ] Group Policy validated
-   [ ] Documentation updated
