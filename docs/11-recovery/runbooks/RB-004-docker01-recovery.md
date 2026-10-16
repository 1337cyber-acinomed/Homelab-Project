# docker01 Recovery Runbook

**Document ID:** RB-004

**Version:** 1.0 (Draft)

**Status:** Review

**Owner:** Project Polaris

**Last Updated:** 2026-07-31

------------------------------------------------------------------------

# Purpose

Provide a repeatable procedure for restoring the Project Polaris Docker
host (docker01) and validating all production containerized services
following a virtual machine failure, application failure, or disaster
recovery event.

------------------------------------------------------------------------

# Scope

Applies to recovery of docker01 and all production Docker services
hosted within Project Polaris.

------------------------------------------------------------------------

# Prerequisites

-   pve01 operational.
-   gateway01 and firewall01 fully restored.
-   DC01 operational and DNS functioning.
-   Latest validated docker01 backup available.
-   Access to NAS01 backup repository.
-   Administrative credentials available.

------------------------------------------------------------------------

# Recovery Procedure

## Phase 1 -- Restore Virtual Machine

1.  Restore the docker01 virtual machine.
2.  Verify CPU, memory, storage, and network configuration.
3.  Start the virtual machine.
4.  Confirm network connectivity.

### Validation

-   VM boots successfully.
-   SSH available.
-   Internet connectivity confirmed.

------------------------------------------------------------------------

## Phase 2 -- Restore Docker Environment

1.  Verify Docker Engine status.
2.  Restore Docker configuration if required.
3.  Restore persistent application data.
4.  Confirm Docker Compose files are present.
5.  Start required containers.

### Validation

-   Docker service running.
-   Containers start without errors.
-   Persistent volumes mounted correctly.

------------------------------------------------------------------------

## Phase 3 -- Validate Production Services

Validate each production service:

-   Homepage
-   Vaultwarden
-   Nginx Proxy Manager
-   Forgejo
-   Portainer
-   Uptime Kuma

### Validation

-   Web interfaces accessible.
-   Authentication functioning.
-   No container restart loops.
-   Services communicate correctly.

------------------------------------------------------------------------

## Phase 4 -- Validate Supporting Infrastructure

1.  Verify DNS resolution.
2.  Verify reverse proxy routing.
3.  Verify certificate validity.
4.  Review container logs.
5.  Confirm backup connectivity to NAS01.

### Validation

-   All services reachable.
-   Certificates valid.
-   No critical log errors.

------------------------------------------------------------------------

# Recovery Completion Checklist

-   [ ] docker01 operational
-   [ ] Docker Engine validated
-   [ ] Persistent data restored
-   [ ] Production containers validated
-   [ ] Reverse proxy functioning
-   [ ] Documentation updated
-   [ ] Recovery recorded

------------------------------------------------------------------------

# Related Documents

-   SOP-006 Backup and Restore Operations
-   SOP-008 Docker Services Administration
-   DR-005 Service Recovery Procedures
-   ADR-018 Backup Strategy
-   ADR-020 Security Architecture

------------------------------------------------------------------------

# Revision History

  Version   Date         Description
  --------- ------------ ------------------------------------
  1.0       2026-07-31   Initial docker01 Recovery Runbook.
