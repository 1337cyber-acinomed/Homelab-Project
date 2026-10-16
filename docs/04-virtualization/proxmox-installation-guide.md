# PR-001: Proxmox VE 9 Installation Guide

Document ID: PR-001

Version: 1.0

Status: Production

Owner: Project Polaris

Last Updated: 2026-07-19

---

# Purpose

This procedure defines the standardized process for installing Proxmox VE 9 within the Project Polaris environment.

Following this procedure results in a production-ready Proxmox host that conforms to all Project Polaris standards for hardware preparation, operating system installation, networking, storage, remote administration, validation, and operational readiness.

This guide is intended to support a complete clean-room deployment without requiring reference to prior implementation history.

---

# Scope

...

---

# References

...

---

# Table of Contents

1. Hardware Preparation

2. BIOS Configuration

3. Proxmox VE Installation

4. Initial Configuration

5. Repository Configuration

6. Operating System Updates

7. Desktop Environment Installation

8. Remote Administration

9. Storage Configuration

10. Network Configuration

11. Validation

12. Production Acceptance

Appendix A – Repository Configuration

Appendix B – Hostname Migration

Appendix C – LightDM / XFCE

Appendix D – RustDesk

Appendix E – Tailscale

Appendix F – Storage Standards

Appendix G – Validation Commands

Appendix H – Troubleshooting

-----------------------------------------------------------------------------
---

# 2. BIOS Configuration

## 2.1 Objective

Configure the system firmware to provide a stable, secure, and virtualization-ready platform for Proxmox VE 9.

Project Polaris standardizes BIOS settings wherever possible to ensure consistent behavior across all hypervisor hosts.

---

## 2.2 Update BIOS

Before installation:

- Update the motherboard firmware to the latest stable vendor release.
- Record the BIOS version in the appropriate Hardware Inventory document.
- Restore default settings after the update before applying the Project Polaris configuration.

---

## 2.3 Required BIOS Settings

The following settings shall be enabled when supported by the hardware.

| Setting | Required Value |
|----------|----------------|
| Intel VT-x / AMD-V | Enabled |
| Intel VT-d / AMD IOMMU | Enabled |
| Execute Disable Bit (NX) | Enabled |
| UEFI Boot | Enabled |
| Secure Boot | Disabled |
| TPM | Enabled (if available) |
| Hyper-Threading / SMT | Enabled |
| CPU Power Profile | Performance (preferred) |
| Wake on LAN | Enabled (optional) |

---

## 2.4 Boot Order

Configure the boot sequence as follows:

1. USB Installation Media
2. Proxmox Operating System Drive
3. All remaining devices

After installation, remove the USB installer and verify the system boots directly into Proxmox.

---

## 2.5 Storage Verification

Confirm that all intended storage devices are detected by the firmware.

Verify:

- Boot drive present.
- VM storage drives present.
- Additional storage devices correctly identified.
- SMART monitoring enabled when supported.

Record any discrepancies before continuing.

---

## 2.6 Network Verification

Verify all onboard and add-in network adapters are detected.

Record:

- Number of interfaces.
- Intended management interface.
- Intended WAN interface (if applicable).

No interface naming assumptions should be made at this stage.

---

## 2.7 Validation

Before proceeding to installation, confirm:

□ BIOS updated.

□ Factory defaults loaded.

□ Virtualization enabled.

□ IOMMU enabled.

□ Secure Boot disabled.

□ UEFI enabled.

□ Boot order verified.

□ Storage detected.

□ Network adapters detected.

---

## 2.8 Lessons Learned

Firmware updates performed before installation reduce later maintenance and improve hardware compatibility.

Recording BIOS versions during commissioning simplifies future troubleshooting and hardware replacement.

Enabling virtualization and IOMMU prior to installation prevents unnecessary reconfiguration after Proxmox deployment.
-----------------------------------------------------------------------------
---

# 3. Proxmox VE Installation

## 3.1 Objective

Install Proxmox VE 9 using the Project Polaris standard configuration.

The installation establishes the base operating system upon which all subsequent Project Polaris configuration and validation is performed.

---

## 3.2 Boot Installation Media

Insert the prepared Proxmox VE installation media.

Power on the system.

Select the UEFI boot entry corresponding to the installation media.

When the Proxmox boot menu appears, select:

```
Install Proxmox VE
```

Proceed through the installer.

---

## 3.3 License Agreement

Review the license agreement.

Select:

```
I Agree
```

Continue.

---

## 3.4 Target Disk Selection

### Project Polaris Standard

Install Proxmox onto the dedicated operating system drive.

Virtual machine storage should reside on separate storage whenever practical.

### Rationale

Separating the operating system from VM storage:

- Simplifies disaster recovery.
- Reduces operating system risk.
- Allows storage migration without reinstalling Proxmox.
- Improves long-term maintainability.

---

## 3.5 Filesystem Selection

### Project Polaris Standard

Use:

```
ext4
```

for the operating system installation unless specific project requirements dictate otherwise.

### Decision Point

Alternative filesystems (ZFS, XFS, etc.) may be appropriate for specialized deployments.

