# Secrets and Certificate Management

**Document ID:** SEC-007\
**Status:** Validated\
**Version:** 1.0

## Purpose

Define the standards for managing credentials, cryptographic keys,
certificates, and other sensitive secrets within Project Polaris to
ensure confidentiality, integrity, and recoverability.

## Scope

Applies to all production infrastructure, network devices, virtual
machines, applications, service accounts, SSH keys, TLS certificates,
and internal Certificate Authority (CA) assets.

## Objectives

-   Protect sensitive credentials from unauthorized access.
-   Centralize credential management.
-   Maintain secure certificate lifecycle management.
-   Support rapid recovery following credential compromise.
-   Document ownership and rotation requirements.

## Secrets Management

  -----------------------------------------------------------------------
  Secret Type                         Standard
  ----------------------------------- -----------------------------------
  Administrative Credentials          Store in Vaultwarden

  Service Account Credentials         Document owner and purpose

  API Keys                            Store securely; never embed in
                                      documentation or repositories

  Recovery Codes                      Store in Vaultwarden and protect
                                      appropriately

  Encryption Keys                     Back up securely and restrict
                                      access
  -----------------------------------------------------------------------

## SSH Key Management

-   Prefer Ed25519 key pairs.
-   Protect private keys with passphrases where practical.
-   Disable password authentication where supported.
-   Remove unused or compromised keys promptly.
-   Document authorized administrative keys.

## Certificate Management

-   Use the internal Certificate Authority for trusted internal
    services.
-   Track certificate ownership and expiration dates.
-   Renew certificates before expiration.
-   Revoke compromised certificates immediately.
-   Protect CA private keys with restricted access and verified backups.

## Credential Rotation

-   Rotate credentials after suspected compromise.
-   Rotate shared administrative credentials after significant personnel
    changes.
-   Replace default credentials during initial deployment.
-   Validate service functionality after credential updates.

## Validation Checklist

-   Vaultwarden entries current.
-   SSH keys reviewed.
-   Certificates valid and not nearing expiration.
-   CA backups verified.
-   Credential rotation documented where applicable.

## Related Documents

-   SEC-001 Security Overview
-   SEC-002 Identity and Access Management
-   SEC-006 Security Monitoring and Logging
-   SOP-006 Backup and Restore Operations
-   DR-002 Backup Strategy

## Revision History

  Version   Date         Notes
  --------- ------------ ------------------------------------------------------
  1.0       2026-07-31   Initial secrets and certificate management baseline.
