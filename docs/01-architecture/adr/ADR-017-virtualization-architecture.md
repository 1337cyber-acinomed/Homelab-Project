# Virtualization Architecture

**Document ID:** ADR-017

**Status:** Accepted

**Date:** 2026-07-31

**Decision Makers:** Project Polaris

------------------------------------------------------------------------

# Context

Project Polaris is built on a single Proxmox Virtual Environment host
that must support production infrastructure, enterprise services, and an
isolated cyber range while operating within hardware and budget
constraints.

------------------------------------------------------------------------

# Problem Statement

The virtualization platform must provide enterprise operational
experience without introducing unnecessary complexity or hardware
requirements. The architecture must remain reproducible, recoverable,
and scalable as additional resources become available.

------------------------------------------------------------------------

# Decision

Project Polaris adopts the following virtualization architecture:

-   Use a single Proxmox VE host as the primary virtualization platform.
-   Organize virtual machines using functional VMID ranges (100-, 200-,
    300-, and 400-series).
-   Build production systems from approved golden templates whenever
    practical.
-   Maintain separate Windows and Linux administrative platforms.
-   Allocate resources according to operational priority rather than
    equal distribution.
-   Preserve snapshots and validated backups before significant changes.
-   Design workloads so production infrastructure and cyber range remain
    logically separated.

------------------------------------------------------------------------

# Alternatives Considered

## Multi-Node Cluster

**Rejected**

Exceeded current hardware availability and operational requirements.

------------------------------------------------------------------------

## Physical Servers for Each Service

**Rejected**

Increased cost, power consumption, and management overhead.

------------------------------------------------------------------------

## Ad Hoc Virtual Machine Deployment

**Rejected**

Reduced consistency, recoverability, and documentation quality.

------------------------------------------------------------------------

# Consequences

## Positive

-   Efficient hardware utilization.
-   Consistent VM deployment.
-   Simplified backup and recovery.
-   Clear workload organization.
-   Enterprise-inspired administration within budget.

## Trade-offs

-   Single host represents a single point of failure.
-   Available compute resources must be shared.
-   Cluster functionality deferred until future expansion.

------------------------------------------------------------------------

# Related Documents

-   ADR-014 Enterprise Design Philosophy
-   ADR-015 Network Architecture
-   GOV-005 Lifecycle Management
-   SOP-004 Proxmox Host Administration
-   SOP-005 Virtual Machine Lifecycle Management
-   Physical Infrastructure Library
-   Logical Infrastructure Library

------------------------------------------------------------------------

# Revision History

  Version   Date         Description
  --------- ------------ ------------------------------------------
  1.0       2026-07-31   Initial Virtualization Architecture ADR.
