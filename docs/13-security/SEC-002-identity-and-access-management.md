# Identity and Access Management

**Document ID:** SEC-002\
**Status:** Validated\
**Version:** 1.0

## Purpose

Define the identity, authentication, authorization, and privileged
access standards used throughout Project Polaris to ensure consistent,
secure administration.

## Scope

Applies to all administrative users, service accounts, infrastructure
platforms, virtual machines, network devices, and applications managed
within Project Polaris.

## Identity Principles

-   Assign a unique identity to every administrator.
-   Grant only the permissions required to perform assigned duties.
-   Separate standard user activities from privileged administration
    whenever practical.
-   Disable or remove unused accounts promptly.
-   Review privileged access on a recurring basis.

## Authentication Standards

  -----------------------------------------------------------------------
  Control                             Standard
  ----------------------------------- -----------------------------------
  Passwords                           Strong, unique passwords stored in
                                      Vaultwarden

  Multi-Factor Authentication         Enabled wherever supported

  SSH Authentication                  Ed25519 keys preferred; password
                                      login disabled when practical

  Administrative Accounts             Dedicated privileged accounts for
                                      administration

  Service Accounts                    Limited to required permissions and
                                      documented ownership
  -----------------------------------------------------------------------

## Authorization Standards

-   Apply least privilege by default.
-   Use role-based access whenever supported.
-   Restrict firewall and infrastructure administration to authorized
    administrators.
-   Limit remote administrative access to approved management paths.

## Credential Management

-   Store infrastructure credentials in Vaultwarden.
-   Protect private SSH keys with passphrases where practical.
-   Rotate credentials after suspected compromise or significant
    personnel changes.
-   Never store plaintext passwords in documentation or repositories.

## Remote Administration

-   Prefer secure management networks or VPN/Tailscale access.
-   Use HTTPS, SSH, or other encrypted management protocols.
-   Disable insecure legacy protocols unless specifically required for
    testing.

## Account Lifecycle

1.  Create and document the account.
2.  Assign minimum required permissions.
3.  Validate successful authentication.
4.  Periodically review permissions.
5.  Disable or remove accounts no longer required.

## Compliance and Review

-   Validate access after major infrastructure changes.
-   Audit privileged accounts periodically.
-   Document exceptions and compensating controls.

## Related Documents

-   SEC-001 Security Overview
-   SEC-003 Network Security
-   SEC-007 Secrets and Certificate Management
-   SOP-007 pfSense Firewall Administration
-   SOP-011 Incident Response

## Revision History

  Version   Date         Notes
  --------- ------------ --------------------------------------------------
  1.0       2026-07-31   Initial Identity and Access Management baseline.
