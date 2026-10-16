# Recovery Priorities

**Document ID:** DR-003\
**Status:** Validated\
**Version:** 1.0

## Purpose

Define the recovery order for Project Polaris infrastructure to ensure
critical services are restored in the proper sequence and dependencies
are respected.

## Scope

Applies to recovery of all production infrastructure following a partial
or complete outage.

## Recovery Tiers

  Tier     Systems                                         Priority
  -------- ----------------------------------------------- ----------
  Tier 1   Power, networking, NAS01                        Critical
  Tier 2   gateway01, firewall01, pve01                    Critical
  Tier 3   DC01 (AD/DNS), core infrastructure              High
  Tier 4   docker01 and management services                High
  Tier 5   Administrative workstations and remaining VMs   Medium

## Recovery Sequence

1.  Verify power and physical connectivity.
2.  Restore core network infrastructure.
3.  Restore gateway01 and firewall01.
4.  Restore the Proxmox host (pve01).
5.  Verify access to backup storage (NAS01).
6.  Restore Active Directory and DNS (DC01).
7.  Restore Docker host (docker01) and hosted applications.
8.  Restore administrative workstations and remaining virtual machines.
9.  Validate all dependent services.
10. Update documentation and record recovery actions.

## Dependency Considerations

-   Restore parent infrastructure before dependent services.
-   Validate each tier before proceeding.
-   Do not restore application services before identity and networking
    are operational.
-   Preserve recovery logs for post-incident review.

## Success Criteria

-   All production infrastructure is operational.
-   Authentication and DNS function normally.
-   Critical applications are accessible.
-   Monitoring reports healthy status.
-   Documentation reflects the completed recovery.

## Related Documents

-   dr-overview.md
-   backup-strategy.md
-   recovery-time-objectives.md
-   service-recovery-procedures.md
-   SOP-012_Disaster_Recovery_Validation.md

## Revision History

  Version   Date         Notes
  --------- ------------ ---------------------------------------
  1.0       2026-07-31   Initial recovery priorities baseline.
