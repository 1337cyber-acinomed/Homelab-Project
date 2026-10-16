# Service Recovery Procedures

**Document ID:** DR-005\
**Status:** Validated\
**Version:** 1.0

## Purpose

Provide a high-level, repeatable sequence for restoring Project Polaris
production services following a partial or complete infrastructure
failure.

## Scope

Applies to recovery of all production infrastructure, virtual machines,
and supporting services.

## Recovery Sequence

### Stage 1 - Physical Infrastructure

1.  Verify electrical power is stable.
2.  Restore ISP connectivity.
3.  Verify switch01 and NanoStation bridge operation.
4.  Confirm NAS01 is available.

### Stage 2 - Network Infrastructure

1.  Restore gateway01.
2.  Restore firewall01.
3.  Verify WAN and LAN connectivity.
4.  Confirm DNS forwarding and Internet access.

### Stage 3 - Virtualization Platform

1.  Start pve01.
2.  Verify storage availability.
3.  Confirm networking and cluster services (if applicable).

### Stage 4 - Core Infrastructure Services

1.  Restore DC01.
2.  Verify Active Directory.
3.  Verify DNS resolution.
4.  Confirm authentication is functioning.

### Stage 5 - Application Services

1.  Restore docker01.
2.  Verify Homepage.
3.  Verify Vaultwarden.
4.  Verify Nginx Proxy Manager.
5.  Verify Forgejo.
6.  Verify Portainer.
7.  Verify Uptime Kuma.

### Stage 6 - Administrative Systems

1.  Restore Admin-WS.
2.  Restore remaining production virtual machines.
3.  Restore remaining lab systems as required.

## Validation

-   Verify client connectivity.
-   Confirm DNS resolution.
-   Verify authentication.
-   Confirm critical applications are accessible.
-   Review system logs for errors.
-   Confirm monitoring reports healthy status.

## Notes

-   Restore systems in dependency order.
-   Do not continue to the next stage until the current stage has been
    validated.
-   Record deviations encountered during recovery.
-   Update documentation following recovery.

## Related Documents

-   dr-overview.md
-   backup-strategy.md
-   recovery-priorities.md
-   recovery-time-objectives.md
-   disaster-recovery-testing.md
-   SOP-006_Backup_and_Restore_Operations.md
-   SOP-012_Disaster_Recovery_Validation.md

## Revision History

  Version   Date         Notes
  --------- ------------ ----------------------------------------------
  1.0       2026-07-31   Initial service recovery procedure baseline.
