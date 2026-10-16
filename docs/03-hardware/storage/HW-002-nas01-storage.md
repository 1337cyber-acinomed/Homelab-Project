# HW-002: nas01

Document ID: HW-002

Status: Production

---

# Asset Information

Role:

Central Backup and Shared Storage Platform

Model:

Asustor Drivestor 2 Gen 2 AS1202T

Firmware:

ADM 5.1.3.RI81

Serial:

AS26031204TM0203

MAC:

XX:XX:XX:XX:XX:XX

Hostname:

nas01

Management IP:

192.168.10.4

Processor:

AArch64 Processor

Installed Memory:

1 GB

Network Link:

1000 Mbps Full-Duplex

---

# Purpose

Provides centralized backup storage, shared documentation, administrative file storage, future container data, virtual machine exports, scripts, and archival storage for Project Polaris.

---

# Storage

Volume:

Volume1

Filesystem:

Btrfs

Primary Disk:

Seagate IronWolf Pro ST4000VN006-3CW104  
Serial: SERIAL-REDACTED  
Capacity: 4 TB  
Location: NAS Bay 2  
Status: Production

Available Capacity at Initial Validation:

Approximately 3.52 TB Free

Bay 1:

Empty  
Reserved for Future Expansion

Production Shares:

Backups

Documentation

Shared

Containers

VM-Exports

Scripts

Archive

---

# Security

HTTPS:

Enabled

HTTP-to-HTTPS Redirection:

Enabled

Management Port:

8001

ADM Defender:

Enabled

Auto-Block:

Enabled

Failed Login Threshold:

5 Attempts

Detection Window:

5 Minutes

Block Duration:

24 Hours

Firewall:

Disabled Pending Future Network Policy Review

Inactive Accounts:

admin

guest

Active Administrative Account:

storage-admin

---

# Services

SMB:

Enabled

WS-Discovery:

Enabled Temporarily

AFP:

Disabled

NFS:

Disabled

FTP:

Disabled

WebDAV:

Disabled

SSH:

Disabled

SFTP:

Disabled

TFTP:

Disabled

SNMP:

Disabled

Rsync Server:

Disabled

---

# Dependencies

Power

Switch01

Firewall01

Project Polaris LAN

Storage Disk Health

Backup Jobs

---

# Future

Install Additional Disk in Bay 1

Evaluate ISO Repository Migration

Validate Backup Retention

Validate Automated Backup Schedules

Perform Restore Testing

Add Monitoring

Configure SMART Notifications

Evaluate Firewall Enablement

Disable WS-Discovery When No Longer Required