The operating system filesystem should not be selected solely because VM storage will use ZFS.

### Rationale

The Project Polaris architecture separates operating system storage from virtualization storage.

Dedicated ZFS pools are created after installation for VM workloads.

This approach:

- Simplifies installation.
- Reduces memory overhead.
- Separates operating system maintenance from virtualization storage.

---

## 3.6 Regional Configuration

Configure:

Language

Keyboard

Time Zone

Verify all selections before continuing.

---

## 3.7 Administrative Credentials

Configure:

Root password

Email address

### Project Polaris Standard

Passwords shall comply with Project Polaris password policy.

Administrative email should be a monitored account.

Credentials shall be stored immediately within Vaultwarden following successful installation.

---

## 3.8 Network Configuration

Configure:

Hostname

Management IP

Gateway

DNS Server

### Project Polaris Standard

Hostnames shall comply with:

STD-001 Node Naming Standard

Management addressing shall comply with:

Project Polaris IP Address Plan

DNS shall be configured according to the current infrastructure design.

---

## 3.9 Installation Summary

Before beginning installation verify:

□ Target disk

□ Filesystem

□ Hostname

□ IP Address

□ Gateway

□ DNS

□ Time Zone

□ Root credentials

Only begin installation after confirming all settings.

---

## 3.10 Installation

Select:

```
Install
```

The installer will:

- Partition the operating system drive.
- Install Debian.
- Install Proxmox VE.
- Configure networking.
- Generate certificates.
- Configure system services.

Installation time varies according to hardware.

---

## 3.11 First Boot

After installation:

Remove installation media.

Reboot the system.

Verify the system boots directly into Proxmox VE.

Log in using the root account created during installation.

---

## 3.12 Initial Login

Verify:

Console login.

Network initialization.

Management IP assignment.

The Proxmox web interface should now be accessible from:

```
https://<management-ip>:8006
```

Ignore the browser certificate warning during the initial installation.

Certificates will be regenerated as necessary during later configuration.

---

## 3.13 Validation

Confirm:

□ Installation completed successfully.

□ Boot media removed.

□ System boots without user intervention.

□ Console login successful.

□ Web interface accessible.

□ Root authentication successful.

□ Management network operational.

---

## 3.14 Lessons Learned

Project Polaris intentionally minimizes installer configuration.

Most enterprise configuration occurs after installation where it can be documented, validated, and repeated consistently.

Separating installation from post-install configuration simplifies rebuilds and reduces installation complexity.
-----------------------------------------------------------------------------
---

# 4. Initial Configuration

## 4.1 Objective

Perform the initial post-installation configuration required to prepare the Proxmox VE host for Project Polaris.

This section establishes the baseline operating environment before repositories, updates, desktop software, storage, or cluster configuration are performed.

---

# 4.2 Verify Console Login

Log in locally using the root account created during installation.

Verify:

- Console login succeeds.
- No boot errors are present.
- Networking initialized correctly.
- Hostname displays correctly.

Run:

```bash
hostnamectl
```

Confirm:

- Static hostname is correct.
- Operating system version is correct.
- Kernel version is correct.

---

# 4.3 Verify Network Configuration

Verify the management interface.

Run:

```bash
ip -br addr
```

Confirm:

- Management interface present.
- Static IP assigned.
- Correct subnet mask.

Verify routing:

```bash
ip route
```

Confirm:

- Default gateway configured.
- Management network reachable.

Verify Internet connectivity:

```bash
ping -c 4 8.8.8.8
```

Verify DNS resolution:

```bash
ping -c 4 google.com
```

Both tests must succeed before continuing.

---

# 4.4 Verify Storage

Display block devices.

```bash
lsblk
```

Verify:

- Boot drive present.
- Planned storage drives detected.
- Device capacities correct.

Display mounted filesystems.

```bash
df -h
```

Confirm:

- Root filesystem mounted.
- Boot filesystem mounted.
- Available space appropriate.

---

# 4.5 Verify Installed Version

Display installed version.

```bash
pveversion
```

Record:

- Proxmox version
- Kernel version

This information should also be recorded within the Hardware Inventory.

---

# 4.6 Configure Hostname

Verify the hostname matches the Node Naming Standard.

Reference:

STD-001

If changes are required, follow:

Appendix B — Hostname Migration Procedure

Hostnames should not be changed after cluster formation except through the documented migration procedure.

---

# 4.7 Verify Time Synchronization

Display current status.

```bash
timedatectl
```

Confirm:

- Correct timezone.
- NTP enabled.
- System clock synchronized.

Correct time is mandatory before cluster formation.

---

# 4.8 Verify System Services

Confirm required services are running.

```bash
systemctl status pve-cluster
```

```bash
systemctl status pvedaemon
```

```bash
systemctl status pveproxy
```

Expected:

All services report:

```
active (running)
```

---

# 4.9 Verify Web Interface

From an administrative workstation:

Browse to:

```
https://<management-ip>:8006
```

Verify:

- Login page appears.
- Root authentication succeeds.
- Dashboard loads correctly.
- No service errors displayed.

