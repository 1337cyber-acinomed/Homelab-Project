# HW-003: Cyber Range Host

Document ID: HW-003

Status: Production

---

# Asset Information

Role:

Secondary Proxmox Virtualization Host

Model:

TBD

Motherboard:

TBD

CPU:

TBD

Installed Memory:

TBD

Firmware:

TBD

Serial:

TBD

Hostname:

cyberrange

FQDN:

cyberrange.polaris.home.arpa

Management IP:

192.168.10.119

Operating System:

Proxmox VE 9.2.2

Kernel:

7.0.2-6-pve

Remote Management:

Tailscale

RustDesk

Desktop Environment:

XFCE

Display Manager:

LightDM

---

# Purpose

Hosts the isolated Project Polaris Cyber Range infrastructure.

Supports offensive security testing, defensive security labs, malware analysis, vulnerable targets, monitoring, SIEM, vulnerability assessment, and isolated network experimentation.

---

# Storage

Proxmox Operating System:

512 GB Drive  
Model: TBD  
Serial: TBD  
Status: Production

Production VM Storage:

ZFS Pool: Cyber_VM  
Device: Seagate ST4000DM004  
Serial: ZW63ZWT6  
Capacity: 4 TB  
AutoTrim: Enabled  
Initial Scrub: Completed  
Status: Production

---

# Dependencies

Power

Firewall01

Project Polaris LAN

NanoStation Bridge

Switch01

NAS01

Tailscale

RustDesk Connectivity

---

# Future

Complete Hardware Model and Serial Documentation

Create Proxmox Installation Procedure PR-001

Configure Cyber Range Backup Jobs

Deploy OPNsense Firewall

Create Isolated Cyber Range Networks

Deploy BlackArch Attack VM

Configure Physical Kali Access

Deploy Windows Defense Range

Deploy Linux Defense Range

Deploy Vulnerable Targets

Deploy SIEM and Monitoring

Deploy Vulnerability Assessment Services

Evaluate Future Cluster Integration
