# SOP-002: Manual Configuration Backup Procedures

**Document ID:** SOP-002  
**Status:** Validated  
**Version:** 1.0

## Purpose
Provide repeatable procedures for manually exporting configuration backups from devices without automated export capability.

## Prerequisites
- Perform procedures only from the Homelab Proxmox host.
- Firefox available.
- Administrator credentials available.

## Procedure 1 - TP-Link TL-SG608E
1. Browse to `http://192.168.10.3`
2. Log in.
3. Navigate to **System -> Backup and Restore**.
4. Click **Backup Config**.
5. Verify:
```bash
ls ~/Downloads
```
6. Confirm `config.cfg` exists.

## Procedure 2 - NanoStation Station
1. Browse to `http://192.168.68.51`
2. Log in.
3. Navigate to **System -> Device Maintenance -> Backup Configuration**.
4. Verify:
```bash
ls ~/Downloads
```
5. Confirm `WA-1C6A1BC2CB68.cfg` exists.
6. Validate:
```bash
grep "resolv.host.1.name" ~/Downloads/WA-1C6A1BC2CB68.cfg
```
Expected:
`resolv.host.1.name=STATION - 5AC LOCO`

## Procedure 3 - NanoStation Access Point
1. Browse to `http://192.168.68.55`
2. Log in.
3. Navigate to **System -> Device Maintenance -> Backup Configuration**.
4. Verify:
```bash
ls ~/Downloads
```
5. Confirm `WA-1C6A1BC2CD7B.cfg` exists.
6. Validate:
```bash
grep "resolv.host.1.name" ~/Downloads/WA-1C6A1BC2CD7B.cfg
```
Expected:
`resolv.host.1.name=ACCESS POINT - NanoStation 5AC loco`

## Notes
- Do not rename downloaded files.
- The Collector Framework performs identification, archival, logging, retention, and cleanup.
- Run the collector after completing one or more manual exports.

## Validation Checklist
- [ ] TP-Link export complete
- [ ] config.cfg present
- [ ] Station export complete
- [ ] WA-1C6A1BC2CB68.cfg present
- [ ] Station identity verified
- [ ] AP export complete
- [ ] WA-1C6A1BC2CD7B.cfg present
- [ ] AP identity verified
