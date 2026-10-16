# TS-002 TrueNAS Pool Creation

Title: Enterprise Storage Pool Creation

Date 2026-07-03

Service: storage01 (TrueNAS)

Severity: Informational

## Objective
Create the initial enterprise storage pool using an unused dedicated disk without impact existing Proxmox storage
----------------------------------------------------------------------------------------------------------------------------------------------------------
## Initial Environment
Available Disks:
-Proxmox ZFS
-Windows passthrough disk
-internal unnused 1 TB samsung disk
-DAS-connected Toshiba disks

Selected Disk:
Samsing HD103UJ
/dev/sdd

Reason:
-Internal SATA connection
-Comepletely unused
-Dedicated learning resource
-No impact on existing production services
---------------------------------------------------------------------------------------------------------------------------------------------------------
## Initial Issue
TrueNAS reported duplicate disk identifiers during pool creation
---------------------------------------------------------------------------------------------------------------------------------------------------------
## Diagnostic Steps
Verified VM configuration:
 qm config 202

Verified Proxmox disk identifiers:
 ls -l /dev/disk/by-id/

Verified active passthrough disks
Verified disk visibility inside TrueNAS
 lsblk -o NAME,SERIAL,MODEL,SIZE

Verified device information
smartctl -i /dev/sdX
--------------------------------------------------------------------------------------------------------------------------------------------------------
## Resolution
Removed obsolete passthrough references
 qm set 202 --delete scsi1

Verified configuration
 qm config 202

Re-added the physical disk using its persistent device identifier
Re-started the VM

Verified unique disk presentation inside TrueNAS

Successfully created
 enterprise-storage
-------------------------------------------------------------------------------------------------------------------------------------------------------
## Pool Configuration
Pool Name:
 enterprise-storage

Layout:
 Stripe

VDEVs:
 1

Width:
 1

Reason:
Single dedicated disk used for learning
Future expansion planned with mirrored or RAIDZ topology as additional storage becomes available
-------------------------------------------------------------------------------------------------------------------------------------------------------
## Datasets Created
-backups
-documentation
-qit
-scratch
------------------------------------------------------------------------------------------------------------------------------------------------------
## Baseline Snapshot
Created:
 baseline

Purpose:
Represents the initial state of the storage domain before production data is stored
------------------------------------------------------------------------------------------------------------------------------------------------------
## Verification
Verified:
-Pool online
-Datasets createdd
-Snapshot present
-Pool healthy
-Stroage documentation updated
------------------------------------------------------------------------------------------------------------------------------------------------------
## Prevention
Before adding passthrough disks to TureNAS, verify the VM configuration (qm config <VMID>) and remove any stale disk mappings to ensure each physical
disk is presented only once.