Certificate warnings are expected during initial installation.

---

# 4.10 Record Installation

Update documentation.

Record:

- Installation date
- Installed version
- Kernel version
- Hostname
- Management IP
- Hardware Inventory reference

Store initial credentials securely within Vaultwarden.

---

# 4.11 Initial Backup

Before making any additional modifications, create a configuration backup.

Recommended files:

```text
/etc/network/interfaces

/etc/hostname

/etc/hosts
```

These files represent the clean post-installation baseline.

---

# 4.12 Validation

Confirm:

□ Console login successful

□ Hostname verified

□ Management network operational

□ Internet connectivity verified

□ DNS resolution verified

□ Storage detected

□ Services running

□ Web interface operational

□ Installation documented

□ Initial configuration backup created

Only after successful validation should repository configuration begin.

---

# 4.13 Lessons Learned

Performing validation immediately after installation isolates installation issues from later configuration changes.

Capturing a clean configuration backup before modifying repositories or installing additional software provides a known-good recovery point and simplifies troubleshooting.

Separating initial validation from operating system updates makes root cause analysis significantly easier should problems arise during later stages of commissioning.
------------------------------------------------------------------------------
---

# 5. Repository Configuration

## 5.1 Objective

Configure the Proxmox VE package repositories in accordance with the Project Polaris standard.

This section removes unsupported enterprise repositories for Community Edition installations and configures the supported community repositories prior to applying operating system updates.

Repository configuration shall be completed before installing any additional software.

---

# 5.2 Verify Current Repository Configuration

Display the configured APT source files.

```bash
ls /etc/apt/sources.list.d/
```

Expected files include:

```
ceph.sources
debian.sources
pve-enterprise.sources
```

Additional files may exist depending on the installation version.

---

# 5.3 Disable Enterprise Repository

Open:

```bash
nano /etc/apt/sources.list.d/pve-enterprise.sources
```

Comment the repository entry.

Example:

```text
# deb https://enterprise.proxmox.com/debian/pve trixie pve-enterprise
```

Save the file.

---

# 5.4 Disable Enterprise Ceph Repository

Open:

```bash
nano /etc/apt/sources.list.d/ceph.sources
```

Comment the enterprise repository entries or disable the file according to the current Proxmox release.

Project Polaris does not enable enterprise Ceph repositories unless a supported subscription is in use.

---

# 5.5 Configure Community Repository

Create:

```bash
nano /etc/apt/sources.list.d/pve-community.sources
```

Insert:

```text
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
```

Save the file.

---

# 5.6 Verify Debian Repository

Open:

```bash
nano /etc/apt/sources.list.d/debian.sources
```

Verify that the Debian repositories correspond to the installed Proxmox release.

No modifications should be made unless required by the current release documentation.

---

# 5.7 Refresh Package Lists

Run:

```bash
apt update
```

Expected result:

- Package lists download successfully.
- No repository signature errors.
- No authentication errors.
- No enterprise repository warnings.

Warnings regarding optional repositories should be investigated before continuing.

---

# 5.8 Validate Repository Configuration

Verify installed repositories.

```bash
apt policy
```

Confirm:

- Community repository present.
- Debian repositories present.
- Enterprise repository disabled.
- Ceph enterprise repository disabled (unless intentionally used).

---

# 5.9 Record Repository State

Document:

- Proxmox release
- Debian release
- Repository configuration
- Date modified

Repository changes should be reflected in system documentation if they differ from the Project Polaris standard.

---

# 5.10 Validation

Confirm:

□ Enterprise repository disabled.

□ Enterprise Ceph repository disabled.

□ Community repository configured.

□ Debian repository verified.

□ apt update completed successfully.

□ No repository authentication errors.

□ No repository signature errors.

Only after successful validation should operating system updates begin.

---

# 5.11 Lessons Learned

Recent Proxmox releases separate repository definitions into individual `.sources` files rather than a single `sources.list` file.

Community Edition installations require both the standard enterprise repository and the enterprise Ceph repository to be reviewed during commissioning.

Validating repository configuration before updating avoids unnecessary troubleshooting and ensures all nodes receive updates from consistent package sources.
------------------------------------------------------------------------------
---

# 6. Operating System Updates

## 6.1 Objective

Update the newly installed Proxmox VE host to the current supported patch level before installing any additional software.

Operating system updates shall be completed immediately after repository configuration and before installing desktop components, remote administration tools, or configuring storage.

---

# 6.2 Verify Current Version

Record the current version.

```bash
pveversion
```

Document:

- Proxmox Version
- Kernel Version

This establishes the installation baseline.

---

# 6.3 Refresh Package Lists

Refresh the package index.

```bash
apt update
```

Confirm:

- No repository errors.
- No authentication warnings.
- No missing package indexes.

If errors exist, resolve them before continuing.

---

# 6.4 Upgrade Installed Packages

Apply all available updates.

```bash
apt full-upgrade
```

Review all package actions before confirming.

Project Polaris standard:

Accept package updates only within the currently installed Proxmox release.

