# Cyber Range Isolation

**Document ID:** ADR-016

**Status:** Accepted

**Date:** 2026-07-31

**Decision Makers:** Project Polaris

------------------------------------------------------------------------

# Context

Project Polaris includes a dedicated cyber range for offensive security,
defensive security, malware analysis, and enterprise security exercises.
These activities require isolation from the production homelab and home
network while remaining flexible enough to support a wide variety of
scenarios.

------------------------------------------------------------------------

# Problem Statement

Cybersecurity testing can introduce malicious software, vulnerable
systems, and intentionally insecure configurations. Without strong
isolation, these workloads could increase risk to production
infrastructure or the home network.

------------------------------------------------------------------------

# Decision

Project Polaris adopts the following cyber range architecture:

-   Deploy a dedicated OPNsense firewall (cyber-fw01) as the security
    boundary.
-   Maintain complete logical isolation from production infrastructure.
-   Treat all cyber range workloads as untrusted by default.
-   Permit Internet access only through the cyber range firewall.
-   Use disposable virtual machines for exercises whenever practical.
-   Retain kali01 as the permanent cyber range management workstation.
-   Permit emergency recovery access only through the approved
    administrative paths.
-   Build enterprise-style segmented environments inside the cyber range
    as required for exercises.

------------------------------------------------------------------------

# Alternatives Considered

## Shared Production Network

**Rejected**

Would unnecessarily increase risk to production systems and reduce
realism.

------------------------------------------------------------------------

## Physically Separate Infrastructure

**Rejected**

Provided excellent isolation but exceeded available hardware and budget.

------------------------------------------------------------------------

## Flat Virtual Network

**Rejected**

Did not adequately simulate enterprise environments or provide
appropriate security boundaries.

------------------------------------------------------------------------

# Consequences

## Positive

-   Strong isolation between production and lab environments.
-   Safe platform for offensive and defensive security exercises.
-   Flexible enterprise network simulation.
-   Reduced risk of accidental impact to production services.
-   Supports repeatable rebuilds using disposable workloads.

## Trade-offs

-   Additional firewall administration.
-   More complex virtual networking.
-   Requires dedicated recovery procedures for the cyber range.

------------------------------------------------------------------------

# Related Documents

-   ADR-015 Network Architecture
-   SEC-003 Network Security
-   DR-005 Service Recovery Procedures
-   Security Documentation Library
-   Logical Infrastructure Library

------------------------------------------------------------------------

# Revision History

  Version   Date         Description
  --------- ------------ ------------------------------------
  1.0       2026-07-31   Initial Cyber Range Isolation ADR.
