# ADR-000: Project Polaris Architectural Charter

- **Status:** Accepted
- **Date:** 2026-07-06
- **Authors:** Jesse Breedlove / Project Polaris
- **Supersedes:** None
- **Superseded By:** None

---

# 1. Purpose

This Architectural Decision Record establishes the long-term vision, guiding principles, and architectural standards for Project Polaris.

The purpose of this document is to ensure every future architectural decision, technology selection, implementation, and roadmap adjustment directly supports the final intended architecture.

This document serves as the authoritative reference for all future ADRs.

---

# 2. Mission Statement

Project Polaris exists to build a secure, enterprise-grade production homelab that supports real services while maintaining a completely isolated cyber range capable of simulating offensive, defensive, and enterprise security operations.

The project emphasizes engineering discipline, documentation, recoverability, security, automation, and continuous learning through practical implementation.

---

# 3. Vision

Project Polaris is not intended to become simply a virtualization server or home laboratory.

The final objective is to build a complete enterprise simulation platform that includes:

- Production infrastructure
- Enterprise identity management
- Secure networking
- Enterprise monitoring
- Backup and disaster recovery
- Automation
- Offensive security
- Defensive security
- Threat hunting
- Purple team operations
- Artificial Intelligence integration

while maintaining complete separation between production services and offensive testing environments.

---

# 4. Guiding Principles

## 4.1 Production First

Production services always take priority over experimentation.

Production systems shall:

- remain stable
- remain documented
- remain backed up
- remain recoverable
- follow enterprise best practices

---

## 4.2 Cyber Range is Disposable

The cyber range exists for learning.

Any component inside the cyber range should be capable of complete destruction and rebuilding without impacting production services.

The cyber range is assumed hostile by design.

---

## 4.3 Documentation First

Every major implementation shall be documented before it is considered complete.

Documentation includes:

- ADRs
- Build Guides
- Recovery Guides
- Troubleshooting
- Hardware Inventory
- Network Documentation
- Backup Documentation

---

## 4.4 Recovery Before Expansion

Every major infrastructure component must have a documented recovery procedure before additional dependencies are added.

Examples include:

- firewall recovery
- DNS recovery
- NAS recovery
- VM recovery
- backup validation

---

## 4.5 Enterprise Simplicity

When multiple valid solutions exist, the preferred solution shall be the one that most closely resembles enterprise best practices while minimizing unnecessary complexity.

Simple, maintainable systems are preferred over highly customized solutions.

---

## 4.6 Security by Design

Security shall be incorporated into every architectural decision rather than added later.

Production systems should never become less secure for the convenience of experimentation.

---

# 5. Architectural Zones

Project Polaris is divided into four trust zones.

---

## Zone 1 — Home Network

Purpose:

Provide secure internet connectivity for household devices.

Examples:

- Family computers
- Phones
- IoT devices
- Smart TVs
- Printers

Primary Security Device:

Gateway01 (pfSense)

---

## Zone 2 — Production Homelab

Purpose:

Provide secure enterprise infrastructure for production services.

Examples:

- Proxmox
- Docker01
- Admin01
- Dedicated NAS
- Internal DNS
- Forgejo
- Vaultwarden
- Monitoring
- Production Active Directory
- Windows Workstations
- Linux Administration

Primary Security Device:

Homelab pfSense

---

## Zone 3 — Cyber Range

Purpose:

Provide an isolated enterprise environment for offensive and defensive cybersecurity operations.

Examples:

- OPNsense Firewall
- Attack hosts
- Windows targets
- Linux targets
- Vulnerable services
- Purple Team exercises
- Malware analysis
- Threat hunting
- Detection engineering

Primary Security Device:

Cyber Range OPNsense

---

## Zone 4 — Shared Infrastructure

Purpose:

Provide services supporting multiple trust zones while preserving security boundaries.

Examples:

- DNS
- Monitoring
- Backup Services
- Certificate Services
- Automation

---

# 6. Planned Architecture

