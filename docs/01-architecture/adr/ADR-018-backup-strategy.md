# Backup Strategy

**Document ID:** ADR-018

**Status:** Accepted

**Date:** 2026-07-31

**Decision Makers:** Project Polaris

------------------------------------------------------------------------

# Context

Project Polaris must protect critical infrastructure while operating
within limited storage, hardware, and budget. The environment emphasizes
recoverability through documentation, configuration management, and
validated backups rather than indiscriminate backup of every workload.

------------------------------------------------------------------------

# Problem Statement

Applying identical backup policies to every system would consume
unnecessary resources and increase operational overhead. A strategy was
needed to prioritize the systems that provide the greatest recovery
value.

------------------------------------------------------------------------

# Decision

Project Polaris adopts a risk-based backup strategy:

-   Prioritize configuration backups for critical infrastructure.
-   Store validated backups on NAS01 as the primary repository.
-   Classify systems into backup tiers based on operational importance
    and rebuild effort.
-   Require backup validation before considering a backup complete.
-   Automate configuration collection whenever practical.
-   Treat snapshots as temporary recovery aids, not backups.
-   Use disaster recovery exercises to validate backup integrity.

------------------------------------------------------------------------

# Alternatives Considered

## Uniform Backup Schedule

**Rejected**

Created unnecessary storage consumption while providing little
additional recovery value.

------------------------------------------------------------------------

## Virtual Machine Backups Only

**Rejected**

Did not adequately protect critical infrastructure configuration or
documentation.

------------------------------------------------------------------------

## Manual Backups Only

**Rejected**

Increased the likelihood of inconsistent recovery points and operator
error.

------------------------------------------------------------------------

# Consequences

## Positive

-   Efficient storage utilization.
-   Faster recovery of critical infrastructure.
-   Reduced operational overhead through automation.
-   Improved confidence through backup validation.
-   Scalable strategy as the environment grows.

## Trade-offs

-   Different recovery methods exist for different asset classes.
-   Some disposable systems intentionally receive minimal or no
    scheduled backups.
-   Automation requires periodic maintenance.

------------------------------------------------------------------------

# Related Documents

-   GOV-005 Lifecycle Management
-   DR-002 Backup Strategy
-   SOP-006 Backup and Restore Operations
-   GOV-001 Backup Policy
-   Backup Automation Documentation

------------------------------------------------------------------------

# Revision History

  Version   Date         Description
  --------- ------------ ------------------------------
  1.0       2026-07-31   Initial Backup Strategy ADR.