Do not perform major release upgrades during commissioning.

---

# 6.5 Remove Obsolete Packages

After the upgrade completes:

```bash
apt autoremove
```

Review the package list before confirming removal.

No Project Polaris software should be removed during commissioning.

---

# 6.6 Verify Kernel Installation

Determine the currently running kernel.

```bash
uname -r
```

Verify the latest installed kernel.

```bash
proxmox-boot-tool kernel list
```

If the system is configured without `proxmox-boot-tool`, document the installed kernel using:

```bash
dpkg --list | grep pve-kernel
```

Confirm the newest kernel has been installed successfully.

---

# 6.7 Reboot the Host

Reboot the system.

```bash
reboot
```

Allow the system to boot normally.

---

# 6.8 Post-Reboot Verification

After reboot, verify:

```bash
uname -r
```

Confirm:

Running kernel matches the newly installed kernel.

Verify Proxmox version.

```bash
pveversion
```

Verify hostname.

```bash
hostnamectl
```

Verify uptime.

```bash
uptime
```

---

# 6.9 Verify Services

Confirm critical services are operational.

```bash
systemctl status pve-cluster
```

```bash
systemctl status pvedaemon
```

```bash
systemctl status pveproxy
```

Expected:

```
active (running)
```

---

# 6.10 Verify Network Connectivity

Confirm networking remains operational.

```bash
ip addr
```

```bash
ip route
```

Verify Internet connectivity.

```bash
ping -c 4 8.8.8.8
```

Verify DNS.

```bash
ping -c 4 google.com
```

---

# 6.11 Verify Web Interface

From an administrative workstation:

Browse to:

```
https://<management-ip>:8006
```

Verify:

- Login successful.
- Dashboard loads.
- No service warnings.
- No failed tasks.

---

# 6.12 Configuration Backup

After successful updates and validation, create the first post-update configuration backup.

Recommended files:

```text
/etc/network/interfaces
/etc/hostname
/etc/hosts
/etc/apt/
```

Store the backup in accordance with the Project Polaris backup standard.

---

# 6.13 Validation

Confirm:

□ apt update completed successfully.

□ apt full-upgrade completed successfully.

□ autoremove completed successfully.

□ Host rebooted successfully.

□ New kernel active.

□ Proxmox version verified.

□ Critical services running.

□ Network connectivity verified.

□ DNS resolution verified.

□ Web interface operational.

□ Configuration backup created.

Only after successful validation should desktop environment installation begin.

---

# 6.14 Lessons Learned

Updating immediately after installation minimizes later troubleshooting by ensuring subsequent software is installed on a fully patched operating system.

Verifying the active kernel after reboot prevents confusion when multiple kernels are installed.

Capturing a configuration backup after updates provides a clean recovery point before introducing additional software or custom configuration.
--------------------------------------------------------------------------------
---

# 7. Administrative Desktop Environment

## 7.1 Objective

Install and configure the Project Polaris administrative desktop environment.

Every Project Polaris Proxmox host shall provide a lightweight local graphical environment to support:

- Local administration
- Disaster recovery
- Hardware troubleshooting
- Remote desktop access
- Administrative tooling

The desktop environment is intended for administration only and is not a replacement for normal web-based management.

---

# 7.2 Project Polaris Standard

Project Polaris standardizes on:

| Component | Standard |
|-----------|----------|
| Desktop Environment | XFCE4 |
| Display Manager | LightDM |

### Rationale

XFCE provides:

- Low memory usage
- Low CPU utilization
- Excellent stability
- Long-term support
- Minimal background services

LightDM provides:

- Fast startup
- Simple configuration
- Reliable remote administration compatibility

---

# 7.3 Install XFCE

Update package lists.

```bash
apt update
```

Install XFCE.

```bash
apt install xfce4 xfce4-goodies
```

Review package actions before confirming installation.

---

# 7.4 Install LightDM

Install LightDM.

```bash
apt install lightdm
```

When prompted, select:

```
LightDM
```

as the default display manager.

If no prompt appears, verify the active display manager after installation.

---

# 7.5 Verify Display Manager

Verify LightDM is enabled.

```bash
systemctl status lightdm
```

Expected:

```
active (running)
```

---

# 7.6 Boot to Graphical Target

Verify the default boot target.

```bash
systemctl get-default
```

Expected:

```
graphical.target
```

If necessary:

```bash
systemctl set-default graphical.target
```

---

# 7.7 Reboot

Reboot the host.

```bash
reboot
```

Allow the system to boot normally.

---

# 7.8 Graphical Login Validation

After reboot verify:

- LightDM login screen appears.
- Root login succeeds (or approved administrative account if future standards change).
- XFCE desktop loads successfully.
- Desktop is responsive.

---

# 7.9 Verify Proxmox Services

Opening a graphical desktop must not interfere with Proxmox services.

Verify:

```bash
systemctl status pve-cluster
```

```bash
systemctl status pvedaemon
```

```bash
systemctl status pveproxy
```

Expected:

```
active (running)
```

---

# 7.10 Verify Resource Utilization

