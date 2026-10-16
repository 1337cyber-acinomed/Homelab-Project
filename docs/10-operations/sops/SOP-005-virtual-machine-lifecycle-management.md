# SOP-005: Virtual Machine Lifecycle Management

**Document ID:** SOP-005\
**Status:** Validated\
**Version:** 1.0

## Purpose

Provide repeatable procedures for creating, modifying, validating, and
retiring virtual machines within the Project Polaris Proxmox
environment.

## Prerequisites

-   Perform administration from an authorized management workstation.
-   Administrative access to the Proxmox web interface.
-   Verify sufficient CPU, memory, and storage resources.
-   Verify current backups before modifying production virtual machines.

## Procedure 1 - Create a Virtual Machine

1.  Create the virtual machine using the approved naming convention.
2.  Assign the approved VMID.
3.  Configure CPU, memory, storage, and network interfaces.
4.  Install the operating system or deploy from an approved template.
5.  Perform initial configuration.
6.  Verify successful boot.

## Procedure 2 - Modify a Virtual Machine

1.  Verify a current backup exists.
2.  Shut down the virtual machine if required.
3.  Apply the approved configuration changes.
4.  Restart the virtual machine.
5.  Validate all services are functioning correctly.

## Procedure 3 - Retire a Virtual Machine

1.  Confirm the virtual machine is no longer required.
2.  Create a final backup if appropriate.
3.  Export or preserve required data.
4.  Remove the virtual machine from Proxmox.
5.  Update the CMDB and related documentation.

## Notes

-   Use approved templates whenever possible.
-   Follow the established VM numbering standards.
-   Document significant lifecycle changes in the appropriate changelog.

## Validation Checklist

-   [ ] VM created or modified successfully
-   [ ] Configuration validated
-   [ ] Services operating normally
-   [ ] Required backups verified
-   [ ] Documentation updated