```
                               Internet
                                   │
                           Gateway01 (pfSense)
                                   │
─────────────────────────────────────────────────────
                    Home Network
─────────────────────────────────────────────────────
                                   │
                           NanoStation Bridge
                                   │
                           Homelab pfSense
                                   │
─────────────────────────────────────────────────────
                Production Infrastructure
─────────────────────────────────────────────────────

Proxmox

Docker01

Admin01

Dedicated NAS

Production DNS

Forgejo

Vaultwarden

Monitoring

Production Active Directory

Windows Workstations

Linux Administration

                                   │
                          Controlled Routing
                                   │
                            OPNsense Firewall
                                   │
─────────────────────────────────────────────────────
                     Cyber Range
─────────────────────────────────────────────────────

Cyber AD Forest

BlackArch

Physical Kali

Windows Servers

Windows Clients

Linux Servers

Linux Clients

Monitoring

SIEM

Detection Stack

Vulnerability Scanner

Malware Analysis

Threat Hunting

Purple Team

Incident Response
```

---

# 7. Active Directory Strategy

Project Polaris intentionally implements two completely independent Active Directory environments.

## Production Active Directory

Purpose:

Manage trusted infrastructure.

Responsibilities include:

- Windows authentication
- Family computers
- Administrative workstations
- Group Policy
- Secure file services
- Certificate Services (future)

Production Active Directory shall never intentionally contain vulnerabilities.

---

## Cyber Range Active Directory

Purpose:

Provide a realistic enterprise environment for offensive and defensive security training.

The Cyber Range AD may intentionally include:

- Kerberoasting
- AS-REP Roasting
- BloodHound attack paths
- ACL abuse
- Delegation attacks
- NTLM weaknesses
- Legacy protocols
- Weak passwords
- Misconfigurations

The Cyber AD is intentionally disposable.

---

# 8. Decision Validation Framework

Every proposed architectural decision shall be evaluated using the following questions.

## Question 1

Does the decision support the Project Polaris Northstar?

---

## Question 2

Which trust zone does the component belong to?

---

## Question 3

Can it be:

- documented
- monitored
- backed up
- recovered

---

## Question 4

Does it introduce unnecessary technical debt?

---

## Question 5

Does it preserve production security?

---

## Question 6

Is there a simpler enterprise-grade solution?

---

Only decisions that satisfy this framework should become part of the production architecture.

---

# 9. Recommendation Categories

Future recommendations shall be classified as:

## Recommended

Directly supports the Northstar.

Proceed immediately.

---

## Optional Enhancement

Supports the Northstar but is not required for the current milestone.

May be deferred.

---

## Deferred

Does not support the current milestone or introduces unnecessary complexity.

Record in the Maintenance Backlog.

Do not implement immediately.

---

# 10. Long-Term Roadmap

Project Polaris will generally progress through the following milestones.

1. Production Infrastructure
2. Dedicated Storage
3. Internal DNS
4. Production Active Directory
5. Cyber Range
6. Security Operations
7. Offensive Security
8. Artificial Intelligence
9. Automation
10. Continuous Improvement

Individual implementation details may evolve over time while preserving this architecture.

---

# 11. Architectural Stability

The architectural destination defined by this ADR is intended to remain stable.

Implementation details may change when operational experience demonstrates a superior approach.

This principle may be summarized as:

> **The Northstar is stable. The implementation path is flexible.**

---

# 12. Success Criteria

Project Polaris shall be considered complete when it provides:

- enterprise-grade production infrastructure
- enterprise identity management
- secure networking
- dedicated backup infrastructure
- documented disaster recovery
- isolated cyber range
- offensive security platform
- defensive security platform
- AI-assisted administration
- complete documentation
- repeatable automation
- validated recovery procedures

while maintaining strict separation between production services and offensive testing environments.

# 13. VPN Compatibility Note

Proton VPN's Windows split tunneling may not fully exclude Tailscale by application alone. Even with tailscale.exe, tailscaled.exe, and tailscale-ipn.exe excluded, traffic to Tailscale CGNAT addresses may still be routed through Proton. Excluding the Tailscale address range (100.64.0.0/10) or the specific node IPs restores connectivity.

---

# 14. Final Statement

Every future architectural decision should be measured against this document.

If a proposed implementation does not advance Project Polaris toward this architecture, it should either be redesigned or deferred.

This document represents the guiding charter for Project Polaris and serves as the foundation upon which all future Architectural Decision Records are based.
