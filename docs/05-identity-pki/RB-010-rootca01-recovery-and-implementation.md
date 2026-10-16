RB-010  
ROOTCA01 Recovery and Implementation

**Part 1 - Build Preparation and Environment Validation**

**Document ID**

RB-010

**Project**

Project Polaris

**Document Type**

Recovery and Implementation Runbook

**Status**

Approved Draft - Operational Validation Pending

**Primary System**

ROOTCA01

# 1\. Document Information

Document Name: ROOTCA01 Recovery and Implementation

Document ID: RB-010

Project: Project Polaris

Document Type: Recovery and Implementation Runbook

Status: Draft until operational validation and destructive rebuild validation are complete.

Related Documents:

-   PKI-001 - Project Polaris Public Key Infrastructure Architecture
-   Project Polaris VM Structure
-   Project Polaris IP Address Registry
-   Project Polaris DNS Registry
-   RB-010 - ROOTCA01 Recovery and Implementation (current working copy)

# 2\. Purpose

This runbook provides complete instructions to build, validate, operate, recover, and rebuild the Project Polaris offline Root Certification Authority (ROOTCA01).

The runbook assumes no prior experience with Proxmox VE, Linux, Windows Server, Active Directory Certificate Services (AD CS), or Public Key Infrastructure (PKI). Every required action shall be documented explicitly.

# 3\. Scope

This runbook covers the complete lifecycle of ROOTCA01, including:

-   Environment validation
-   Virtual machine creation
-   Windows Server installation
-   Initial operating system configuration
-   Offline Root Certification Authority installation
-   PKI configuration
-   System hardening
-   Operational procedures
-   Backup procedures
-   Disaster recovery
-   Planned evaluation-expiration rebuilds
-   Validation
-   Troubleshooting

This runbook does not replace PKI-001, which remains the authoritative architecture document for the Project Polaris PKI.

# 4\. Operator Contract

1.  No previous technical knowledge is assumed.
2.  Every required action shall be documented.
3.  Every action shall include validation.
4.  Every part shall be validated before continuing.
5.  Every procedure shall be written so that a first-time operator can successfully complete it.
6.  No forward reference may contain information required to complete the current part.
7.  If an operator cannot complete a task using only this runbook, the runbook shall be considered incomplete and shall be corrected before approval.
8.  ROOTCA01 shall be intentionally destroyed after implementation and successfully rebuilt using only this runbook before RB-010 is considered operationally complete.

# 5\. Success Criteria

-   ROOTCA01 is successfully built using only RB-010.
-   ROOTCA01 is fully operational.
-   All validation steps pass.
-   Backup procedures are validated.
-   ROOTCA01 is intentionally destroyed.
-   ROOTCA01 is successfully rebuilt using only RB-010.
-   Deficiencies discovered during validation are corrected.
-   The corrected runbook successfully completes a subsequent validation.

# 6\. Requirements

## 6.1 Hardware and Virtual Resource Requirements

**Resource**

**Minimum Requirement**

Proxmox host

Operational

Virtual CPU

2 vCPU

Memory

4 GB RAM

Virtual disk

80 GB

Network adapter

1 virtual NIC

Network bridge

vmbr2

Storage location

Approved VM datastore; confirm during EV-03

## 6.2 Software Requirements

**Software**

**Requirement**

Proxmox VE

Operational

Windows Server 2016 Evaluation ISO

Available in NAS-ISO-Repo (homelab)

Web browser

Microsoft Edge, Firefox, Chrome, or equivalent

## 6.3 Account Requirements

-   A Proxmox administrative account capable of viewing the host, opening the host shell, reading storage, and creating virtual machines.

## 6.4 Documentation Requirements

-   PKI-001 - Project Polaris Public Key Infrastructure Architecture
-   Project Polaris VM Structure
-   Project Polaris IP Address Registry
-   Project Polaris DNS Registry
-   RB-010 - ROOTCA01 Recovery and Implementation

Additional documents may be added later only when actual implementation proves they are required to complete the runbook.

# 7\. Environment Validation Rules

No virtual machine creation or implementation activity may begin until every validation in this part passes.

If any validation fails:

1.  Stop the runbook.
2.  Resolve the failure.
3.  Repeat the failed validation.
4.  Continue only after the validation passes.
########################################################################################################################
# Milestone 1 - Initial Validation
#
# Purpose - establish baseline requirements for ROOTCA01 rebuild
########################################################################################################################

# EV-01 - Verify the Proxmox Host Is Operational

## Purpose

Confirm that the Proxmox management interface is reachable before attempting any implementation work.

## Requirements

-   A computer connected to a network that can reach the Proxmox host.
-   A supported web browser.
-   Proxmox management address:

https://192.168.10.2:8006

## GUI Procedure

1.  Open a web browser.
2.  Click the address bar.
3.  Enter https://192.168.10.2:8006 and press Enter.
4.  If a browser security warning appears, select the option to display advanced information, then select the option to continue to the site.
5.  Confirm that the Proxmox Virtual Environment login page appears.

## Expected Result

The Proxmox login page opens. The optional Windows test reports:

TcpTestSucceeded : True

## Validation

☐ The browser reached https://192.168.10.2:8006.

☐ The Proxmox login page appeared.

## Failure Action

1.  Confirm the computer is connected to the correct network.
2.  Confirm the address was entered exactly as shown.
3.  Run Test-NetConnection 192.168.10.2 -Port 8006 from Windows PowerShell.
4.  If PingSucceeded and TcpTestSucceeded are both false, stop and troubleshoot network connectivity.
5.  If the host responds to ping but TCP port 8006 fails, troubleshoot the Proxmox web service or firewall.
6.  Do not continue until the login page is reachable.

## Operator Notes

A certificate warning is expected when the browser does not yet trust the certificate used by the Proxmox web interface.

# EV-02 - Verify Proxmox Administrative Login

## Purpose

Confirm that the operator can authenticate and administer the Proxmox host.

## Requirements

-   EV-01 passed.
-   Valid Proxmox administrative credentials.

## GUI Procedure

1.  At the Proxmox login page, locate User name.
2.  Enter the approved administrative username.
3.  Confirm the Realm matches the account type. For the root account, select Linux PAM standard authentication.
4.  Enter the password.
5.  Click Login.
6.  Wait for the Proxmox management interface to load.
7.  In the left navigation panel, click homelab.
8.  Click Shell.
9.  Confirm that a command prompt appears.

## Expected Result

The management interface loads and displays Datacenter and the host named homelab. The Shell shows a prompt similar to:

root@homelab:~#

## Validation

☐ Administrative login succeeded.

☐ Datacenter is visible.

☐ The host named homelab is visible.

☐ The Shell tab opens successfully.

## Failure Action

1.  Verify the username.
2.  Verify the selected realm.
3.  Re-enter the password carefully.
4.  Confirm Caps Lock is not enabled.
5.  Do not continue until administrative access succeeds.

## Operator Notes

The vertical panel on the left side of the interface is the Proxmox inventory tree. It contains Datacenter, the host homelab, storage entries, virtual machines, and containers.

# EV-03 - Verify CPU, Memory, and Storage Resources

## Purpose

Confirm that the host has enough available resources to create ROOTCA01.

## Minimum Requirement

**Resource**

**Required**

CPU allocation

2 vCPU

Memory allocation

4 GB

Virtual disk

80 GB

## GUI Procedure

1.  In the left navigation panel, click homelab.
2.  Click Summary.
3.  Locate the CPU and memory utilization information.
4.  Record current CPU utilization, total installed memory, used memory, and available memory.
5.  Confirm that allocating another 2 vCPU and 4 GB RAM will not exhaust the host.
6.  In the left navigation panel, click Datacenter.
7.  Click Storage.
8.  Locate the datastore intended for the ROOTCA01 virtual disk.
9.  Confirm the datastore is enabled, active, and permitted to store VM disk images.
10.  Confirm at least 80 GB of usable capacity is available.

