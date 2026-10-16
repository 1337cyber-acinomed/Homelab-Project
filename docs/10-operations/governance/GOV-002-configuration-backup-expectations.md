# GOV-002: Configuration Backup Expectations

**Document ID:** GOV-002  
**Status:** Validated  
**Version:** 1.0

## Purpose
Establish the governance, expectations, and architecture for Project Polaris configuration backups.

## Guiding Principle
> Configuration backups shall leverage each platform's native capabilities whenever possible. The Project Polaris Collector Framework shall supplement native functionality only where necessary to normalize, validate, archive, and retain configuration backups in accordance with GOV-001.
> Configuration collection, validation, archival, replication, retention, logging, and reporting shall be treated as independent stages within the Configuration Backup Pipeline. Whenever practical, each stage shall have a single responsibility so that failures can be isolated without impacting successful completion of preceding stages

## Scope
Applies to Gateway01, Firewall01, Cyber-FW01, Homelab Proxmox, CyberRange Proxmox, NAS01, TP-Link TL-SG608E, NanoStation AP, and NanoStation STA.

## Responsibilities
### Administrator
- Verify successful configuration collection.
- Perform required manual exports where automation is not supported.
- Review logs, investigate failures, and validate restores.

### Collector Framework
- Execute platform collectors.
- Validate configurations.
- Archive changed configurations.
- Remove duplicates.
- Enforce retention.
- Produce operational logs.

## Collection Methods
- **Method A:** Native Scheduled Export (NAS01)
- **Method B:** Collector Retrieval (Gateway01, Firewall01, Cyber-FW01)
- **Method C:** Collector Generated Archive (Homelab Proxmox, CyberRange Proxmox)
- **Method D:** Manual Export + Collector Archive (TP-Link, NanoStations)

## Collector Framework Overview
The orchestrator (`polaris-backup-configs.sh`) executes platform collectors, validates results, archives changed configurations, enforces retention, and records activity in `config-backup.log`.

## Standard Directories
- `/var/lib/project-polaris/config-backup/staging`
- `/var/lib/project-polaris/config-backup/quarantine`

## Naming Convention
`<Device>-YYYY-MM-DD.<extension>`

NanoStation exports are validated using both the MAC-derived filename and the embedded `resolv.host.1.name`.

## Logging
Rolling operational log: `config-backup.log`

## Retention
Automatically enforced in accordance with GOV-001.

## Validation
Implementation validation completed during Phase 2A. Ongoing validation occurs during disaster recovery testing.

## References
- GOV-001
- ADR-000
- Project Polaris Roadmap
