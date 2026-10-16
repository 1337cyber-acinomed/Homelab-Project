# SOP-008: Docker Services Administration

**Document ID:** SOP-008\
**Status:** Validated\
**Version:** 1.0

## Purpose

Provide repeatable procedures for administering Docker services hosted
within Project Polaris while maintaining service availability and
configuration consistency.

## Prerequisites

-   Perform administration from an authorized management workstation.
-   Administrative access to docker01.
-   SSH access or Portainer available.
-   Verify a current backup exists before making significant changes.

## Procedure 1 - Verify Docker Host Health

1.  Log in to docker01.
2.  Verify the Docker service is running.
3.  Review CPU, memory, and disk utilization.
4.  Confirm required containers are running.
5.  Review container logs for unexpected errors.

## Procedure 2 - Deploy or Update a Container

1.  Verify the requested change has been approved.
2.  Create or verify a current backup of persistent application data.
3.  Deploy or update the container using the approved configuration.
4.  Confirm the container starts successfully.
5.  Verify application connectivity and functionality.

## Procedure 3 - Validate Hosted Services

1.  Verify Homepage loads correctly.
2.  Verify Vaultwarden is accessible.
3.  Verify Nginx Proxy Manager is operational.
4.  Verify Forgejo, Portainer, and Uptime Kuma are functioning normally.
5.  Update documentation and the changelog if configuration changes were
    made.

## Notes

-   Use persistent volumes for application data.
-   Maintain configuration consistency across container updates.
-   Document all permanent service additions, removals, and
    configuration changes.

## Validation Checklist

-   [ ] Docker service healthy
-   [ ] Required containers running
-   [ ] Hosted applications validated
-   [ ] Backup verified
-   [ ] Configuration changes documented
-   [ ] Documentation updated