## Expected Result

-   The host is not under sustained CPU exhaustion.
-   At least 4 GB RAM can be allocated without exhausting host memory.
-   The selected datastore is active.
-   At least 80 GB is available.
-   Any applicable ZFS pool reports ONLINE.

## Validation

☐ 2 vCPU can be allocated.

☐ 4 GB RAM can be allocated.

☐ At least 80 GB of storage is available.

☐ The selected datastore is active.

☐ The applicable storage pool is healthy.

## Failure Action

1.  Stop the runbook.
2.  Do not reduce the documented minimum merely to continue.
3.  Review existing VM allocations and host utilization.
4.  Complete the approved node-capacity and optimization review.
5.  Repeat EV-03 after corrective action.

## Operator Notes

Record the selected datastore name here for use in Part 2: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

# EV-04 - Verify the Windows Server 2016 Evaluation ISO Exists

## Purpose

Confirm the required Windows installation media is available in Proxmox.

## Requirements

-   Proxmox administrative access.
-   NAS-ISO-Repo (homelab) available.

## GUI Procedure

1.  In the left navigation panel, expand Datacenter if necessary.
2.  Click NAS-ISO-Repo (homelab).
3.  Click ISO Images.
4.  Review the listed ISO files.
5.  Locate the approved Windows Server 2016 Evaluation ISO.
6.  Confirm the ISO is not marked unavailable or errored.

## Expected Result

NAS-ISO-Repo reports active and the approved Windows Server 2016 Evaluation ISO appears in the GUI and CLI storage listings.

## Validation

☐ NAS-ISO-Repo is active.

☐ The Windows Server 2016 Evaluation ISO is listed.

☐ The exact filename is recorded below for Part 2.

## Failure Action

1.  Stop the runbook.
2.  Confirm NAS-ISO-Repo is mounted and active.
3.  Upload or copy the approved ISO into NAS-ISO-Repo.
4.  Repeat EV-04.
5.  Do not substitute another Windows version without an approved architectural change.

## Operator Notes

Exact ISO filename: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

# EV-05 - Verify vmbr2 Exists and Is Active

## Purpose

Confirm ROOTCA01 can be attached to the same production network used by DC01 and CA01 when network access is required.

## Required Bridge

vmbr2

## GUI Procedure

1.  In the left navigation panel, click homelab.
2.  Click System.
3.  Click Network.
4.  Locate vmbr2.
5.  Confirm the row exists.
6.  Confirm the interface is configured and active.
7.  Do not edit the bridge during this validation.

## Expected Result

-   vmbr2 exists in the GUI.
-   vmbr2 exists in the Linux network configuration.
-   ip link show vmbr2 reports the interface as available and normally state UP.

## Validation

☐ vmbr2 exists.

☐ vmbr2 is configured.

☐ vmbr2 is active.

☐ No network changes were made.

## Failure Action

1.  Stop the runbook.
2.  Do not create a substitute bridge.
3.  Review the production network configuration and topology documentation.
4.  Correct the existing bridge only through an approved network change.
5.  Repeat EV-05.

## Operator Notes

ROOTCA01 will normally remain offline. vmbr2 is validated now because controlled connectivity is required during installation, patching, publication, backup, and recovery activities.

# EV-06 - Verify the Proxmox System Time

## Purpose

Confirm the host clock is correct before creating a Certification Authority. Accurate time is essential to certificate validity, logging, authentication, and PKI operations.

## CLI Procedure

Open homelab -> Shell and run:

date

timedatectl status

Confirm the local date, time, and timezone are correct. Confirm System clock synchronized reports yes and NTP service reports active.

## Expected Result

The date, local time, and timezone are correct, and timedatectl confirms the system clock is synchronized.

## Validation

☐ Local date is correct.

☐ Local time is correct.

☐ Timezone is correct.

☐ System clock synchronized reports yes.

☐ NTP service reports active.

## Failure Action

1.  Stop the runbook.
2.  Record the timedatectl status output.
3.  Run systemctl status systemd-timesyncd --no-pager.
4.  If systemd-timesyncd does not exist or is inactive, run systemctl status chrony --no-pager.
5.  Do not modify time services until the current Proxmox time configuration is identified.
6.  Correct the synchronization problem.
7.  Repeat EV-06.

## Operator Notes

Recorded time and timezone: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

# EV-07 - Verify the Planned VMID Is Available

## Purpose

Confirm the approved ROOTCA01 VMID is not already assigned to a virtual machine or container.

## Definition: Proxmox Inventory Tree

The Proxmox inventory tree is the vertical navigation panel on the left side of the web interface. It normally displays Datacenter, homelab, storage, virtual machines, and containers. Each VM is normally shown with its VMID and name.

## Requirement

The approved ROOTCA01 VMID must be obtained from the authoritative Project Polaris VM Structure document. This runbook shall not invent a VMID.

## GUI Procedure

1.  Locate the navigation panel on the left side of the Proxmox interface.
2.  At the top of the panel, confirm the view selector displays Server View.
3.  Expand Datacenter if it is collapsed.
4.  Expand homelab if it is collapsed.
5.  Review every displayed VM and container.
6.  Confirm the approved ROOTCA01 VMID does not appear.

## Expected Result

The approved VMID is absent from the GUI inventory tree, qm list, and pct list.

## Validation

☐ ROOTCA01 VMID has been formally approved.

☐ The VMID does not appear in the GUI.

☐ The VMID does not appear in qm list.

☐ The VMID does not appear in pct list.

☐ The VMID is confirmed in the VM Structure document.

## Failure Action

1.  Stop the runbook.
2.  Do not delete or reuse the existing object.
3.  Review the VM Structure document.
4.  Select and approve a different VMID.
5.  Update the VM Structure document.
6.  Repeat EV-07.

## Operator Notes

Approved ROOTCA01 VMID: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

# EV-08 - Verify Required Documentation Is Available

## Purpose

Confirm the operator can access the authoritative documents required to complete and validate the build.

## Required Documents

-   PKI-001 - Project Polaris Public Key Infrastructure Architecture
-   Project Polaris VM Structure
-   Project Polaris IP Address Registry
-   Project Polaris DNS Registry
-   RB-010 - ROOTCA01 Recovery and Implementation

## GUI Procedure

1.  Open the approved Project Polaris documentation location.
2.  Locate each required document.
3.  Open each document.
4.  Confirm each document is readable.
5.  Confirm RB-010 is the current working version being validated.

## Expected Result

Every required document is accessible and readable before implementation begins.

## Validation

☐ PKI-001 is available.

☐ VM Structure is available.

☐ IP Address Registry is available.

☐ DNS Registry is available.

☐ The current RB-010 working copy is available.

## Failure Action

1.  Stop the runbook.
2.  Retrieve the current authoritative copy.
3.  Confirm it is readable.
4.  Repeat EV-08.

## Operator Notes

Authoritative documentation location: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

# 8\. Part 1 Acceptance Checklist

☐ EV-01 through EV-08 were executed.

☐ Every validation passed.

☐ The ROOTCA01 VMID was approved and recorded.

☐ The exact Windows Server ISO filename was recorded.

☐ The intended VM datastore was confirmed and recorded.

☐ vmbr2 was validated.

☐ The Proxmox host clock and NTP synchronization were validated.

☐ All required documents are accessible.

☐ No unresolved prerequisite failures remain.

# 9\. Validation Status

Validation Method: Execute EV-01 through EV-08 against the Project Polaris production environment before creating ROOTCA01.

☐ Not Started

☐ Passed

☐ Failed

Validation date: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

Operator: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

Operator Notes:

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

####################################################################################################################################################
# Milestone 2 - Hardware structure build
#
# Purpsoe - Steps 1-4 establish the procedure to rebuild ROOTCA01's hardware structure.
####################################################################################################################################################

