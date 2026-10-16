# Project Polaris Recovery Kit

**Project:** Project Polaris

**Document Version:** 1.0

**Last Updated:** 2026-07-05

**Classification:** Administrative Use

---

# Purpose

This document provides the minimum information required to begin recovery of Project Polaris following a major outage or disaster.

It is not intended to replace the Build Guide, Operations Guide, or Disaster Recovery procedures. Instead, it provides the recovery sequence and references to those documents.

---

# Recovery Philosophy

Recover infrastructure before services.

Recover services before applications.

Recover production before lab environments.

Validate each recovery stage before proceeding.

---

# Recovery Priority

| RP | System | Asset ID | Status |
|----|---------|----------|--------|
| RP-01 | Gateway01 (Future) | INF-004 | Planned |
| RP-02 | Proxmox | INF-001 | Production |
| RP-03 | Firewall01 | NET-001 | Production |
| RP-04 | Docker01 | INF-002 | Production |
| RP-05 | Admin01 | INF-003 | Production |
| RP-06 | Core Services | SRV-001 – SRV-006 | Production |
| RP-07 | Monitoring | SRV-006 | Production |
| RP-08 | Remaining Infrastructure | Various | Production |
| RP-09 | Cyber Range | Planned | Planned |

---

# Critical Systems

| Asset | Purpose |
|---------|---------|
| INF-001 | Proxmox Virtualization Host |
| NET-001 | Firewall01 (Homelab pfSense) |
| INF-002 | Docker01 Container Host |
| INF-003 | Admin01 Administrative Workstation |
| SRV-001 | Vaultwarden |
| SRV-002 | Forgejo |
| SRV-003 | Nginx Proxy Manager |
| SRV-004 | Portainer |
| SRV-005 | Homepage |
| SRV-006 | Uptime Kuma |

---

# Credential Recovery

Administrative credentials are maintained in:

**Vaultwarden**

Recovery procedures:

- Master password procedure
- Emergency recovery procedure
- Organization recovery documentation

Passwords are **not** stored within this document.

---

# Backup Locations

## Infrastructure

- Proxmox configuration
- Firewall01 configuration
- Docker Compose files

## Services

- Vaultwarden backups
- Forgejo backups
- Homepage configuration
- Portainer configuration
- Nginx Proxy Manager configuration
- Uptime Kuma configuration

## Documentation

- Forgejo Repository
- Git Clone
- Local Documentation

---

# Recovery References

| Document | Purpose |
|-----------|----------|
| Architecture Guide | Overall architecture |
| Build Guide | Complete rebuild procedures |
| Operations Guide | Daily administration |
| Disaster Recovery SOP | Detailed recovery procedures |
| TS/LL | Lessons learned |
| ADR Repository | Architectural decisions |

All Docker Compose files reside under:

/srv/docker/compose/

Git repository:

~/Git/homelab-infrastructure/docker/

---

# Emergency Contacts

Owner:

Project Polaris Administrator

---

# Recovery Checklist

## Infrastructure

- [ ] Verify hardware
- [ ] Restore Proxmox
- [ ] Restore Firewall01
- [ ] Restore Docker01
- [ ] Restore Admin01

## Core Services

- [ ] Restore Vaultwarden
- [ ] Restore Forgejo
- [ ] Restore Nginx Proxy Manager
- [ ] Restore Portainer
- [ ] Restore Homepage
- [ ] Restore Uptime Kuma

## Validation

- [ ] Internet access
- [ ] DNS
- [ ] HTTPS
- [ ] SSH
- [ ] Git
- [ ] Vaultwarden
- [ ] Monitoring

## Final

- [ ] Restore remaining infrastructure
- [ ] Verify documentation
- [ ] Verify backups
- [ ] Record incident
