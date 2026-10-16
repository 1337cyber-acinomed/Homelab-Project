---
document:
  id: CMDB-002
  owner: Infrastructure
  status: Production
  title: Asset Standards
  version: 3
---

# Asset Standards

## Purpose

This document defines the standards used when creating, naming,
documenting, and managing assets within Project Polaris. It ensures
consistency across physical devices, virtual machines, services, and
future infrastructure.

## Naming Standards

  Asset Type             Standard     Example
  ---------------------- ------------ ------------
  Proxmox Host           pve##        pve01
  NAS                    nas##        nas01
  Switch                 switch##     switch01
  Firewall               firewall##   firewall01
  Gateway                gateway##    gateway01
  Windows Server         ROLE##       DC01
  Windows Workstation    WS##         WS01
  Linux Administration   admin##      admin01
  Docker Host            docker##     docker01

## Asset Requirements

Every managed asset shall have:

-   Unique hostname
-   Assigned owner
-   Documented purpose
-   Lifecycle state
-   Backup strategy
-   Monitoring status
-   Recovery procedure
-   Cross-reference to related documentation

## Lifecycle States

  State         Description
  ------------- ------------------------------------------
  Planned       Approved but not deployed
  Build         Being configured
  Testing       Under validation
  Production    Operational
  Maintenance   Temporarily unavailable for planned work
  Retired       Removed from service

## Documentation Requirements

Each asset must include:

-   Physical or virtual location
-   Network information
-   Dependencies
-   Criticality
-   Configuration baseline
-   Change history

## Related Documents

-   cmdb.md
-   physical-topology.md
-   logical-topology.md

## Revision History

  Version   Date         Notes
  --------- ------------ -----------------------------------
  3.0       2026-07-31   Initial asset standards baseline.