# 10\. Part 1 Completion Rule

Part 1 is complete only after every environment validation has been executed and passed. Part 2 begins with creation of the ROOTCA01 virtual machine.

\# PART 2

\---

\# Step 2.1 — Access the Proxmox Web Interface

\## Purpose

Access the Proxmox Virtual Environment management interface to begin creation of the Windows Server 2019 virtual machine that will later become the reusable Project Polaris baseline.

\---

\## Estimated Duration

5 minutes

\---

\## Requirements

\* Proxmox host powered on

\* Administrative workstation connected to the management network

\* Network connectivity to the Proxmox management interface

\* Proxmox administrative credentials

\---

\## Screenshot Placeholder

\*\*Screenshot 2.1-A — Proxmox Login Page\*\*

\*\*Screenshot 2.1-B — Proxmox Datacenter Summary\*\*

\---

\## GUI Procedure

1\. Open a web browser.

2\. Browse to the Proxmox management interface.

Example:

\`\`\`

https://<Proxmox-IP>:8006

\`\`\`

3\. If the browser displays a certificate warning, continue to the site.

During initial deployment, Project Polaris uses the default Proxmox certificate until the internal PKI infrastructure is deployed.

This warning is expected.

4\. The Proxmox login page appears.

5\. Enter the administrative username.

6\. Enter the corresponding password.

7\. Select the appropriate authentication realm.

8\. Select \*\*Login\*\*.

9\. Wait for the Proxmox dashboard to load.

10\. Confirm the Datacenter view appears.

\---

\## CLI Procedure

Not applicable.

All virtual machine creation is performed through the Proxmox graphical interface to ensure consistency with documented screenshots.

\---

\## Validation

Verify the following:

\* Login completed successfully.

\* Datacenter is visible.

\* The Proxmox node appears online.

\* Storage resources display without errors.

\* Existing virtual machines appear in the navigation tree.

\---

\## Failure Action

If login fails:

\* Verify keyboard layout.

\* Confirm username.

\* Confirm authentication realm.

\* Verify password.

\* Confirm the Proxmox host is reachable over the network.

If the dashboard fails to load:

\* Refresh the browser.

\* Verify network connectivity.

\* Verify the Proxmox services are running.

\---

\## Expected Result

The Proxmox management dashboard is open and ready for virtual machine creation.

\---

\## Operator Notes

Certificate warnings are expected during initial deployment and do not indicate a failure.

Future Project Polaris PKI implementation replaces the temporary certificate with an internally trusted certificate.

\---

\# Step 2.2 — Start the Create Virtual Machine Wizard

\## Purpose

Launch the Proxmox virtual machine creation wizard.

This wizard defines the hardware configuration that Windows Server will use throughout installation.

\---

\## Estimated Duration

2 minutes

\---

\## Requirements

\* Successfully logged into Proxmox

\* Appropriate node selected

\---

\## Screenshot Placeholder

\*\*Screenshot 2.2-A — Create VM Button\*\*

\*\*Screenshot 2.2-B — Create VM Wizard\*\*

\---

\## GUI Procedure

1\. In the navigation pane, select the desired Proxmox node.

2\. Confirm the node status is \*\*Online\*\*.

3\. Select \*\*Create VM\*\* from the upper-right toolbar.

4\. Wait for the Create Virtual Machine wizard to appear.

\## Validation

Verify:

\* The Create VM wizard opens successfully.

\* The wizard begins on the \*\*General\*\* tab.

\* No error messages appear.

\---

\## Failure Action

If the wizard does not open:

\* Verify the node is selected.

\* Refresh the browser.

\* Confirm sufficient permissions exist.

\* Verify the Proxmox node is operational.

\---

\## Expected Result

The Create VM wizard is ready for configuration.

\---

\## Operator Notes

All virtual machine settings are configured during the wizard before Windows installation begins.

\---

\# Step 2.3 — Configure the General Settings

\## Purpose

Assign the identity information used by Proxmox to manage the virtual machine.

These settings identify the virtual machine within the Project Polaris environment.

\---

\## Estimated Duration

5 minutes

\---

\## Requirements

\* Create VM wizard open

\---

\## Screenshot Placeholder

\*\*Screenshot 2.3-A — General Tab Configuration\*\*

\---

\## GUI Procedure

1\. Verify the \*\*General\*\* tab is selected.

2\. Enter the approved VM ID.

IAW VMID inventory Plan

3\. Enter the virtual machine name.

IAW VMID inventory Plan

4\. Confirm the remaining values remain at their defaults unless otherwise required by the environment.

\---

\## Validation

Verify:

\* VM ID is correct.

\* VM Name is correct.

\* No duplicate VM ID warning appears.

\---

\## Failure Action

If the VM ID is already in use:

\* Cancel the wizard.

\* Determine whether an existing VM110 already exists.

\* Remove or renumber the conflicting virtual machine if appropriate.

\* Restart the wizard.

\---

5\. Select \*\*Next\*\*.

\## Expected Result

The General configuration is accepted and the wizard advances to the operating system configuration page.

\---

\## Operator Notes

Project Polaris reserves VM110 as the reusable Windows Server 2019 engineering baseline.

This baseline serves as an operational optimization for future deployments but is never required for disaster recovery.

\---

\# Step 2.4 — Configure the Operating System

\## Purpose

Specify the Windows installation media and firmware configuration required for Project Polaris.

Windows Server 2019 is installed using modern UEFI firmware to align with current enterprise deployment practices.

\---

\## Estimated Duration

5 minutes

\---

\## Requirements

\* Windows Server 2019 installation ISO uploaded to Proxmox storage

\* VirtIO driver ISO uploaded to Proxmox storage

\---

\## Screenshot Placeholder

\*\*Screenshot 2.4-A — Operating System Tab\*\*

\---

\## GUI Procedure

1.Verify storage is NAS-ISO-Repo

2\. Select the uploaded Windows Server 2019 installation ISO.

\`\`

17763.3650.221105-1748.rs5\_release\_svc\_refresh\_SERVER\_EVAL\_x64FRE\_en-us.iso

\`\`

3\. Verify the Guest OS type is configured for Microsoft Windows.

4\. verify the version is configured for 2011/2016/2019

5\. select add additional drive for VirtIO drivers check box

6\. Verify storage is NAS-ISO-Repo

7\. Select virtio-win-0.1.285.iso for ISO image

\## Validation

Verify:

\* Windows Server installation ISO selected.

\* OVMF (UEFI) selected.

\* Guest operating system configured for Microsoft Windows.

\---

\## Failure Action

If the Windows ISO is unavailable:

\* Cancel the wizard.

\* Upload the installation media to Proxmox storage.

\* Restart this procedure.

If incorrect firmware was selected:

\* Return to the Operating System page before continuing.

6\. Select \*\*Next\*\*.

\---

\## Expected Result

The wizard advances to the System configuration page.

\---

\## Operator Notes

Project Polaris standardizes on UEFI firmware for consistency with current enterprise Windows deployments.

\---

\# Step 2.5 — Configure the System Settings

\## Purpose

Configure the virtual machine firmware and hardware interfaces required for reliable Windows Server installation.

\---

\## Estimated Duration

5 minutes

\---

\## Requirements

\* Operating System page completed

\---

\## Screenshot Placeholder

\*\*Screenshot 2.5-A — System Configuration\*\*

\---

\## GUI Procedure

1\. select q35 for Machine

4\. Configure the Bios as:

\`\`\`

OVMF (UEFI)

\`\`\`

5\. Select local-lvm for EFI storage

5\. Leave Secure Boot disabled unless otherwise directed by future documentation.

6\. Confirm the remaining operating system settings remain at their approved defaults.

3\. Leave TPM configuration at the approved project default unless directed otherwise by future documentation.

\## Validation

Verify:

\* UEFI remains selected.

\* No configuration warnings appear.

\* Wizard advances successfully.

\---

\## Failure Action

If warnings appear:

\* Review the configuration.

\* Correct any unintended changes.

\* Continue only after warnings have been resolved.

5\. Select \*\*Next\*\*.

\---

\## Expected Result

The wizard advances to the Hard Disk configuration page.

\---

\## Operator Notes

Project Polaris intentionally minimizes unnecessary deviations from Proxmox defaults unless a documented operational benefit exists.

\---

\# Step 2.6 — Configure the Virtual Hard Disk

\## Purpose

Create the primary virtual disk that will store the Windows Server operating system.

Project Polaris uses the VirtIO SCSI storage controller to provide high-performance virtual storage while maintaining compatibility with Windows through the VirtIO driver installation performed during Windows Setup.

\---

\## Estimated Duration

10 minutes

\---

\## Requirements

\* System configuration completed

\* Target storage available

\---

\## Screenshot Placeholder

\*\*Screenshot 2.6-A — Hard Disk Configuration\*\*

\---

\## GUI Procedure

1\. Select the approved Proxmox storage location.

‘’

VM2

‘’

2\. Configure the bus/device as:

\`\`\`

VirtIO SCSI

\`\`\`

3\. Configure the virtual disk size according to the Project Polaris storage standard.

‘’

100GB

‘’

4\. Leave advanced storage settings at their approved defaults unless otherwise documented.

5\. Confirm the disk configuration.

\---

\## Validation

Verify:

\* Correct storage selected.

\* VirtIO SCSI configured.

\* Virtual disk size matches the implementation standard.

\* Wizard advances without errors.

\---

\## Failure Action

If storage cannot be selected:

\* Verify storage is online.

\* Confirm sufficient free capacity exists.

\* Resolve storage issues before continuing.

If an incorrect controller is selected:

\* Return to the Hard Disk page.

\* Select VirtIO SCSI.

\* Continue after validation.

6\. Select \*\*Next\*\*.

\---

\## Expected Result

The virtual hard disk is configured and the wizard advances to CPU configuration.

\---

\## Operator Notes

Windows Server installation will not initially recognize the VirtIO SCSI virtual disk until the appropriate VirtIO storage driver is loaded during Windows Setup.

This behavior is expected and is documented later in the installation procedure.

**Step 2.7 — Configure the Virtual Processor**

**Purpose**

Configure the virtual processor resources assigned to the Windows Server 2019 virtual machine.

The selected processor configuration provides sufficient performance for installation, updates, and baseline engineering while remaining consistent with Project Polaris resource planning.

**Estimated Duration**

5 minutes

**Requirements**

-   Hard Disk configuration completed successfully

**Screenshot Placeholder**

**Screenshot 2.7-A — CPU Configuration**

**GUI Procedure**

1.  The **CPU** configuration page opens automatically.
2.  Verify the processor type is set to the Proxmox default unless otherwise documented.
3.  Set cores to 2.
4.  Verify the CPU topology reflects the approved configuration.
5.  Leave advanced CPU options at their default values unless specifically documented elsewhere in this runbook.

**Validation**

Verify the following:

-   CPU configuration is accepted.
-   No warnings are displayed.
-   The wizard advances to the Memory configuration page.

**Failure Action**

If configuration errors occur:

-   Review processor allocation.
-   Confirm adequate CPU resources remain available on the Proxmox host.
-   Correct any configuration errors before proceeding.

1.  Select **Next**.

**Expected Result**

The virtual processor configuration is complete and the wizard advances to Memory configuration.

**Operator Notes**

Project Polaris intentionally avoids unnecessary processor over-allocation to preserve host performance and maintain predictable resource utilization.

**Step 2.8 — Configure Virtual Memory**

**Purpose**

Assign memory resources required for Windows Server installation and baseline operation.

**Estimated Duration**

5 minutes

**Requirements**

-   CPU configuration completed

**Screenshot Placeholder**

**Screenshot 2.8-A — Memory Configuration**

**GUI Procedure**

1.  The **Memory** configuration page opens.
2.  Configure memory according to the approved Project Polaris implementation standard.

‘’

4096 by default

‘’

1.  Leave ballooning enabled or disabled according to the approved implementation.
2.  Verify all remaining memory options remain at their documented values.

**Validation**

Verify:

-   Memory configuration is accepted.
-   No resource warnings appear.
-   Wizard advances to Network configuration.

**Failure Action**

If insufficient memory is available:

-   Verify available host memory.
-   Reduce allocations on other virtual machines if appropriate.
-   Continue only after adequate resources are available.

1.  Select **Next**.

**Expected Result**

The wizard advances to Network configuration.

**Operator Notes**

Memory values documented in this runbook reflect the approved Project Polaris implementation and may differ from Proxmox defaults.

**Step 2.9 — Configure Network Settings**

**Purpose**

Attach the virtual machine to the appropriate virtual network for installation.

Network configuration during baseline creation is intentionally minimal because static network configuration is performed later in the implementation process.

**Estimated Duration**

5 minutes

**Requirements**

-   Memory configuration completed

**Screenshot Placeholder**

**Screenshot 2.9-A — Network Configuration**

**GUI Procedure**

1.  Verify the correct virtual bridge is selected.

‘’

Vmbr2

‘’

1.  Confirm the virtual network adapter model matches the approved implementation.

‘’

Default (VirtIO(paravirtualized)

‘’

1.  Leave VLAN settings at their default values unless otherwise documented.
2.  Review the network configuration.
3.  Leave other setting as default unless otherwise documented.

**Validation**

Verify:

-   Correct bridge selected.
-   Network adapter configured successfully.
-   Wizard advances to the Confirm page.

**Failure Action**

If the required bridge is unavailable:

-   Verify the bridge exists on the Proxmox host.
-   Correct the bridge configuration before continuing.

1.  Select **Next**.

**Expected Result**

The network configuration is accepted.

**Operator Notes**

Static IP addressing is intentionally deferred until later implementation.

Maintaining DHCP during baseline creation allows VM110 to remain reusable across future deployments without requiring immediate network modification.

**Step 2.10 — Review Virtual Machine Configuration**

**Purpose**

Review every configuration item before the virtual machine is created.

This validation provides an opportunity to correct configuration errors before hardware is provisioned.

**Estimated Duration**

5 minutes

**Requirements**

-   Network configuration completed

**Screenshot Placeholder**

**Screenshot 2.10-A — Summary Page**

**GUI Procedure**

1.  Review every configuration category displayed on the Summary page.
2.  Verify:
    -   VM ID
    -   VM Name
    -   Firmware
    -   Storage
    -   Processor
    -   Memory
    -   Network
    -   Installation media
3.  If corrections are required, select **Back** and modify the appropriate configuration page.
4.  After validation is complete, select **Finish**.

**CLI Procedure**

Not applicable.

**Validation**

Verify:

-   Summary accurately reflects the approved Project Polaris configuration.
-   No warning messages appear.
-   Finish completes successfully.

**Failure Action**

If incorrect settings are identified:

-   Return to the appropriate wizard page.
-   Correct the configuration.
-   Review the Summary page again before creating the virtual machine.

**Expected Result**

Proxmox begins creating the virtual machine.

**Operator Notes**

Reviewing the Summary page significantly reduces recovery time by identifying configuration mistakes before installation begins.

**Step 2.11 — Verify Successful Virtual Machine Creation**

**Purpose**

Confirm Proxmox successfully created the virtual machine and associated virtual hardware.

**Estimated Duration**

5 minutes

**Requirements**

-   Virtual machine creation completed

**Screenshot Placeholder**

**Screenshot 2.11-A — Newly Created VM110**

**GUI Procedure**

1.  Wait for Proxmox to finish creating the virtual machine.
2.  Close the Create VM wizard if necessary.
3.  Locate **ROOTCA01** within the Proxmox navigation tree.
4.  Select the virtual machine.
5.  Open the **Summary** page.
6.  Verify the virtual machine status displays as **Stopped**.

**CLI Procedure**

Not applicable.

**Validation**

Verify:

-   ROOTCA01 VM exists.
-   No creation errors occurred.
-   Summary information is displayed.
-   Virtual hardware is listed.

**Failure Action**

If ROOTCA01 VM is missing:

-   Review the Proxmox task log.
-   Correct any reported errors.
-   Repeat the virtual machine creation procedure if necessary.

**Expected Result**

**ROOTCA01** exists and is ready for final configuration before Windows installation.

**Operator Notes**

The virtual machine has been created but no operating system has yet been installed.

**Step 2.12 — Validate Virtual Hardware Configuration**

**Purpose**

Perform a final verification of the virtual hardware before powering on the virtual machine.

This validation ensures the Windows installation begins using the approved Project Polaris hardware configuration.

**Estimated Duration**

10 minutes

**Requirements**

-   ROOTCA01 successfully created

**Screenshot Placeholder**

**Screenshot 2.12-A — Hardware Tab**

**GUI Procedure**

1.  Select **ROOTCA01**.
2.  Open the **Hardware** tab.
3.  Verify the presence of:
    -   Virtual hard disk
    -   VirtIO SCSI controller
    -   Windows Server installation ISO
    -   VirtIO driver ISO
    -   Network adapter
    -   Memory allocation
    -   Processor allocation
    -   EFI Disk
4.  Confirm no unexpected hardware devices are present.
5.  Close the Hardware page after validation.

**CLI Procedure**

Not applicable.

**Validation**

Verify:

-   All required virtual hardware exists.
-   VirtIO SCSI controller is present.
-   Windows installation ISO is attached.
-   VirtIO driver ISO is attached.
-   No configuration errors appear.

**Failure Action**

If hardware is missing:

-   Power off the virtual machine if necessary.
-   Add or correct the missing hardware.
-   Repeat this validation before continuing.

**Expected Result**

ROOTCA01 hardware configuration matches the approved Project Polaris standard and is ready for Windows Server installation.

**Operator Notes**

Completion of Part 2 confirms the virtual machine has been fully provisioned and validated.

The next phase installs Windows Server 2019 using the approved Project Polaris implementation.

##Part 3

**Step 3.1 — Start the Virtual Machine**

**Purpose**

Power on the newly created virtual machine and begin the Windows Server 2019 installation process.

**Estimated Duration**

2 minutes

**Requirements**

-   Part 2 completed successfully
-   Windows Server 2019 installation ISO attached
-   VirtIO driver ISO attached
-   Virtual hardware validated

**Screenshot Placeholder**

**Screenshot 3.1-A — ROOTCA01 Summary**

**Screenshot 3.1-B — Console Window During Boot**

**GUI Procedure**

1.  Select **ROOTCA01** from the Proxmox navigation tree.
2.  Verify the virtual machine status displays **Stopped**.
3.  Select **Start** from the toolbar.
4.  Wait for the status to change to **Running**.
5.  Select **Console**.
6.  Observe the virtual machine beginning the Windows installation boot sequence.
7.  If prompted to boot from the installation media, press any key.
8.  Wait for the Windows Setup environment to load.

**CLI Procedure**

Not applicable.

**Validation**

Verify:

-   VM powers on successfully.
-   Console displays the Windows boot sequence.
-   Windows Setup loads without errors.

**Failure Action**

If the virtual machine fails to start:

-   Review the Proxmox task log.
-   Verify the installation ISO remains attached.
-   Confirm sufficient host resources are available.
-   Correct the issue before continuing.
-   If the Start button returns "Error 500: got no worker upid – start worker failed", first verify whether the VM actually started by checking the Summary page. If the VM is already running, continue normally. If the VM is in an inconsistent state, select Shutdown → Stop, wait until the VM reports Stopped, then start it again.  If “Error 500: got no worker upid – start worker failed” is displayed, select stop machine from the shutdown drop down menu, verify system is stopped, restart system.
-   If unable to boot from media is displayed: select options in the proxmox menu -> double click boot order -> click and drag the hamburger icon next to IDE0 to the top of the list -> restart VM.

**Expected Result**

The Windows Setup environment loads and displays the initial language selection screen.

**Operator Notes**

The first boot from the installation media may take longer than subsequent boots. This behavior is expected.

**Step 3.2 — Configure Initial Windows Setup**

**Purpose**

Configure the initial Windows installation language and regional preferences before beginning installation.

**Estimated Duration**

5 minutes

**Requirements**

-   Windows Setup loaded successfully

**Screenshot Placeholder**

**Screenshot 3.2-A — Windows Setup Language Screen**

**GUI Procedure**

1.  Review the Windows Setup language page.
2.  Configure the following options as appropriate for the deployment:
    -   Language to install
    -   Time and currency format
    -   Keyboard or input method
3.  Verify all selections.
4.  Select **Next**.
5.  Select **Install now**.
6.  Wait while Windows Setup prepares the installation.

**Validation**

Verify:

-   Windows accepts the selected regional settings.
-   Installation preparation begins successfully.

**Failure Action**

If Windows Setup does not continue:

-   Verify keyboard and mouse functionality.
-   Restart the virtual machine if necessary.
-   Confirm the installation media is functioning correctly.

**Expected Result**

Windows proceeds to the operating system selection screen.

**Operator Notes**

Regional settings selected during installation may be modified later if operational requirements change.

**Step 3.3 — Select the Windows Server Edition**

**Purpose**

Select the approved Windows Server 2019 edition used throughout Project Polaris.

**Estimated Duration**

5 minutes

**Requirements**

-   Windows installation prepared successfully

**Screenshot Placeholder**

**Screenshot 3.3-A — Windows Edition Selection**

**GUI Procedure**

1.  Review the available Windows Server editions.
2.  Select Windows Server 2019 Standard Evaluation (desktop experience).
3.  Verify the selected edition before continuing.
4.  Select **Next**.

**Validation**

Verify:

-   Correct Windows Server edition selected.
-   Installation proceeds to the license agreement.

**Failure Action**

If the incorrect edition is selected:

-   Return to the previous screen if possible.
-   Restart installation if necessary before files are installed.

**Expected Result**

The Microsoft Software License Terms page appears.

**Operator Notes**

Selecting the correct edition at installation prevents unnecessary rebuilding later in the deployment process.

**Step 3.4 — Accept the License Agreement**

**Purpose**

Accept the Microsoft Software License Terms required to continue installation.

**Estimated Duration**

2 minutes

**Requirements**

-   Correct Windows Server edition selected

**Screenshot Placeholder**

**Screenshot 3.4-A — License Agreement**

**GUI Procedure**

1.  Review the Microsoft Software License Terms.
2.  Select the option indicating acceptance of the license agreement.
3.  Select **Next**.

**Validation**

Verify:

-   License agreement accepted.
-   Installation advances to installation type selection.

**Failure Action**

If installation does not continue:

-   Verify the license agreement checkbox is selected.
-   Retry the operation.

**Expected Result**

The installation type selection screen appears.

**Operator Notes**

Acceptance of the license agreement is required before Windows Setup permits installation.

**Step 3.5 — Select the Installation Type**

**Purpose**

Specify that Windows Server will perform a new installation on an empty virtual disk.

**Estimated Duration**

2 minutes

**Requirements**

-   License agreement accepted

**Screenshot Placeholder**

**Screenshot 3.5-A — Installation Type Selection**

**GUI Procedure**

1.  Review the available installation options.
2.  Select:

**Custom: Install Windows only (advanced)**

1.  Wait for Windows Setup to search for available storage devices.

**CLI Procedure**

Not applicable.

**Validation**

Verify:

-   Custom installation selected.
-   Windows proceeds to the disk selection page.

**Failure Action**

If Windows does not continue:

-   Verify the installation media is functioning correctly.
-   Restart the installation if necessary.

**Expected Result**

The disk selection page appears.

**Operator Notes**

Because Project Polaris uses the VirtIO SCSI storage controller, Windows will not yet detect the virtual hard disk.

This behavior is expected and will be corrected during the next procedure by loading the VirtIO storage driver.

**Step 3.6 — Observe the Missing Storage Device**

**Purpose**

Confirm the expected Windows behavior before loading the VirtIO storage driver.

This validation distinguishes normal installation behavior from an actual storage failure.

**Estimated Duration**

3 minutes

**Requirements**

-   Disk selection page displayed

**Screenshot Placeholder**

**Screenshot 3.6-A — No Drives Found**

**GUI Procedure**

1.  Observe the Windows disk selection page.
2.  Confirm that no installation disks are currently displayed.
3.  Read the informational message indicating that Windows cannot locate a suitable storage device.
4.  Do **not** cancel the installation.
5.  Do **not** modify the virtual machine hardware.
6.  Prepare to load the VirtIO storage driver during the next procedure.

**CLI Procedure**

Not applicable.

**Validation**

Verify:

-   No installation disks are displayed.
-   Windows reports that no storage devices are available.
-   No hardware errors are reported by Proxmox.

**Failure Action**

If a disk is unexpectedly visible:

-   Stop the installation.
-   Verify the virtual storage controller configuration.
-   Confirm the virtual disk is using the approved VirtIO SCSI controller before proceeding.

If Proxmox reports hardware errors:

-   Power off the virtual machine.
-   Correct the virtual hardware configuration.
-   Restart the installation.

**Expected Result**

Windows displays no available installation disks, confirming that the VirtIO storage driver must be loaded before installation can continue.

**Operator Notes**

This is expected behavior.

Project Polaris intentionally uses the VirtIO SCSI storage controller because it provides improved virtual storage performance and efficiency compared to standard emulated controllers.

The required storage driver is supplied by the attached VirtIO driver ISO and will be loaded during the next step of the installation process.

**Step 3.7 — Load the VirtIO Storage Driver**

**Purpose**

Load the VirtIO SCSI storage driver required for Windows Server Setup to recognize the virtual hard disk.

Project Polaris standardizes on the VirtIO SCSI storage controller because it provides improved virtual storage performance and reduced virtualization overhead compared to legacy emulated storage controllers.

**Estimated Duration**

10 minutes

**Requirements**

-   Windows Setup displaying **No drives found**
-   VirtIO driver ISO attached to the virtual machine

**Screenshot Placeholder**

**Screenshot 3.7-A — Load Driver Window**

**Screenshot 3.7-B — VirtIO Driver Directory**

**GUI Procedure**

1.  On the **Where do you want to install Windows?** screen, select **Load driver**.
2.  Select **Browse**.
3.  Navigate to the attached VirtIO driver CD.
4.  Open the directory corresponding to:
    -   VirtIO SCSI driver
    -   2k19
    -   AMD64 (64-bit)
5.  Select the appropriate driver.
6.  Select **Next**.
7.  Wait while Windows loads the storage driver.
8.  Observe the installation disk list refreshing automatically.

**Validation**

Verify:

-   Driver loads without errors.
-   The virtual hard disk becomes visible.
-   Windows returns to the disk selection screen.

**Failure Action**

If no drivers are displayed:

-   Verify the VirtIO driver ISO is attached.
-   Verify the correct operating system directory was selected.
-   Retry loading the driver.

If the disk still does not appear:

-   Verify the virtual disk uses the VirtIO SCSI controller.
-   Confirm the virtual disk exists in the Proxmox Hardware tab.
-   Restart installation if necessary after correcting the hardware configuration.

**Expected Result**

Windows detects the previously unavailable virtual hard disk and makes it available for installation.

**Operator Notes**

Loading the VirtIO storage driver is expected during every Project Polaris recovery.

This behavior is normal and does not indicate a storage failure.

**Step 3.8 — Select the Installation Disk**

**Purpose**

Choose the newly detected virtual hard disk as the installation destination.

**Estimated Duration**

5 minutes

**Requirements**

-   VirtIO storage driver successfully loaded
-   Installation disk visible

**Screenshot Placeholder**

**Screenshot 3.8-A — Installation Disk Visible**

**GUI Procedure**

1.  Review the available storage devices.
2.  Verify only the expected virtual disk is displayed.
3.  Select the unallocated virtual disk.
4.  Select **Next**.
5.  Wait while Windows creates the required partitions automatically.

**Validation**

Verify:

-   Correct virtual disk selected.
-   Windows automatically creates the required EFI, Recovery, and Primary partitions.
-   File copy begins.

**Failure Action**

If multiple unexpected disks appear:

-   Stop the installation.
-   Verify the virtual hardware configuration.
-   Continue only after confirming the correct installation disk.

If partition creation fails:

-   Delete all partitions on the virtual disk.
-   Retry the installation.

**Expected Result**

Windows begins copying installation files to the virtual hard disk.

**Operator Notes**

Project Polaris allows Windows Setup to automatically create the required partitions to ensure compatibility with UEFI boot mode.

**Step 3.9 — Monitor Windows Installation**

**Purpose**

Monitor Windows Server installation while installation files are copied, expanded, and configured.

**Estimated Duration**

20–40 minutes

**Requirements**

-   Installation files copying successfully

**Screenshot Placeholder**

**Screenshot 3.9-A — Windows Installation Progress**

**GUI Procedure**

1.  Observe the Windows installation progress.
2.  Allow each installation phase to complete without interruption.
3.  The installation progresses through several stages, including:
    -   Copying Windows files
    -   Installing features
    -   Installing updates
    -   Finishing installation
4.  Allow Windows to restart automatically whenever prompted.
5.  Do not interrupt automatic reboots.

**Validation**

Verify:

-   Installation progresses normally.
-   Progress percentages continue increasing.
-   Automatic reboots complete successfully.

**Failure Action**

If installation appears frozen for an extended period:

-   Observe Proxmox task activity.
-   Verify disk activity remains present.
-   Restart only if installation has clearly failed.

**Expected Result**

Windows completes installation and begins the first-boot configuration process.

**Operator Notes**

Installation time varies depending on host performance and storage speed.

Temporary pauses during installation are expected.

**Step 3.10 — Complete the Initial Administrator Configuration**

**Purpose**

Create the initial local Administrator password required to access the newly installed operating system.

**Estimated Duration**

10 minutes

**Requirements**

-   Windows installation completed successfully

**Screenshot Placeholder**

**Screenshot 3.10-A — Administrator Password Screen**

**GUI Procedure**

1.  Wait for the Administrator password configuration screen.
2.  Enter the approved Project Polaris Administrator password.
3.  Confirm the password.
4.  Select **Finish**.
5.  Wait while Windows completes initial configuration.

**Validation**

Verify:

-   Password accepted.
-   Windows proceeds to the login screen.

**Failure Action**

If the password is rejected:

-   Verify complexity requirements are satisfied.
-   Re-enter the password carefully.
-   Continue after successful acceptance.

**Expected Result**

Windows displays the login screen.

**Operator Notes**

Administrator credentials should be recorded in accordance with Project Polaris credential management procedures.

**Step 3.11 — Sign In to Windows Server**

**Purpose**

Verify successful installation by logging into the operating system for the first time.

**Estimated Duration**

5 minutes

**Requirements**

-   Administrator password configured

**Screenshot Placeholder**

**Screenshot 3.11-A — Windows Login Screen**

**Screenshot 3.11-B — Server Desktop**

**GUI Procedure**

1.  At the login screen, send **Ctrl+Alt+Delete** using the Proxmox Console menu if required.
2.  Enter the Administrator password.
3.  Select **Sign in**.
4.  Wait while Windows completes the first-login configuration.
5.  Allow Server Manager to open automatically.

**CLI Procedure**

Not applicable.

**Validation**

Verify:

-   Login succeeds.
-   Windows desktop appears.
-   Server Manager launches automatically.
-   No activation or installation errors prevent normal operation.

**Failure Action**

If login fails:

-   Verify the password entered during installation.
-   Retry authentication.
-   Reset the Administrator password if required using approved recovery procedures.

**Expected Result**

The Windows Server desktop is displayed and the operating system is operational.

**Operator Notes**

The first login typically requires additional time while Windows completes user profile initialization.

**Step 3.12 — Validate the Initial Windows Installation**

**Purpose**

Confirm that Windows Server installed successfully before beginning operating system engineering and configuration.

This validation establishes the baseline condition for all remaining implementation procedures.

**Estimated Duration**

10 minutes

**Requirements**

-   Successfully logged into Windows Server

**Screenshot Placeholder**

**Screenshot 3.12-A — Server Manager**

**Screenshot 3.12-B — System Information**

**GUI Procedure**

1.  Verify Server Manager opens successfully.
2.  Open **System Information** or **About**.
3.  Confirm the operating system reports:
    -   Windows Server 2019
    -   Expected edition
    -   Expected system memory
    -   Expected processor configuration
4.  Verify the system responds normally.
5.  Confirm no installation error dialogs are present.

**Validation**

Verify:

-   Windows Server 2019 installed successfully.
-   Desktop loads normally.
-   Server Manager operates correctly.
-   System information reflects the expected virtual hardware.
-   No installation errors remain.

**Failure Action**

If Windows reports missing hardware or installation problems:

-   Review Device Manager.
-   Review Proxmox virtual hardware.
-   Correct hardware issues before continuing with operating system engineering.

**Expected Result**

Windows Server 2019 installation is complete, validated, and ready for the initial engineering configuration described in Part 4.

**Operator Notes**

Completion of Part 3 confirms the operating system has been successfully installed using the approved Project Polaris recovery procedure.

Temporary network-related warnings are expected immediately after Windows installation because the optimized VirtIO network drivers have not yet been installed. These warnings are resolved during Step 4.2.

**\## Part 4**

**Step 4.1 — Verify Initial Server Health**

**Purpose**

Verify that Windows Server completed installation successfully before making any configuration changes.

This validation establishes a known-good operating system state prior to beginning Project Polaris engineering tasks.

**Estimated Duration**

10 minutes

**Requirements**

-   Part 3 completed successfully
-   Logged in as the local Administrator

**Screenshot Placeholder**

**Screenshot 4.1-A — Windows Server Desktop**

**Screenshot 4.1-B — Server Manager Dashboard**

**GUI Procedure**

1.  Allow Server Manager to finish loading.
2.  Wait for background initialization to complete.
3.  Observe the notification area for any startup messages.
4.  Verify the desktop responds normally.
5.  Confirm Server Manager displays without critical errors.
6.  Verify no unexpected error dialogs appear.

**Validation**

Verify:

-   Windows desktop loads successfully.
-   Server Manager opens normally.
-   Keyboard and mouse function correctly.
-   Command Prompt opens successfully.
-   No unexpected operating system errors are present.

**Failure Action**

If Windows reports startup failures:

-   Review displayed error messages.
-   Restart the virtual machine.
-   Confirm the issue persists before continuing.

If repeated startup failures occur:

-   Review the Windows Event Viewer after login.
-   Correct installation issues before proceeding.

**Expected Result**

Windows Server is operating normally and is ready for engineering configuration.

**Operator Notes**

Minor informational notifications immediately after installation are expected.

Critical system errors are not expected.

**Step 4.2 — Install the VirtIO Guest Tools**

**Purpose**

Install the VirtIO guest drivers and utilities required for reliable virtual hardware operation.

These drivers improve storage, network, memory, and virtualization performance while preparing the operating system for integration with Proxmox.

**Estimated Duration**

15 minutes

**Requirements**

-   VirtIO driver ISO attached
-   Logged into Windows as Administrator

**Screenshot Placeholder**

**Screenshot 4.2-A — VirtIO Driver Disc**

**Screenshot 4.2-B — VirtIO Guest Tools Installer**

**GUI Procedure**

1.  Open **File Explorer**.
2.  Open the attached VirtIO driver CD.

Locate the VirtIO guest tools installer. (virtio-win-guests-tools)

1.  Launch the installer.
2.  If prompted by User Account Control, select **Yes**.
3.  Follow the installation wizard using the default options.
4.  Allow all required drivers to install.
5.  Complete the installation wizard.
6.  Restart the virtual machine if prompted.

**Validation**

Verify:

-   Installation completes successfully.
-   No installation errors are reported.
-   Windows recognizes the installed VirtIO drivers after reboot.

**Failure Action**

If installation fails:

-   Verify the VirtIO ISO remains attached.
-   Restart the installer.
-   Review installer error messages before continuing.

**Expected Result**

VirtIO guest drivers are installed successfully and Windows operates normally after reboot.

**Operator Notes**

Installing the complete VirtIO guest tools package ensures all supported virtual hardware operates using optimized drivers rather than generic Microsoft drivers.

**Step 4.3 — Enable the QEMU Guest Agent in Proxmox**

**Purpose**

Enable communication between the Proxmox host and the Windows guest operating system.

The QEMU Guest Agent provides improved management capabilities, including enhanced shutdown operations, IP address reporting, filesystem coordination, and virtualization awareness.

**Estimated Duration**

5 minutes

**Requirements**

-   VirtIO guest tools installed
-   Windows operating normally
-   Proxmox web interface available

**Screenshot Placeholder**

**Screenshot 4.3-A — Proxmox Options Tab**

**Screenshot 4.3-B — QEMU Guest Agent Enabled**

**GUI Procedure**

1.  Return to the Proxmox web interface.
2.  Select **ROOTCA01**.
3.  Open the **Options** tab.
4.  Locate **QEMU Guest Agent**.
5.  Select **Edit**.
6.  Enable the QEMU Guest Agent.
7.  Save the configuration.
8.  Reboot ROOTCA01 for configuration to take affect
9.  Verify qemu guest agent shows enabled in options
10.  Start ROOTCA01

**Validation**

Verify:

-   QEMU Guest Agent is enabled.
-   No Proxmox configuration errors occur.
-   The setting is retained after saving.

**Failure Action**

If the option cannot be enabled:

-   Verify the VirtIO guest tools installation completed successfully.
-   Confirm the guest operating system is running.
-   Retry after rebooting the virtual machine if necessary.

**Expected Result**

Proxmox is configured to communicate with the Windows guest using the QEMU Guest Agent.

**Operator Notes**

The guest agent is installed inside Windows by the VirtIO guest tools package.

Enabling the option in Proxmox activates host-to-guest communication.

**Step 4.4 — Validate Guest Agent Communication**

**Purpose**

Confirm that Proxmox can successfully communicate with the Windows guest through the QEMU Guest Agent.

**Estimated Duration**

10 minutes

**Requirements**

-   QEMU Guest Agent enabled
-   Windows Server running normally

**Screenshot Placeholder**

**Screenshot 4.4-A — Guest Agent Status**

**Screenshot 4.4-B — Summary Page with Guest Information**

**GUI Procedure**

1.  Select **ROOTCA01**.
2.  Select options and verify QEMU Guest Agent = enabled
3.	Open the **Summary** page.
3.  verify that the status window displays the quest MAC Address and IP Address
4.  Wait several moments if information does not appear immediately.

**Validation**

Verify:

- QEMU Guest Agent is Enabled.
- The Status panel displays the guest MAC address.
- The Status panel displays the guest IP address.
- No Guest Agent communication errors are reported.

**Failure Action**

If communication fails:

-   Restart Windows.
-   Verify the VirtIO guest tools installation completed successfully.
-   Confirm the QEMU Guest Agent remains enabled within Proxmox.
-   Retry the validation.

**Expected Result**

Proxmox successfully communicates with the Windows guest through the QEMU Guest Agent.

**Operator Notes**

The Guest Agent may require a short period after Windows startup before reporting complete information.

This delay is expected.

**Step 4.5 — Verify Device Manager**

**Purpose**

Confirm that Windows recognizes all virtual hardware and that required drivers installed successfully.

**Estimated Duration**

10 minutes

**Requirements**

-   VirtIO guest tools installed
-   Windows restarted if required

**Screenshot Placeholder**

**Screenshot 4.5-A — Device Manager**

**GUI Procedure**

1.  Type device manager in the search bar next to the start menu
2.  Select Device Manager to openExpand each major hardware category.
3.  Verify there are no devices displaying warning icons.
4.  Confirm all expected virtual hardware appears operational.

**CLI Procedure**

Not applicable.

**Validation**

Verify:

-   No unknown devices exist.
-   No devices display warning symbols.
-   Storage, network, display, and system devices report normal operation.

**Failure Action**

If unknown devices remain:

-   Verify the VirtIO guest tools installation completed successfully.
-   Reinstall the guest tools if necessary.
-   Restart Windows and repeat this validation.

**Expected Result**

Windows recognizes all virtual hardware using the appropriate drivers.

**Operator Notes**

Unknown devices immediately following installation generally indicate that one or more VirtIO drivers were not installed successfully.

**Step 4.6 — Configure Windows Update**

**Purpose**

Verify Windows Update is operational and prepare the server to receive all available updates before the baseline image is created.

Project Polaris requires the operating system to be fully updated before VM110 is established as the reusable Windows Server baseline.

**Estimated Duration**

10 minutes

**Requirements**

-   Windows operating normally
-   Network connectivity available

**Screenshot Placeholder**

**Screenshot 4.6-A — Windows Update**

**GUI Procedure**

1.  Type system update in the search bar next to the start menu
2.  Select Check for Updates
3.  Windows Update will open.Verify the Windows Update service opens successfully.
4.  Select **Check for updates**.
5.  Allow Windows to begin searching for available updates.
6.  Windows update will begin automatically after selecting check for updates. If the do not start automatically proceed to step 4.7.

Do not wait for all updates to complete during this step.

The update process continues in the following procedures.

**Validation**

Verify:

-   Windows Update opens successfully.
-   Update scan begins.
-   No Windows Update service errors are reported.

**Failure Action**

If Windows Update cannot search for updates:

-   Verify network connectivity.
-   Confirm DNS resolution is functioning.
-   Restart the Windows Update service if necessary.
-   Retry the update scan.

**Expected Result**

Windows successfully begins scanning for available updates.

**Operator Notes**

Project Polaris intentionally completes all Windows Updates before establishing the VM110 baseline.

Doing so minimizes repeated update cycles for future deployments while ensuring newly deployed servers begin from a current operating system baseline.

**Step 4.7 — Install All Available Windows Updates**

**Purpose**

Install all available Windows Server updates before establishing the Project Polaris VM110 baseline.

Maintaining a fully updated baseline reduces deployment time for future servers while ensuring new systems begin from a secure operating system state.

**Estimated Duration**

30–120 minutes

*Actual duration depends on update availability and Internet connection speed.*

**Requirements**

-   Windows Update successfully completed an update scan
-   Internet connectivity available

**Screenshot Placeholder**

**Screenshot 4.7-A — Windows Update Downloading**

**Screenshot 4.7-B — Windows Update Installing**

**GUI Procedure**

1.  Open **Settings**.
2.  Navigate to:

**Update & Security → Windows Update**

1.  Review the list of available updates.
2.  Select **Download** or **Install**, if prompted.
3.  Allow Windows to download all available updates.
4.  Allow Windows to install each update.
5.  Restart the virtual machine whenever Windows requests a restart.
6.  After each restart, sign in using the local Administrator account.
7.  Return to **Windows Update**.
8.  Repeat **Check for updates**.
9.  Continue installing updates until Windows reports that no additional updates are available.

**Validation**

Verify:

-   All available updates install successfully.
-   Required restarts complete successfully.
-   Windows Update reports the system is fully up to date.

**Failure Action**

If updates fail:

-   Record the update error code.
-   Retry Windows Update.
-   Restart Windows if necessary.
-   Continue until all applicable updates have been installed.

**Expected Result**

Windows reports that the operating system is fully updated.

**Operator Notes**

Multiple update cycles and several reboots are normal.

Windows Update may discover additional updates after previous updates have been installed.

This behavior is expected.

**Step 4.8 — Verify Windows Activation Status**

**Purpose**

Confirm the installed operating system is functioning under the expected Windows Server 2019 Evaluation licensing model.

**Estimated Duration**

5 minutes

**Requirements**

-   Windows Update completed successfully

**Screenshot Placeholder**

**Screenshot 4.8-A — Activation Status**

**GUI Procedure**

1.  Open **Settings**.
2.  Navigate to:

**System → Activation**

1.  Review the activation information.
2.  Verify the operating system reports the expected Windows Server 2019 Evaluation licensing status.

**Validation**

Verify:

-   Windows reports the expected evaluation licensing information.
-   No unexpected activation errors appear.

**Failure Action**

If unexpected activation errors occur:

-   Verify the installed Windows edition.
-   Review Microsoft licensing documentation.
-   Correct licensing issues before continuing if required.

**Expected Result**

Windows reports the expected licensing status for the evaluation installation.

**Operator Notes**

Project Polaris uses Windows Server Evaluation media during laboratory construction.

Licensing migration procedures are documented separately.

**Step 4.9 — Perform Final Operating System Validation**

**Purpose**

Perform a comprehensive validation of the operating system before creating the reusable VM110 baseline.

**Estimated Duration**

15 minutes

**Requirements**

-   Windows fully updated
-   Guest Agent operational
-   VirtIO drivers installed

**Screenshot Placeholder**

**Screenshot 4.9-A — Server Manager**

**Screenshot 4.9-B — Device Manager**

**Screenshot 4.9-C — Windows Update**

**GUI Procedure**

Verify the following:

1.  Windows Server starts normally.
2.  Server Manager opens successfully.
3.  Device Manager reports no unknown devices.
4.  Windows Update reports no remaining updates.
5.  The desktop responds normally.
6.  Networking functions correctly.
7.  No unexpected warning dialogs are displayed.

**CLI Procedure**

Open **Command Prompt**.

Run:

systeminfo

Review the reported operating system information.

**Validation**

Verify:

-   Operating system version is correct.
-   Installed memory matches the virtual hardware.
-   Processor information is correct.
-   No unexpected hardware errors are reported.

**Failure Action**

If validation identifies problems:

-   Correct the reported issue.
-   Repeat this validation.
-   Do not continue until the operating system passes all validation checks.

**Expected Result**

Windows Server operates normally and is ready to become the reusable VM110 baseline.

**Operator Notes**

This validation represents the final engineering checkpoint before baseline creation.

##Part 4 Completion Milestone

Completion of Parts 1 through 4 confirms:

- The Proxmox environment has been validated.
- The ROOTCA01 virtual machine has been successfully created.
- Windows Server has been installed.
- VirtIO drivers have been installed.
- QEMU Guest Agent communication has been validated.
- Windows Update has completed successfully.
- The operating system has passed initial validation.

##############################################################################################################################################
# Milestone 3 - Application configuration level build
#
# Purpose – Steps 5–XX rebuild the ROOTCA01 application layer after the underlying operating system has been validated.
##############################################################################################################################################