Review system resources.

```bash
free -h
```

```bash
top
```

or

```bash
htop
```

Confirm:

- Memory usage appropriate.
- CPU utilization low while idle.
- No unexpected background processes.

---

# 7.11 Administrative Applications

Verify installation of basic administrative tools.

Examples include:

- Terminal Emulator
- File Manager
- Text Editor
- Firefox
- System Monitor

Additional administrative software will be installed in later sections.

---

# 7.12 Configuration Backup

After successful validation create a configuration backup.

Recommended:

```text
/etc/lightdm/

/etc/systemd/

/etc/X11/
```

Store the backup according to the Project Polaris backup standard.

---

# 7.13 Validation

Confirm:

□ XFCE installed.

□ LightDM installed.

□ LightDM active.

□ graphical.target enabled.

□ Desktop loads successfully.

□ Proxmox services remain operational.

□ Resource utilization acceptable.

□ Administrative applications available.

□ Configuration backup completed.

Only after successful validation should remote administration software be installed.

---

# 7.14 Lessons Learned

Installing the desktop environment before remote administration tools provides a stable platform for validating graphical access.

XFCE has demonstrated excellent performance on both Project Polaris hosts while maintaining minimal resource consumption.

Maintaining a lightweight desktop environment significantly improves local recovery capabilities without materially affecting Proxmox performance.
------------------------------------------------------------------------------
---

# 8. Remote Administration

## 8.1 Objective

Configure the standardized Project Polaris remote administration platform.

Every Proxmox host shall support secure remote administration through multiple independent management methods to maximize operational flexibility and disaster recovery capability.

The Project Polaris remote administration standard consists of:

- SSH
- Proxmox Web Interface
- Tailscale
- RustDesk

These services provide multiple management paths should any single service become unavailable.

---

# 8.2 Administrative Access Policy

Project Polaris supports multiple administrative methods.

Priority order:

1. Local Console
2. SSH
3. Proxmox Web Interface
4. Tailscale
5. RustDesk

No single remote administration method shall be considered sufficient.

---

# 8.3 Verify SSH

Confirm OpenSSH is installed.

```bash
systemctl status ssh
```

Expected:

```
active (running)
```

If required:

```bash
apt install openssh-server
```

Enable:

```bash
systemctl enable ssh
```

Start:

```bash
systemctl start ssh
```

---

# 8.4 SSH Validation

From another administrative system:

```bash
ssh root@<management-ip>
```

Verify:

- Connection established.
- Authentication successful.
- Shell access available.

---

# 8.5 Install Tailscale

Install Tailscale using the official installation method.

Example:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

Authenticate:

```bash
tailscale up
```

Complete authentication through the browser.

---

# 8.6 Verify Tailscale

Display status.

```bash
tailscale status
```

Verify:

- Host appears online.
- Correct hostname.
- Correct Tailscale IP.
- Connected to Project Polaris tailnet.

Verify connectivity.

```bash
tailscale ping <peer>
```

Confirm successful communication.

---

# 8.7 Install RustDesk

Download the current RustDesk package.

Install:

```bash
apt install ./rustdesk*.deb
```

Resolve dependencies if necessary.

```bash
apt --fix-broken install
```

---

# 8.8 Verify RustDesk

Launch RustDesk.

Confirm:

- Application opens.
- ID assigned.
- Password generated.
- Host reachable from another administrative workstation.

Record the RustDesk ID if required by organizational policy.

---

# 8.9 Verify Proxmox Web Interface

Browse to:

```
https://<management-ip>:8006
```

Verify:

- Login page.
- Authentication.
- Dashboard.
- Node summary.

---

# 8.10 Multi-Path Validation

Verify each management path.

| Service | Validation |
|----------|------------|
| Console | Successful |
| SSH | Successful |
| Proxmox GUI | Successful |
| Tailscale | Successful |
| RustDesk | Successful |

All methods should remain operational simultaneously.

---

# 8.11 Configuration Backup

Record:

- Tailscale hostname
- Tailscale IP
- RustDesk ID (if required)
- SSH configuration

Backup:

```text
/etc/ssh/

/var/lib/tailscale/
```

Store according to the Project Polaris backup standard.

---

# 8.12 Validation

Confirm:

□ SSH operational.

□ SSH accessible remotely.

□ Proxmox GUI operational.

□ Tailscale installed.

□ Tailscale authenticated.

□ Tailscale connectivity verified.

□ RustDesk installed.

□ RustDesk operational.

□ Multiple administration paths available.

Only after successful validation should storage configuration begin.

---

# 8.13 Lessons Learned

Providing multiple independent administrative methods significantly improves recoverability.

Tailscale provides secure remote access without exposing administrative services directly to the Internet.

RustDesk complements SSH by providing full graphical access during maintenance and troubleshooting.

No single management method should be relied upon exclusively.
-------------------------------------------------------------------------------
---

# 9. Storage Configuration

## 9.1 Objective

Configure and validate local virtualization storage in accordance with the Project Polaris Storage Architecture (SA-001).

Storage configuration shall follow the approved storage design and naming standards.

