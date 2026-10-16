# System Hardening Standards

**Document ID:** SEC-004\
**Status:** Validated\
**Version:** 1.0

## Purpose

Establish baseline hardening requirements for operating systems,
virtualization platforms, network appliances, and application hosts
within Project Polaris. These standards reduce the attack surface while
maintaining operational stability.

## Scope

Applies to Proxmox hosts, pfSense firewalls, Windows Server, Windows
workstations, Ubuntu systems, Docker hosts, and future production
infrastructure.

## Hardening Principles

-   Secure systems before exposing services.
-   Remove or disable unnecessary software and services.
-   Keep systems current with security updates.
-   Encrypt administrative communications.
-   Validate functionality after every hardening change.
-   Document approved deviations from the baseline.

## Platform Baselines

### Proxmox VE

-   Install supported software versions.
-   Restrict administrative access to authorized users.
-   Use HTTPS for web administration.
-   Keep host packages updated.
-   Protect SSH using key-based authentication where practical.
-   Back up host configuration regularly.

### pfSense

-   Change all default credentials.
-   Limit administrative access to trusted management networks.
-   Use HTTPS exclusively for web management.
-   Enable automatic configuration backups where appropriate.
-   Review firewall rules after significant changes.
-   Maintain current firmware and package versions.

### Windows Server

-   Join production systems to Active Directory when applicable.
-   Apply current security updates.
-   Enable Windows Defender Firewall.
-   Remove unused roles and features.
-   Restrict local administrator usage.
-   Audit privileged account activity.

### Windows Workstations

-   Enable automatic security updates.
-   Use Microsoft Defender or equivalent protection.
-   Remove unnecessary software.
-   Operate daily activities as a standard user whenever practical.
-   Lock systems automatically after inactivity.

### Ubuntu Servers

-   Apply security updates regularly.
-   Disable unused services.
-   Restrict SSH access to authorized administrators.
-   Prefer SSH keys over passwords.
-   Enable host firewall rules appropriate to the workload.

### Docker Hosts

-   Deploy only required containers.
-   Keep container images current.
-   Remove unused images and volumes.
-   Limit container privileges.
-   Store persistent data outside container filesystems.
-   Back up application data routinely.

## Validation Checklist

-   Security updates installed.
-   Default credentials removed.
-   Unnecessary services disabled.
-   Administrative access validated.
-   System functionality verified.
-   Backups completed successfully.

## Exception Management

Any deviation from these standards must be documented, include a
business or technical justification, identify compensating controls, and
be reviewed during future security assessments.

## Related Documents

-   SEC-001 Security Overview
-   SEC-002 Identity and Access Management
-   SEC-003 Network Security
-   SEC-005 Vulnerability Management
-   SOP-007 pfSense Firewall Administration
-   SOP-011 Incident Response

## Revision History

  Version   Date         Notes
  --------- ------------ ----------------------------------------------
  1.0       2026-07-31   Initial system hardening standards baseline.
