---
document:
  id: CMDB-003
  owner: Infrastructure
  status: Production
  title: Configuration Baselines
  version: 3
---

# Configuration Baselines

## Purpose

This document defines the approved baseline configuration standards for
managed Project Polaris assets. Baselines provide a known-good
configuration for deployment, recovery, auditing, and change management.

## Baseline Objectives

-   Ensure consistent deployments
-   Reduce configuration drift
-   Support disaster recovery
-   Simplify troubleshooting
-   Establish repeatable builds

## Physical Infrastructure Baselines

  Asset             Baseline
  ----------------- ----------------------------------------------------
  pve01             Current validated Proxmox production configuration
  nas01             Validated storage and SMB configuration
  switch01          Validated managed switch configuration backup
  NanoStation AP    Validated bridge configuration
  NanoStation STA   Validated bridge configuration

## Virtual Infrastructure Baselines

  Asset        Baseline
  ------------ --------------------------------------------
  gateway01    Approved golden pfSense image
  firewall01   Validated production pfSense configuration
  docker01     Standard Docker host configuration
  admin01      Standard Linux administration workstation
  DC01         Golden Windows Server + AD DS baseline
  Admin-WS     Standard administrative workstation
  WS01         Standard Windows workstation

## Baseline Management Policy

-   Record all approved configuration changes.
-   Capture backups before significant modifications.
-   Validate configuration after maintenance.
-   Update documentation when baselines change.

## Configuration Drift

Configuration drift should be investigated whenever:

-   Unauthorized changes are detected.
-   Backup validation fails.
-   Production behavior differs from the documented baseline.
-   Disaster recovery testing reveals inconsistencies.

## Related Documents

-   cmdb.md
-   asset-standards.md
-   physical-topology.md
-   logical-topology.md

## Revision History

  Version   Date         Notes
  --------- ------------ ------------------------------------------
  3.0       2026-07-31   Initial configuration baseline document.
