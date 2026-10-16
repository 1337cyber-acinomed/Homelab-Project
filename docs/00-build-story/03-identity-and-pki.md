# Chapter 3 — Identity and PKI (July – August 2026)

## Goal

A real Windows enterprise core: an Active Directory forest with a tiered administration model, a Group Policy baseline, and a **two-tier PKI** with an offline root. Everything had to be recoverable.

## What I built

| Component | Result |
|---|---|
| `dc01` (VM 200) | Sole DC, DNS, global catalog and FSMO holder for `ad.polaris`. Recycle Bin enabled |
| Directory | Protected OU baseline, group and delegation model, privileged access model with an explicit break-glass boundary |
| Group Policy | Eight-GPO authoritative inventory, a six-setting computer baseline, domain account policy |
| PKI | **ROOTCA01**, an offline standalone root (`Polaris Root CA`, built from a hardened `CAPolicy.inf`), and **CA01**, the enterprise subordinate (`Polaris Issuing CA`). Admin-WS enrolled a machine certificate as acceptance proof |
| Admin | `Admin-WS` Windows admin workstation; `WS01`/`WS02` user workstations |
| Recovery | System State backups to the NAS, protected VM backups, gold images (`DC01-Gold`, `ROOTCA01-GOLD`), a recovery order and RB-005/RB-006 recovery runbooks |

Milestones: **RB-010 ROOTCA01 recovery and implementation closed 13 Aug 2026**, and the **AD milestone was accepted and frozen 15 Aug 2026** after five-system validation gates.

## Problems and decisions

- **ROOTCA01 had to be rebuilt.** RB-010 documents recovering the offline root, moving public artifacts (certificate and CRL) through Admin-WS to CA01 and DC01, and the final acceptance test. A proposal to "re-transport artifacts" at step 5.8 was rejected because transport was already done; the step was redefined as final acceptance validation. That is a small example of not repeating frozen work.
- **Accepted exceptions, written down.** One DC, 12-character minimum passwords with no expiry, and one admin account administering all tiers were accepted as personal-lab exceptions, each with a recorded compensating control.
- **Service accounts with least privilege.** The config-backup collector for Admin-WS moved from the domain admin account to a dedicated non-administrator local account (`polaris-admws-backup`). That required resolving WMI, SCM and DISM permission gaps one at a time.

## Skills demonstrated

Active Directory design and administration, DNS for AD, Group Policy, Microsoft ADCS two-tier PKI (offline root, CAPolicy.inf, CRL/AIA distribution), PowerShell, privileged-access tiering, Windows backup and recovery.

## Records

[AD design](../05-identity-pki/active-directory-design.md) · [Privileged access model](../05-identity-pki/privileged-access-model.md) · [AD milestone closeout](../05-identity-pki/active-directory-milestone-closeout-v1.0.md) · [PKI-001 architecture](../05-identity-pki/PKI-001-pki-architecture.md) · [RB-010 runbook](../05-identity-pki/RB-010-rootca01-recovery-and-implementation.md) · [RB-010 closeout](../05-identity-pki/RB-010-rootca01-closeout-v1.0.md) · [CAPolicy.inf](../../code/pki/CAPolicy.inf)
