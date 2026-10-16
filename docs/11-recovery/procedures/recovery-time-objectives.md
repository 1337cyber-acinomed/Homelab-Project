# Recovery Time Objectives

**Document ID:** DR-004\
**Status:** Validated\
**Version:** 1.0

## Purpose

Define the recovery time objectives (RTO) and recovery point objectives
(RPO) for Project Polaris to establish restoration priorities and
acceptable service interruption targets.

## Scope

Applies to all production infrastructure, core services, and supporting
systems documented within Project Polaris.

## Recovery Objectives

  System / Service              Recovery Priority     Target RTO   Target RPO
  ----------------------------- ------------------- ------------ ------------
  gateway01                     Critical                  1 Hour     24 Hours
  firewall01                    Critical                  1 Hour     24 Hours
  pve01                         Critical                 2 Hours     24 Hours
  NAS01                         Critical                 2 Hours     24 Hours
  DC01 (AD/DNS)                 High                     2 Hours     24 Hours
  docker01                      High                     4 Hours     24 Hours
  Administrative Workstations   Medium                   8 Hours     24 Hours
  Remaining Lab VMs             Medium                  24 Hours     24 Hours

## Recovery Definitions

-   **Recovery Time Objective (RTO):** Maximum acceptable time to
    restore a service after an outage.
-   **Recovery Point Objective (RPO):** Maximum acceptable age of
    recovered data.

## Validation Requirements

-   Verify recovery completes within the defined RTO where practical.
-   Restore from the most recent validated backup.
-   Confirm recovered services function normally before returning them
    to production.
-   Document actual recovery times for future improvement.

## Review Policy

-   Review RTO and RPO targets after significant architectural changes.
-   Update objectives following disaster recovery exercises.
-   Record approved changes in the Disaster Recovery changelog.

## Related Documents

-   dr-overview.md
-   backup-strategy.md
-   recovery-priorities.md
-   service-recovery-procedures.md
-   disaster-recovery-testing.md

## Revision History

  Version   Date         Notes
  --------- ------------ --------------------------------------
  1.0       2026-07-31   Initial recovery objective baseline.
