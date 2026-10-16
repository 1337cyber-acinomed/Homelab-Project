# Naming Standards

**Document ID:** GOV-003

**Version:** 1.0 (Draft)

**Status:** Review

**Owner:** Project Polaris

**Last Updated:** 2026-07-31

------------------------------------------------------------------------

# Purpose

This standard establishes the naming conventions used throughout Project
Polaris to ensure consistency, predictability, and maintainability
across infrastructure, services, documentation, and future expansion.

Consistent naming improves administration, automation, troubleshooting,
documentation, and disaster recovery.

------------------------------------------------------------------------

# Guiding Principles

Project Polaris naming standards follow these principles:

-   Consistency over convenience.
-   Names should clearly describe purpose.
-   Abbreviations shall remain standardized.
-   Hostnames shall remain stable throughout the asset lifecycle.
-   Documentation shall use the same names as production infrastructure.

------------------------------------------------------------------------

# Infrastructure Naming

## Physical Infrastructure

  Asset Type            Standard          Example
  --------------------- ----------------- -----------------
  Proxmox Host          pve##             pve01
  NAS                   nas##             nas01
  Switch                switch##          switch01
  Wireless Bridge AP    nanostation-ap    nanostation-ap
  Wireless Bridge STA   nanostation-sta   nanostation-sta

------------------------------------------------------------------------

## Network Infrastructure

  Asset Type          Standard     Example
  ------------------- ------------ ------------
  Edge Firewall       gateway##    gateway01
  Internal Firewall   firewall##   firewall01
  Cyber Firewall      cyber-fw##   cyber-fw01

------------------------------------------------------------------------

## Windows Infrastructure

  Asset Type                   Standard   Example
  ---------------------------- ---------- ----------
  Domain Controller            DC##       DC01
  Certificate Authority        CA##       CA01
  Administrative Workstation   Admin-WS   Admin-WS
  Standard Workstation         WS##       WS01

------------------------------------------------------------------------

## Linux Infrastructure

  Asset Type                   Standard   Example
  ---------------------------- ---------- ----------
  Docker Host                  docker##   docker01
  Administrative Workstation   admin##    admin01
  Kali Management              kali##     kali01

------------------------------------------------------------------------

## Virtual Machines

-   Approved VMIDs shall be used.
-   VM names shall match documentation and DNS.
-   Templates should include "-GOLD" when applicable.

------------------------------------------------------------------------

## Documentation

  Document Type                  Prefix
  ------------------------------ ---------
  Standard Operating Procedure   SOP-###
  Disaster Recovery              DR-###
  Security                       SEC-###
  Governance                     GOV-###
  Architecture Decision Record   ADR-###

------------------------------------------------------------------------

## Git Repositories

-   Repository names shall use lowercase with hyphens.
-   Repository names should describe a single project or purpose.

------------------------------------------------------------------------

## DNS

-   Hostnames shall use lowercase.
-   Production systems shall receive static DNS records.
-   Internal FQDNs shall use the approved internal domain.

------------------------------------------------------------------------

## Future Expansion

New naming conventions shall remain compatible with the existing
standards and should avoid introducing duplicate or conflicting
prefixes.

------------------------------------------------------------------------

# Periodic Review

This standard shall be reviewed:

-   Following major infrastructure additions.
-   After architectural changes.
-   Before introducing new infrastructure classes.
-   At least annually.

------------------------------------------------------------------------

# Revision History

  ------------------------------------------------------------------------
  Version    Date         Description
  ---------- ------------ ------------------------------------------------
  1.0        2026-07-31   Initial Naming Standards for Project Polaris.

  ------------------------------------------------------------------------
