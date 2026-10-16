# Network Architecture

**Document ID:** ADR-015

**Status:** Accepted

**Date:** 2026-07-31

**Decision Makers:** Project Polaris

------------------------------------------------------------------------

# Context

Project Polaris requires a network architecture that provides
enterprise-style segmentation while remaining simple to operate,
cost-effective, and easily recoverable by a non-expert in the event of a
failure.

------------------------------------------------------------------------

# Problem Statement

A traditional enterprise network design could increase operational
complexity beyond the needs of a single-node homelab. The architecture
must balance security, reliability, recoverability, and budget
constraints while supporting future expansion.

------------------------------------------------------------------------

# Decision

Project Polaris adopts the following network architecture decisions:

-   Maintain a double NAT design for the production environment.
-   Deploy **gateway01** at the network edge to provide enterprise
    firewall capabilities.
-   Use **firewall01** to isolate the homelab production network.
-   Preserve a physical recovery path that requires only moving a single
    Ethernet cable to restore home connectivity.
-   Maintain dedicated management paths for infrastructure
    administration.
-   Separate production infrastructure from the cyber range through
    independent firewall boundaries.

------------------------------------------------------------------------

# Alternatives Considered

## Single Firewall Architecture

**Rejected**

Did not provide the desired separation between the home network and the
production homelab.

------------------------------------------------------------------------

## Enterprise Multi-Firewall Design

**Rejected**

Added unnecessary complexity and hardware cost without proportional
operational benefit.

------------------------------------------------------------------------

## ISP Router Only

**Rejected**

Did not provide the required security controls, segmentation, or
enterprise learning objectives.

------------------------------------------------------------------------

# Consequences

## Positive

-   Simple emergency recovery procedure.
-   Strong separation between home and lab infrastructure.
-   Enterprise firewall experience.
-   Scalable foundation for future expansion.
-   Minimal disruption during maintenance.

## Trade-offs

-   Double NAT remains part of the architecture.
-   Slightly increased routing complexity compared to a flat network.
-   Additional firewall administration required.

------------------------------------------------------------------------

# Related Documents

-   GOV-008 Architecture Governance
-   SEC-003 Network Security
-   DR-003 Recovery Priorities
-   DR-005 Service Recovery Procedures
-   Physical and Logical Infrastructure libraries

------------------------------------------------------------------------

# Revision History

  Version   Date         Description
  --------- ------------ -----------------------------------
  1.0       2026-07-31   Initial Network Architecture ADR.
