# SOP-007: pfSense Firewall Administration

**Document ID:** SOP-007\
**Status:** Validated\
**Version:** 1.0

## Purpose

Provide repeatable procedures for administering the Project Polaris
pfSense firewalls while maintaining secure and reliable network
operations.

## Prerequisites

-   Perform administration from an authorized management workstation.
-   Administrative access to the pfSense web interface.
-   Verify a current configuration backup exists before making changes.
-   Schedule production changes during an approved maintenance window.

## Procedure 1 - Verify Firewall Health

1.  Log in to the pfSense web interface.
2.  Review the dashboard for system alerts.
3.  Verify WAN and LAN interfaces are online.
4.  Confirm CPU, memory, and storage utilization are within normal
    limits.
5.  Review recent system logs for errors.

## Procedure 2 - Perform Configuration Changes

1.  Verify the requested change has been approved.
2.  Export a current configuration backup.
3.  Apply the approved configuration change.
4.  Save and apply the configuration.
5.  Verify interfaces and services return to normal operation.

## Procedure 3 - Validate Firewall Operation

1.  Confirm client connectivity through the firewall.
2.  Verify DNS and DHCP services are functioning as expected.
3.  Review firewall logs for unexpected blocks or errors.
4.  Execute the configuration backup collector if applicable.
5.  Update documentation and the changelog.

## Notes

-   Always retain a current XML configuration backup before significant
    changes.
-   Minimize production disruption by batching related changes into a
    single maintenance window.
-   Document all permanent firewall rule or interface modifications.

## Validation Checklist

-   [ ] Firewall healthy
-   [ ] Configuration backup completed
-   [ ] Changes applied successfully
-   [ ] Client connectivity verified
-   [ ] Services validated
-   [ ] Documentation updated
