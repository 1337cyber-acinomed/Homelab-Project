# Backup Strategy

**Document ID:** DR-002\
**Status:** Validated\
**Version:** 1.0

## Purpose

Define the backup strategy for Project Polaris to ensure production
systems, configurations, and documentation can be recovered following
hardware failure, software failure, accidental deletion, or disaster.

## Scope

This strategy applies to all production infrastructure, including
physical devices, virtual machines, containerized services,
configuration backups, and documentation.

## Backup Objectives

-   Protect critical system configurations and data.
-   Maintain recoverable copies on NAS01.
-   Verify backup integrity after each backup operation.
-   Support disaster recovery and operational continuity.
-   Maintain documented retention policies.

## Backup Architecture

  Asset Type            Backup Method                       Primary Storage
  --------------------- ----------------------------------- -----------------
  Proxmox Host          Configuration export                NAS01
  Virtual Machines      Proxmox backups                     NAS01
  pfSense / gateway01   XML configuration export            NAS01
  Switch01              Configuration export                NAS01
  NanoStation Bridge    Configuration export                NAS01
  Docker Services       Configuration and persistent data   NAS01
  Windows Servers       Manual exports and VM backups       NAS01
  Documentation         Git repository and backup archive   NAS01

## Backup Validation

-   Verify every backup completes successfully.
-   Validate backup integrity before retention processing.
-   Confirm successful transfer to NAS01.
-   Record backup status in collector logs.
-   Investigate and resolve failed validations before closing the backup
    cycle.

## Retention Policy

-   Maintain current production backups.
-   Retain historical backups according to the approved retention
    schedule.
-   Remove expired backups through the automated retention process.
-   Preserve backups required for disaster recovery or investigations.

## Recovery Considerations

-   Restore from the most recent validated backup whenever practical.
-   Verify restored systems before returning them to production.
-   Update documentation after recovery activities.

## Related Documents

-   dr-overview.md
-   recovery-priorities.md
-   recovery-time-objectives.md
-   SOP-006_Backup_and_Restore_Operations.md
-   SOP-012_Disaster_Recovery_Validation.md

## Revision History

  Version   Date         Notes
  --------- ------------ -----------------------------------
  1.0       2026-07-31   Initial backup strategy baseline.
