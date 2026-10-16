# HW-001: pve01

Document ID: HW-001

Status: Production

---

# Asset Information

Role:

Primary Proxmox Virtualization Host

Model:

Custom-Built System

Motherboard:

Gigabyte GA-Z170X-Gaming 7

CPU:

TBD

Installed Memory:

32 GB DDR4

Maximum Supported Memory:

64 GB DDR4

Firmware:

TBD

Serial:

TBD

Hostname:

pve01

Management IP:

TBD

Operating System:

Proxmox VE

Network Interfaces:

Intel PCIe 4-Port NIC

---

# Purpose

Primary virtualization platform for Project Polaris enterprise infrastructure.

Hosts core infrastructure, firewall, management, Linux services, Windows domain services, templates, and future trusted workloads.

---

# Storage

Proxmox Operating System:

Toshiba MQ01ABD100  
Serial: SERIAL-REDACTED  
Capacity: 1 TB  
Status: Production

Primary VM Storage:

ZFS Pool: VM  
Device: Toshiba MQ01ABD100  
Serial: SERIAL-REDACTED  
Capacity: 1 TB  
Status: Production

Secondary VM Storage:

ZFS Pool: VM2  
Device: Samsung HD103UJ  
Serial: SERIAL-REDACTED  
Capacity: 1 TB  
Status: Production

ISO Repository:

Storage ID: ISO-Repo  
Device: Toshiba MK6465GSXN  
Serial: SERIAL-REDACTED  
Capacity: 640 GB  
Location: DAS  
Status: Production

---

# Dependencies

Power

Firewall01

Project Polaris LAN

NanoStation Bridge

Switch01

NAS01

Local ZFS Storage

Backup Strategy

---

# Future

Upgrade Memory to 64 GB

Complete Hardware Serial Documentation

Evaluate Centralized ISO Repository Location

Continue Storage Health Monitoring

Complete Backup and Restore Validation

Support Gateway01 and CA01 Deployment