This section configures storage for virtualization workloads only.

Storage planning and physical inventory are documented separately in SA-001.

---

# 9.2 Storage Philosophy

Project Polaris separates storage into distinct functional roles.

Operating System Storage

- Dedicated Proxmox installation
- Independent of VM storage
- Simplifies recovery

Virtual Machine Storage

- Dedicated ZFS storage pools
- Local to each node
- Managed independently

Backup Storage

- NAS-based
- Independent of virtualization hosts

ISO Repository

- Centralized repository
- Accessible by all Proxmox hosts
- Managed separately from VM storage

---

# 9.3 Verify Installed Storage

Display storage devices.

```bash
lsblk
```

Verify:

- Operating system drive
- Planned VM storage drives
- Additional storage devices
- Capacity matches inventory

Record any discrepancies before proceeding.

---

# 9.4 Verify Storage Health

For each storage device verify SMART status.

Example:

```bash
smartctl -H /dev/sdX
```

Expected:

```
SMART overall-health self-assessment test result: PASSED
```

If SMART reports errors, resolve them before placing the device into production.

---

# 9.5 Create ZFS Pool

Create the storage pool according to SA-001.

Examples:

Infrastructure

```
VM
```

Cyber Range

```
Cyber_VM
```

Use ashift appropriate for the storage media.

Verify successful creation.

```bash
zpool status
```

---

# 9.6 Enable ZFS Maintenance

Enable automatic TRIM.

```bash
zpool set autotrim=on <pool>
```

Verify.

```bash
zpool get autotrim
```

Expected:

```
on
```

---

# 9.7 Initial Pool Verification

Display status.

```bash
zpool status
```

Confirm:

- ONLINE
- No errors
- Expected devices present

Display properties.

```bash
zpool list
```

Confirm:

- Capacity
- Available space
- Health

---

# 9.8 Register Storage

Register the pool with Proxmox.

Datacenter

↓

Storage

↓

Add

↓

ZFS

Configure:

Pool Name

Storage ID

Content Types

Enable

Node Assignment

Verify storage appears correctly.

---

# 9.9 Content Types

Enable only required content.

Typical selections:

Infrastructure

- Disk Images
- Containers
- Snippets

ISO storage should remain separate whenever possible.

---

# 9.10 Initial Validation

Create a small temporary virtual machine.

Verify:

- Disk creation
- Disk deletion
- Pool utilization changes appropriately

Remove the temporary VM after validation.

---

# 9.11 Maintenance Configuration

Perform an initial scrub.

```bash
zpool scrub <pool>
```

Verify completion.

```bash
zpool status
```

Confirm:

- No errors
- Scrub completed successfully

---

# 9.12 Storage Backup

Record:

Pool name

Device assignments

Capacity

Serial numbers

Configuration

Update:

SA-001

Hardware Inventory

Storage documentation

---

# 9.13 Validation

Confirm:

□ Storage detected.

□ SMART healthy.

□ ZFS pool created.

□ Pool ONLINE.

□ autotrim enabled.

□ Storage registered.

□ Test VM created.

□ Test VM removed.

□ Initial scrub completed.

□ Documentation updated.

Only after successful validation should network configuration continue.

---

# 9.14 Lessons Learned

Separating operating system storage from virtualization storage greatly simplifies long-term maintenance.

Standardized storage naming improves documentation consistency and cluster administration.

Local ZFS pools provide an efficient administrative cluster without requiring shared storage.

Maintaining a centralized ISO repository separately from virtualization storage improves storage utilization while simplifying future expansion.
------------------------------------------------------------------------------
---

# 10. Network Configuration

## 10.1 Objective

Configure the Proxmox VE host networking according to the Project Polaris Network Architecture (STD-002) and the Project Polaris IP Address Plan.

Network configuration shall establish the host's permanent management connectivity while maintaining consistency across all Project Polaris infrastructure.

---

# 10.2 Network Standards

All network configuration shall comply with:

- STD-001 – Node Naming Standard
- STD-002 – Network Architecture & Management Guide
- Project Polaris IP Address Plan
- Project Polaris DNS Registry

No static IP addresses shall be assigned outside the approved IP Address Plan.

---

# 10.3 Verify Physical Interfaces

Identify available network interfaces.

```bash
ip -br link
```

or

```bash
ip addr
```

Document:

- Interface names
- Link status
- Intended purpose

Reference the Hardware Inventory if interface assignments differ from expectations.

---

# 10.4 Configure Management Interface

Configure the management bridge according to the approved network design.

Project Polaris Standard:

- Static IP Address
- Static Gateway
- Static DNS
- Bridge Configuration

Do not configure temporary addressing.

---

# 10.5 Verify Interface Configuration

Review:

```bash
cat /etc/network/interfaces
```

Confirm:

- Interface assignments
- Static addressing
- Gateway
- Bridge membership
- Comments (if used)

Verify configuration matches the approved network design.

---

# 10.6 Apply Configuration

Reload networking.

```bash
ifreload -a
```

If required:

```bash
systemctl restart networking
```

