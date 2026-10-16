# SD-001: Storage Domain

## Purpose
Provide persistent storage services for Project polaris

## Provides
-SMB Shares
-ZFS datasets
-Snapshots
-Backup storage foundation

## consumers
-docker01
-future Windows system
-future AI services
-future cyber range services

## Dependencies
-pve01
-fw-edge01
-enterprise netowork
-TrueNAS

## interface
-SMb
-Future: NFS

## Security model
Local trueNAS accounts initially. Future integration with Active Directory/LDAP

## Notes
Live docker volumes remain local to docker01 for now. storage01 provides backups and shared storage, not live applicatino storage
