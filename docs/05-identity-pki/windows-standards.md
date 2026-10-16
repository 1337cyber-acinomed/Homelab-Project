# Windows Standards

## VM Plan

| VMID | Hostname | Role | OS |
|---:|---|---|---|
| 200 | dc01 | Domain Controller | Windows Server 2019 Evaluation |
| 201 | ws-admin | Privileged Admin Workstation | Windows 11 Pro |
| 202 | ws01 | Windows Workstation | Windows 10 Pro passthrough |
| 203 | ws02 | Windows Workstation | Windows 11 Pro |

## Golden Image Strategy

Build Windows Server 2019 Evaluation as a clean template before AD promotion.

Golden image includes:

- updates
- QEMU guest agent
- baseline configuration
- static networking preparation
- no AD DS role installed

## Baseline Security

Enabled:

- Windows Defender
- Windows Firewall
- auditing
- complexity requirements
- account lockout

Initial password policy:

- minimum length: 14
- complexity: enabled
- history: 24
- maximum age: 365 days
- minimum age: 1 day
- reversible encryption: disabled

Documented exception:

Primary owner administrative account may be set to password never expires.

## GPO Baseline

Initial GPOs:

- Default Domain Policy
- Domain Controller Baseline
- Admin Workstation Baseline
- Standard Workstation Baseline
- Server Baseline Policy

## PKI

Do not deploy AD CS during initial AD deployment.

Reserve ca01 for a future milestone.

## Installation Media

Operating System:
Windows Server 2019 Evaluation (Desktop Experience)

Purpose:
Golden Image Template

Source:
Microsoft Evaluation Center

Status:
Uploaded to Proxmox ISO storage

Checksum:
(Optional)