Only reboot if necessary.

---

# 10.7 Verify Connectivity

Verify interface status.

```bash
ip -br addr
```

Verify routing.

```bash
ip route
```

Confirm:

- Static IP active.
- Default gateway present.
- Bridge operational.

---

# 10.8 Verify External Connectivity

Ping gateway.

```bash
ping -c 4 <gateway>
```

Ping Internet.

```bash
ping -c 4 8.8.8.8
```

Verify DNS.

```bash
ping -c 4 google.com
```

All tests shall succeed before continuing.

---

# 10.9 Verify Hostname Resolution

Display hostname.

```bash
hostnamectl
```

Verify local resolution.

```bash
hostname
```

Verify hosts file.

```bash
cat /etc/hosts
```

Confirm:

- Hostname matches STD-001.
- FQDN correct.
- Loopback entries correct.
- No legacy hostnames remain.

---

# 10.10 Verify Time Synchronization

Networking must support reliable time synchronization.

Verify:

```bash
timedatectl
```

Confirm:

- Correct timezone.
- NTP synchronized.
- System clock synchronized.

---

# 10.11 Verify Administrative Services

Confirm management services remain operational.

```bash
systemctl status ssh
```

```bash
systemctl status pveproxy
```

```bash
systemctl status pve-cluster
```

Expected:

```
active (running)
```

---

# 10.12 Verify Web Interface

Browse to:

```
https://<management-ip>:8006
```

Confirm:

- Login successful.
- Dashboard loads.
- No service warnings.
- Node reachable.

---

# 10.13 Configuration Backup

Create a post-network configuration backup.

Recommended files:

```text
/etc/network/interfaces

/etc/hosts

/etc/hostname

/etc/resolv.conf
```

Store according to the Project Polaris backup standard.

---

# 10.14 Validation

Confirm:

□ Physical interfaces detected.

□ Management bridge configured.

□ Static IP assigned.

□ Gateway verified.

□ DNS operational.

□ Internet connectivity verified.

□ Hostname correct.

□ FQDN correct.

□ No legacy hostnames remain.

□ SSH operational.

□ Proxmox GUI operational.

□ Configuration backup completed.

Only after successful validation should final system validation begin.

---

# 10.15 Lessons Learned

Separating network architecture from installation procedures greatly simplifies future network changes while preserving installation consistency.

Standardizing management networking before cluster formation significantly reduces administrative complexity.

Validating hostname resolution prior to clustering prevents later certificate and PMXCFS issues.

Maintaining permanent static management addressing provides predictable administrative access and simplifies disaster recovery.
-------------------------------------------------------------------------------
---

# 11. System Validation

## 11.1 Objective

Perform a comprehensive validation of the newly installed Proxmox VE host to verify compliance with Project Polaris standards.

Successful completion of this section certifies that the node is ready for production use.

No node shall be considered commissioned until every validation in this section has successfully passed.

---

# 11.2 Operating System Validation

Verify:

□ Proxmox VE installed successfully

□ Correct Proxmox version

□ Correct kernel version

□ Latest operating system updates installed

□ System reboots successfully

Commands:

```bash
pveversion

uname -r
```

---

# 11.3 Hardware Validation

Verify:

□ CPU virtualization enabled

□ Memory detected correctly

□ Storage devices detected

□ Network interfaces detected

Commands:

```bash
lscpu

free -h

lsblk

ip -br link
```

---

# 11.4 Storage Validation

Verify:

□ Storage pool ONLINE

□ No ZFS errors

□ autotrim enabled

□ Initial scrub completed

□ Storage registered in Proxmox

Commands:

```bash
zpool status

zpool list

pvesm status
```

---

# 11.5 Network Validation

Verify:

□ Static IP configured

□ Gateway reachable

□ Internet connectivity

□ DNS resolution

□ Management bridge operational

Commands:

```bash
ip addr

ip route

ping -c 4 <gateway>

ping -c 4 8.8.8.8

ping -c 4 google.com
```

---

# 11.6 Administrative Access Validation

Verify:

□ Local console

□ SSH

□ Proxmox GUI

□ Tailscale

□ RustDesk

Confirm all administrative methods operate correctly.

---

# 11.7 Service Validation

Verify:

□ pve-cluster

□ pvedaemon

□ pveproxy

□ ssh

□ lightdm

Commands:

```bash
systemctl status pve-cluster

systemctl status pvedaemon

systemctl status pveproxy

systemctl status ssh

systemctl status lightdm
```

Expected:

```
active (running)
```

---

# 11.8 Documentation Validation

Confirm the following documents have been updated.

□ Hardware Inventory

□ Storage Architecture

□ IP Address Plan

□ DNS Registry

□ VM Structure (if applicable)

□ Maintenance Backlog

□ Installation Notes

Project Polaris documentation shall always reflect the current production state.

---

# 11.9 Backup Validation

Verify:

□ Configuration backup created

□ Backup location documented

□ Backup restoration procedure understood

Recommended backup includes:

```text
/etc/

/root/

/etc/pve/
```

---

# 11.10 Security Validation

