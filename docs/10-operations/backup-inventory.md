# Project Polaris Backup Inventory

## Overview

This document defines the backup strategy for all Project Polaris infrastructure.

---

# Infrastructure

| Asset | Method | Destination | Frequency | Verified |
|---------|----------|---------------|--------------|------------|
| Proxmox | vzdump | Storage01 | Weekly / Before Changes | ☐ |
| Firewall01 | XML Export | Storage01 | Before Changes | ☐ |
| Docker01 | VM Backup | Storage01 | Weekly | ☐ |
| Admin01 | VM Backup | Storage01 | Weekly | ☐ |
| Storage01 | TrueNAS Config Export + Proxmox snapshot | Storage01: Backups/Infrastructure/Storage01 | After major change + Monthly | done |

---

# Services

| Service | Method | Destination | Frequency | Verified |
|----------|------------|---------------|--------------|------------|
| Vaultwarden | Docker Volume | Storage01 | Weekly | ☐ |
| Forgejo | Data + Config | Storage01 | Weekly | ☐ |
| Nginx Proxy Manager | Data + Config | Storage01 | Weekly | ☐ |
| Portainer | Volume | Storage01 | Weekly | ☐ |
| Homepage | Config Files | Storage01 | Weekly | ☐ |
| Uptime Kuma | SQLite DB | Storage01 | Weekly | ☐ |

---

# Documentation

Git Repository

Forgejo Repository

Local Clone

Storage01 Backup

---

# Validation Schedule

Infrastructure backups shall be validated after major configuration changes.

Service backups shall be validated after application upgrades or configuration changes.

Recovery testing shall be performed periodically as part of disaster recovery exercises.
