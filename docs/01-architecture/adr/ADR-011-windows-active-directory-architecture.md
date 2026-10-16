# ADR-0011: Windows Active Directory Architecture

- Status: Accepted
- Date: 2026-07-06
- Related: ADR-0000, ADR-0008, ADR-0009

## Context

Project Polaris requires a production Active Directory environment that supports secure enterprise administration while remaining separate from the future intentionally vulnerable cyber range.

## Decision

Project Polaris will deploy a production Active Directory forest named:

polaris.home.arpa

The production domain will be secure by design. The cyber range will later use a separate, isolated Active Directory forest for offensive and defensive security training.

## Guiding Principle

Production teaches how to build securely.  
The Cyber Range teaches how secure systems fail.

## Production Forest

Forest:
polaris.home.arpa

Domain:
polaris.home.arpa

Forest Functional Level:
Windows Server 2016

Domain Functional Level:
Windows Server 2016

Domain Controller:
dc01

Operating System:
Windows Server 2019 Evaluation

## DNS Model

pfSense remains the DNS server configured on clients.

Active Directory will become authoritative for the AD-integrated polaris.home.arpa zone.

pfSense will forward polaris.home.arpa queries to dc01 after AD DNS is deployed.

## Time Synchronization

Current:

Internet NTP → firewall01 → dc01 → domain members

Future:

Internet NTP → gateway01 → firewall01 → dc01 → domain members

gateway01 is not required before dc01 deployment.

## VM Plan

| VMID | Hostname | Role | OS |
|---:|---|---|---|
| 200 | dc01 | Domain Controller | Windows Server 2019 Evaluation |
| 201 | ws-admin | Privileged Admin Workstation | Windows 11 Pro |
| 202 | ws01 | Windows Workstation | Existing Windows 10 Pro passthrough |
| 203 | ws02 | Windows Workstation | Windows 11 Pro |

## Administrative Model

Separate accounts will be used:

- lab-admin: standard daily-use account
- domain-admin: privileged administration account

Administrative activity should occur from ws-admin.

## Group Strategy

Project Polaris will use AGDLP:

Accounts → Global Groups → Domain Local Groups → Permissions

## Security Baseline

Production AD will use secure defaults:

- Windows Firewall enabled
- Windows Defender enabled
- auditing enabled
- remote administration controlled by GPO
- password complexity enabled
- account lockout enabled

## Password Policy Exception

The primary owner administrative account may be configured with “Password never expires” for lab continuity.

This is a documented exception, not the default standard.

Compensating controls:

- strong unique password
- used only within Polaris
- privileged use limited to ws-admin
- exception reviewed during future hardening milestone

## Cyber Range Separation

The cyber range AD forest will be separate, isolated, and intentionally vulnerable.

No trust relationship will exist between production AD and cyber range AD unless explicitly approved in a future ADR.

## Consequences

Positive:

- realistic enterprise identity design
- secure production domain
- clear cyber range separation
- repeatable rebuild process
- scalable workstation model

Negative:

- additional documentation required
- Windows Server Evaluation requires lifecycle rebuild planning
