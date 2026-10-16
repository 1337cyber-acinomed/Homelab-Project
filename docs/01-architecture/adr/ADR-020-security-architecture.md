# Security Architecture

**Document ID:** ADR-020

**Status:** Accepted

**Date:** 2026-07-31

**Decision Makers:** Project Polaris

------------------------------------------------------------------------

# Context

Project Polaris is designed to provide enterprise-inspired operational
experience while remaining appropriate for a single-node homelab. The
environment must protect production infrastructure, support an isolated
cyber range, and remain recoverable within available hardware and budget
constraints.

------------------------------------------------------------------------

# Problem Statement

Relying on a single security control creates unnecessary risk. The
architecture requires multiple complementary controls that protect
infrastructure, limit the impact of failures, and support secure
administration without introducing unnecessary complexity.

------------------------------------------------------------------------

# Decision

Project Polaris adopts a layered security architecture based on defense
in depth.

The architecture includes:

-   Defense in depth across physical, network, host, application, and
    operational layers.
-   Least-privilege administration for users, services, and
    infrastructure.
-   Layered firewall architecture using gateway01, firewall01, and
    cyber-fw01.
-   Complete isolation of the cyber range from production
    infrastructure.
-   Vaultwarden as the authoritative repository for credentials and
    secrets.
-   SSH key-based administration using Ed25519 keys whenever practical.
-   Internal Certificate Authority (CA) for trusted internal TLS
    services.
-   Tailscale and approved management paths for secure remote
    administration.
-   Security validation following significant infrastructure changes.
-   Disaster recovery integrated into the overall security strategy.

------------------------------------------------------------------------

# Alternatives Considered

## Perimeter Security Only

**Rejected**

Did not provide sufficient protection if an internal system became
compromised.

------------------------------------------------------------------------

## Password-Only Administration

**Rejected**

Provided weaker administrative protection than key-based authentication
and centralized credential management.

------------------------------------------------------------------------

## Flat Trusted Network

**Rejected**

Reduced segmentation and increased the potential impact of compromise.

------------------------------------------------------------------------

# Consequences

## Positive

-   Multiple independent security layers.
-   Reduced attack surface.
-   Improved administrative security.
-   Strong separation between production and cyber-range environments.
-   Better recoverability following security incidents.

## Trade-offs

-   Increased administrative effort.
-   Additional certificate and credential management.
-   More complex firewall and access-control administration.

------------------------------------------------------------------------

# Related Documents

-   SEC-001 Security Overview
-   SEC-002 Identity and Access Management
-   SEC-003 Network Security
-   SEC-004 System Hardening Standards
-   SEC-005 Vulnerability Management
-   SEC-006 Security Monitoring and Logging
-   SEC-007 Secrets and Certificate Management
-   ADR-015 Network Architecture
-   ADR-016 Cyber Range Isolation

------------------------------------------------------------------------

# Revision History

  Version   Date         Description
  --------- ------------ ------------------------------------
  1.0       2026-07-31   Initial Security Architecture ADR.
