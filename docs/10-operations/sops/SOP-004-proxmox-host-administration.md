# SOP-004: Proxmox Host Administration

**Document ID:** SOP-004\
**Status:** Validated\
**Version:** 1.0

## Purpose

Provide repeatable procedures for safely administering the Project
Polaris Proxmox host while maintaining production stability.

## Prerequisites

-   Perform administration from an authorized management workstation.
-   Administrative access to the Proxmox web interface.
-   SSH access available if required.
-   Verify current backups before making significant configuration
    changes.

## Procedure 1 - Verify Host Health

1.  Log in to the Proxmox web interface.
2.  Confirm the node is online.
3.  Review CPU, memory, and storage utilization.
4.  Verify all required storage is mounted.
5.  Confirm no critical system alerts are present.

## Procedure 2 - Verify Virtual Machine Status

1.  Review all production virtual machines.
2.  Confirm required services are running.
3.  Investigate unexpected stopped or paused virtual machines.
4.  Review recent task history for failures.

## Procedure 3 - Perform Maintenance

1.  Schedule maintenance during an approved maintenance window.
2.  Verify backups have completed successfully.
3.  Perform the required administrative task.
4.  Validate system operation after completion.
5.  Update the applicable documentation and changelog.

## Notes

-   Avoid unnecessary host reboots.
-   Validate production services before ending maintenance.
-   Follow the Change Management process for significant infrastructure
    modifications.

## Validation Checklist

-   [ ] Host healthy
-   [ ] Storage available
-   [ ] Production VMs verified
-   [ ] Maintenance completed
-   [ ] Services validated
-   [ ] Documentation updated
