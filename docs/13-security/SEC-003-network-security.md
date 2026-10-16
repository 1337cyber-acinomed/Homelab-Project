# Network Security

**Document ID:** SEC-003\
**Status:** Validated\
**Version:** 1.0

## Purpose

Define the network security architecture, segmentation strategy, remote
access standards, and administrative controls used throughout Project
Polaris.

## Scope

Applies to all physical networking equipment, firewalls, virtual
networking, switches, wireless bridges, VPN connectivity, and management
interfaces.

## Network Security Objectives

-   Protect internal resources from unauthorized access.
-   Separate trusted, management, production, and future lab
    environments.
-   Minimize exposed services.
-   Encrypt all administrative traffic.
-   Validate network security after configuration changes.

## Network Architecture

  -----------------------------------------------------------------------
  Layer                               Primary Controls
  ----------------------------------- -----------------------------------
  Edge                                ISP connection, gateway firewall

  Internal Perimeter                  pfSense firewall, VLANs/subnets,
                                      ACLs

  Management                          Restricted administrative access,
                                      HTTPS, SSH, Tailscale

  Wireless                            WPA security, Ubiquiti bridge,
                                      hidden infrastructure where
                                      practical

  Virtual                             Proxmox bridges, isolated virtual
                                      networks
  -----------------------------------------------------------------------

## Segmentation Standards

-   Separate WAN and LAN networks.
-   Isolate administrative interfaces from general client access
    whenever practical.
-   Maintain logical separation between production infrastructure and
    future cyber-range resources.
-   Restrict inter-network communication to documented business
    requirements.

## Firewall Standards

-   Default-deny approach for inbound traffic.
-   Permit only required services.
-   Review firewall rules after significant infrastructure changes.
-   Document all non-standard exceptions.

## Remote Administration

-   Prefer Tailscale or trusted management networks for remote access.
-   Use HTTPS for web administration.
-   Use SSH with Ed25519 keys where supported.
-   Disable insecure management protocols unless required for testing.

## Network Monitoring

-   Monitor firewall health and connectivity.
-   Validate DNS and gateway functionality after changes.
-   Review logs for failed administrative access and abnormal network
    activity.

## Validation Checklist

-   Firewall rules reviewed.
-   Remote administration verified.
-   DNS resolution validated.
-   Required services reachable.
-   Unnecessary exposed services removed.

## Related Documents

-   SEC-001 Security Overview
-   SEC-002 Identity and Access Management
-   SEC-004 System Hardening Standards
-   SOP-007 pfSense Firewall Administration
-   DR-005 Service Recovery Procedures

## Revision History

  Version   Date         Notes
  --------- ------------ ------------------------------------
  1.0       2026-07-31   Initial network security baseline.