Confirm:

□ Root password secured

□ Credentials stored in Vaultwarden

□ SSH accessible only through approved methods

□ Administrative software installed

□ No unnecessary software installed

---

# 11.11 Operational Validation

Confirm:

□ Host remains stable

□ No unexpected reboots

□ No failed services

□ No failed system tasks

Commands:

```bash
journalctl -p err -b

systemctl --failed
```

Expected:

No unexpected failures.

---

# 11.12 Final Acceptance Checklist

The commissioning administrator shall verify:

Operating System

□ Pass

Storage

□ Pass

Networking

□ Pass

Remote Administration

□ Pass

Documentation

□ Pass

Backups

□ Pass

Security

□ Pass

Operational Validation

□ Pass

Only after every category has passed may the node be accepted into production.

---

# 11.13 Node Acceptance Record

Record:

Node Name:

Hardware Identifier:

Installation Date:

Commissioned By:

Verified By:

Proxmox Version:

Kernel Version:

Final Status:

☐ Accepted

☐ Rejected

Comments:

---

# 11.14 Lessons Learned

Separating validation into functional categories significantly simplifies troubleshooting and future audits.

Configuration backups taken immediately after validation provide a reliable production baseline.

Updating Project Polaris documentation before accepting the node into production ensures operational documentation always reflects the deployed infrastructure.

Successful validation represents the transition from installation to production readiness.
------------------------------------------------------------------------------
---

# 12. Production Acceptance

## 12.1 Objective

Formally accept the Proxmox VE host into the Project Polaris production environment.

Successful completion of this section signifies that the node has satisfied all installation, validation, documentation, and operational requirements established by Project Polaris.

Upon acceptance, the node becomes subject to all Project Polaris operational standards, maintenance procedures, backup policies, and change management practices.

---

# 12.2 Acceptance Criteria

A node may be accepted into production only after all of the following conditions have been satisfied.

### Installation

□ Proxmox VE installation completed successfully.

□ Initial configuration completed.

□ Repository configuration verified.

□ Operating system updated.

---

### Configuration

□ Administrative desktop configured.

□ Remote administration configured.

□ Storage configured.

□ Network configuration verified.

---

### Validation

□ All Section 11 validation categories passed.

□ No unresolved errors remain.

□ No failed services.

□ No outstanding installation tasks.

---

### Documentation

The following documentation has been updated.

□ Hardware Inventory

□ Storage Architecture

□ IP Address Plan

□ DNS Registry

□ VM Structure (if applicable)

□ Maintenance Backlog

□ Installation Guide Revision (if applicable)

---

### Backup

□ Configuration backup completed.

□ Backup location verified.

□ Recovery documentation reviewed.

---

# 12.3 Administrative Acceptance

The commissioning administrator shall verify:

□ Host complies with STD-001.

□ Host complies with STD-002.

□ Host complies with SA-001.

□ Host is ready for production workloads.

---

# 12.4 Production Registration

Record the following information.

| Item | Value |
|------|-------|
| Hostname | |
| Hardware Identifier | |
| Hardware Inventory Document | |
| Installation Date | |
| Production Acceptance Date | |
| Installed By | |
| Verified By | |
| Current Proxmox Version | |
| Current Kernel Version | |

---

# 12.5 Operational Handover

Upon acceptance:

- The node becomes part of the Project Polaris production infrastructure.
- Future modifications shall follow Project Polaris operational procedures.
- Configuration changes shall be documented.
- Backups shall be maintained according to the Cluster Administration Guide.
- Significant architectural changes shall be reviewed before implementation.

---

# 12.6 Post-Installation Actions

Following production acceptance:

1. Join the administrative cluster (if applicable).

2. Configure production virtual machines.

3. Configure monitoring.

4. Configure scheduled backups.

5. Update project documentation.

6. Record any implementation-specific notes for future reference.

---

# 12.7 Acceptance Statement

The undersigned certify that this Proxmox VE host has been installed, configured, validated, and documented in accordance with Project Polaris standards.

The node is approved for production use.

---

Commissioned By:

_____________________________________

Date:

_____________________________________

Verified By:

_____________________________________

Date:

_____________________________________

---

# 12.8 Lessons Learned

Project Polaris demonstrated that a standardized installation procedure significantly reduces deployment time while improving consistency across multiple hosts.

Separating standards, procedures, operations, and architecture documentation simplifies long-term maintenance and enables clean-room rebuilds.

Formal production acceptance ensures that infrastructure enters service only after technical validation, documentation, and recovery planning have been completed.

---

# Appendices

Appendix A – Repository Configuration

Appendix B – Hostname Migration Procedure

Appendix C – Administrative Desktop Environment

Appendix D – RustDesk Installation

Appendix E – Tailscale Installation

Appendix F – Storage Standards

Appendix G – Validation Commands

Appendix H – Troubleshooting

---

# Revision History

| Version | Date | Description |
|----------|------|-------------|
| 1.0 | 2026-07-19 | Initial Project Polaris Proxmox VE 9 Installation Guide established. |
-------------------------------------------------------------------------------

