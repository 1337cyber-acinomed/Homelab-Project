# SOP-001: OPNsense Firmware Update and Validation

**Document ID:** SOP-001

**Title:** OPNsense Firmware Update and Validation Procedure

**Project:** Project Polaris

**System:** Cyber Range Firewall (OPNsense)

**Classification:** Internal

**Status:** Under Validation

**Version:** 1.0 (Validation Draft)

**Author:** Project Polaris

**Approved By:** _Pending_

**Last Updated:** _Pending Final Validation_

---

# Purpose

This Standard Operating Procedure (SOP) provides a repeatable, step-by-step process for performing firmware updates on the Project Polaris OPNsense firewall while minimizing operational risk and ensuring the firewall is returned to a fully validated production state.

The procedure incorporates enterprise change-management practices including prerequisite verification, recovery preparation, firmware installation, post-update validation, and rollback readiness.

---

# Scope

This SOP applies to the Project Polaris Cyber Range OPNsense firewall and any future replacement systems performing the same role.

This procedure shall be followed whenever:

- Updating OPNsense firmware.
- Installing operating system security updates.
- Applying major or minor OPNsense releases.
- Performing maintenance that requires a firewall reboot.
- Validating firewall operation following maintenance.

---

# Objectives

This procedure is designed to ensure:

- Firewall configuration is preserved before maintenance.
- Recovery points exist prior to any system modification.
- Network services remain functional after maintenance.
- Security boundaries remain enforced.
- Administrative access is maintained throughout the maintenance window.
- Cyber Range systems are returned to service only after the firewall has been fully validated.

---

# Prerequisites

The following conditions **must** be satisfied before beginning this procedure.

- A maintenance window has been approved.
- `admin01` is operational and accessible.
- Proxmox is operational.
- Backup storage is available.
- Internet connectivity is functional.
- OPNsense Web GUI is accessible from `admin01`.
- No active Cyber Range exercises are in progress.
- All Cyber Range virtual machines can be gracefully shut down.

**If any prerequisite is not satisfied, do not begin this procedure.**

---

# Estimated Duration

Approximately 30–60 minutes depending on firmware version, download size, and reboot time.

---

# Required Systems

- Proxmox VE
- OPNsense Firewall
- admin01 (Primary Administration Workstation)
- Internet Connectivity

---

# Recovery Resources

The following recovery resources will be created during this procedure:

- Proxmox Snapshot
- Proxmox VM Backup
- OPNsense Configuration Backup (config.xml)

These recovery resources must exist before any firmware update is initiated.

---

# Validation Methodology

This SOP is validated using a live production maintenance window.

Each operational step shall be executed in order.

A step is considered validated when:

- The expected result is achieved.
- No modification is required to enable later steps.

Once validated, a step is considered frozen and shall not be modified unless a later step reveals a procedural defect that prevents successful completion of this SOP.

Administrative edits (formatting, grammar, numbering, document organization, etc.) may be made after validation provided they do not alter the operational process.

# Step 1.1 — Verify Prerequisites

## Purpose

Verify that all required conditions are satisfied before beginning the maintenance procedure. This step ensures the maintenance window starts from a known, supported state and reduces the risk of interruption during the firmware update.

---

## Procedure

Verify that each of the following prerequisites is satisfied.

| Item | Verification |
|------|--------------|
| 1 | A maintenance window has been approved. |
| 2 | `admin01` is powered on and operational. |
| 3 | Proxmox VE is operational and accessible. |
| 4 | Backup storage is available and accessible. |
| 5 | Internet connectivity is functional. |
| 6 | The OPNsense Web GUI is accessible from `admin01`. |
| 7 | No active Cyber Range exercises are in progress. |
| 8 | All Cyber Range virtual machines can be gracefully shut down. |

Review each item before continuing.

---

## Expected Result

- All prerequisite items have been verified.
- No prerequisite conditions are outstanding.
- The maintenance window is approved to proceed.

---

## Failure Action

If any prerequisite cannot be verified:

1. Stop the maintenance procedure.
2. Resolve the missing prerequisite.
3. Restart this SOP beginning with **Step 1.1**.

Do **not** continue until all prerequisites have been satisfied.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes:**

____________________________________________________________

____________________________________________________________

____________________________________________________________

# Step 1.2 — Gracefully Shut Down All Cyber Range Virtual Machines

## Purpose

Gracefully shut down all Cyber Range virtual machines prior to firewall maintenance. This eliminates unnecessary network traffic during the firmware update, ensures clients establish fresh network sessions after maintenance, and reduces variables during post-update troubleshooting.

---

## Procedure

1. Log in to the Proxmox VE web interface.
2. Identify all virtual machines that are members of the Cyber Range.
3. For each Cyber Range virtual machine:
   - Select the virtual machine.
   - Click **Shutdown**.
   - Wait for the operating system to perform a graceful shutdown.
4. Verify each Cyber Range virtual machine displays a status of **Stopped**.
5. Confirm that only the systems required to perform maintenance remain powered on (for example, Proxmox, OPNsense, and `admin01`).

**Note:** `kali01` is considered a Cyber Range virtual machine and shall be gracefully shut down during scheduled firmware maintenance. It will be powered on later during the post-update validation process.

---

## Expected Result

- All Cyber Range virtual machines have been gracefully shut down.
- No Cyber Range virtual machines remain running.
- OPNsense remains operational.
- `admin01` remains operational.
- Proxmox VE remains operational.

---

## Failure Action

If any Cyber Range virtual machine fails to shut down gracefully:

1. Allow the guest operating system additional time to complete the shutdown.
2. If the virtual machine remains unresponsive, investigate the guest operating system before proceeding.
3. Do **not** forcefully stop a virtual machine unless required to preserve the maintenance window and the risk has been assessed.
4. Do **not** continue to the next step until all Cyber Range virtual machines are confirmed to be powered off.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes:**

____________________________________________________________

____________________________________________________________

____________________________________________________________

# Step 1.3 — Verify Firewall Health

## Purpose

Verify that the OPNsense firewall is operating normally before beginning maintenance. This establishes a known-good operational baseline and ensures existing issues are not mistaken for problems introduced by the firmware update.

---

## Procedure

1. From `admin01`, open a web browser.
2. Navigate to the OPNsense Web GUI.
3. Authenticate using an administrative account.
4. Verify the Dashboard loads successfully.
5. Navigate through the following pages to confirm normal GUI operation:
   - Dashboard
   - Interfaces → Overview
   - Firewall → Rules
   - System → Firmware
6. Verify each page loads without errors or excessive delay.
7. Review the Dashboard and verify the following:
   - CPU utilization is within normal operating levels.
   - Memory utilization is within normal operating levels.
   - Storage utilization is within normal operating levels.
8. Navigate to **Interfaces → Overview**.
9. Verify the following interfaces report a status of **Up**:
   - WAN
   - LAN
10. Navigate to **System → Diagnostics → Services** (or **Dashboard → Services**, depending on the installed dashboard widgets).
11. Verify all configured production services are running without errors.
12. Confirm there are no active system alerts, critical alarms, or hardware faults that would prevent maintenance.

---

## Expected Result

- OPNsense Dashboard loads successfully.
- Administrative login is successful.
- All major configuration pages load normally.
- WAN and LAN interfaces are operational.
- All expected production services are running.
- No critical system alerts are present.
- The firewall is operating normally and is ready for maintenance.

---

## Failure Action

If any expected service is not running, an interface is down, a configuration page fails to load, or a critical system alert is present:

1. Stop the maintenance procedure.
2. Investigate the connectivity or authentication issue.
3. Restore administrative access before continuing.
4. Repeat **Step 1.3** after corrective actions have been completed.
5. Do **not** continue until the firewall is confirmed to be in a healthy operational state.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes:**

____________________________________________________________

____________________________________________________________

____________________________________________________________

# Step 1.4 — Verify Internet Connectivity

## Purpose

Verify that the OPNsense firewall operating system has functional Internet connectivity and DNS resolution before beginning maintenance. Firmware updates require Internet access to download update packages. Confirming connectivity before maintenance prevents unnecessary troubleshooting during the update process.

---

## Procedure

1. Open the Proxmox VE web interface.
2. Select the OPNsense virtual machine.
3. Open the **Console**.
4. Log in using the `root` account or another account with administrative privileges.
5. Select option **8 — Shell** from the OPNsense console menu.
6. At the shell prompt, execute:

```sh
ping -c 4 8.8.8.8
```

7. Verify:
   - Four packets are transmitted.
   - Four packets are received.
   - Zero packet loss is reported.

8. Execute:

```sh
ping -c 4 google.com
```

9. Verify:
   - The hostname successfully resolves to an IP address.
   - Four packets are transmitted.
   - Four packets are received.
   - Zero packet loss is reported.

10. Type:

```sh
exit
```

11. Verify the OPNsense console menu is displayed again.

---

## Expected Result

- The firewall successfully reaches `8.8.8.8`.
- The firewall successfully resolves `google.com`.
- DNS resolution is functioning correctly.
- Internet connectivity is confirmed.
- The operator successfully returns to the OPNsense console menu.

---

## Failure Action

If either command fails:

1. Stop the maintenance procedure.
2. Verify the WAN interface is operational.
3. Verify the configured default gateway is online.
4. Verify DNS configuration.
5. Restore Internet connectivity before continuing.
6. Repeat **Step 1.4** after corrective actions have been completed.

Do **not** proceed until Internet connectivity and DNS resolution have been successfully verified.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes:**

____________________________________________________________

____________________________________________________________

____________________________________________________________

# Step 2.1 — Create Proxmox Snapshot

## Purpose

Create a point-in-time snapshot of the OPNsense virtual machine immediately before performing the firmware update. This snapshot provides a rapid rollback point in the event the update fails or introduces an unexpected issue.

---

## Procedure

1. Open the Proxmox VE web interface.
2. Select the OPNsense virtual machine.
3. Select the **Snapshots** tab.
4. Click **Take Snapshot**.
5. Configure the snapshot using the following values:
   - **Name:** `pre-update-<version>`
     - *Example:* `pre-update-26-7`
   - **Description:** `Pre-firmware update snapshot`
6. Verify **Include RAM** is **not selected**.
7. Click **Take Snapshot**.
8. Wait for the snapshot task to complete successfully.
9. Verify the snapshot appears in the snapshot list with a status indicating successful creation.

---

## Expected Result

- The snapshot completes without errors.
- The snapshot is visible in the Proxmox snapshot list.
- The OPNsense virtual machine remains operational after the snapshot completes.

---

## Failure Action

If the snapshot fails:

1. Stop the maintenance procedure.
2. Review the Proxmox task log to determine the cause of the failure.
3. Resolve the issue preventing snapshot creation.
4. Repeat **Step 2.1** after corrective actions have been completed.

Do **not** proceed until a valid recovery snapshot has been successfully created.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes:**

____________________________________________________________

____________________________________________________________

____________________________________________________________

# Step 2.2 — Backup OPNsense Configuration

## Purpose

Create a backup of the current OPNsense configuration before performing the firmware update. This backup provides an additional recovery method independent of the Proxmox virtual machine snapshot.

---

## Procedure

1. Log in to the OPNsense Web GUI.
2. Navigate to **System → Configuration → Backups**.
3. Select the **Backups** tab.
4. Click **Download Configuration**.
5. Save the configuration file using the following naming convention:

   - **Filename:** `config-<version>-pre-update.xml`
     - *Example:* `config-26-7-pre-update.xml`

6. Save the file to the designated Project Polaris backup location.
7. Verify the configuration file exists and has a non-zero file size.

---

## Expected Result

- The configuration backup downloads successfully.
- The backup file is saved using the approved naming convention.
- The backup file is accessible from the designated backup location.

---

## Failure Action

If the configuration backup cannot be created:

1. Stop the maintenance procedure.
2. Verify administrative access to the OPNsense Web GUI.
3. Resolve the issue preventing configuration export.
4. Repeat **Step 2.2** after corrective actions have been completed.

Do **not** proceed until a valid configuration backup has been successfully created.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes:**

____________________________________________________________

____________________________________________________________

____________________________________________________________


# Step 2.3 — Create Proxmox Virtual Machine Backup

## Purpose

Create a full backup of the OPNsense virtual machine before performing the firmware update. This backup provides a complete recovery point independent of the Proxmox snapshot and exported OPNsense configuration.

---

## Precaution

- If **NAS01 is available**, complete Steps **1–8**.
- If **NAS01 is not available**, complete Steps **9–16**.
- Complete only the applicable backup path.
- Do not proceed with the firmware update until a valid virtual machine backup has been created.

---

## Procedure

### NAS01 Available

1. Open the Proxmox VE web interface.
2. Select the OPNsense virtual machine.
3. Select **Backup**.
4. Configure the backup using the following settings:
   - **Storage:** `NAS-Backups`
   - **Mode:** `Snapshot`
   - **Compression:** `ZSTD`
   - **Protected:** Enabled
5. Click **Backup**.
6. Wait for the backup task to complete successfully.
7. Review the Proxmox task log and verify the backup completed without errors.
8. Verify the backup appears in the **NAS01 Backups** folder.

### NAS01 Unavailable

9. Open the Proxmox VE web interface.
10. Select the OPNsense virtual machine.
11. Select **Backup**.
12. Configure the backup using the following settings:
    - **Storage:** `local`
    - **Mode:** `Snapshot`
    - **Compression:** `ZSTD`
    - **Protected:** Enabled
13. Click **Backup**.
14. Wait for the backup task to complete successfully.
15. Review the Proxmox task log and verify the backup completed without errors.
16. Verify the backup appears in the virtual machine backup list.

---

## Expected Result

- The virtual machine backup completes without errors.
- The backup is visible in either:
  - The **NAS01 Backups** folder, or
  - The Proxmox virtual machine backup list on `local` storage.
- The backup is protected from unintended deletion.
- The OPNsense virtual machine remains operational after the backup completes.

---

## Failure Action

If the backup fails:

1. Stop the maintenance procedure.
2. Review the Proxmox task log to determine the cause of the failure.
3. Verify sufficient storage capacity is available at the selected destination.
4. Resolve the issue preventing backup completion.
5. Repeat **Step 2.3** using the appropriate backup path.

Do **not** proceed until a valid virtual machine backup has been successfully created.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes:**

____________________________________________________________

____________________________________________________________

____________________________________________________________

# Step 3.1 — Check for Available Firmware Updates

## Purpose

Determine whether a firmware update is available and identify the target firmware version before beginning the update process.

---

## Procedure

1. Log in to the OPNsense Web GUI.
2. Navigate to **System → Firmware → Status**.
3. Verify the **Firmware Status** page loads successfully.
4. Click **Check for Updates**.
5. Wait for the update check to complete.
6. Review the update results and verify:
   - The currently installed firmware version is displayed.
   - The target firmware version is displayed.
   - The update status indicates the firmware is available for installation.
7. Record the following information in the maintenance record:
   - Current firmware version
   - Target firmware version
   - Date and time of the maintenance activity

---

## Expected Result

- The firmware status page loads successfully.
- The update check completes without errors.
- The current firmware version is identified.
- The target firmware version is identified.
- The firmware update is available for installation.
- The maintenance record has been updated.

---

## Failure Action

If the update check fails:

1. Stop the maintenance procedure.
2. Verify Internet connectivity by repeating **Step 1.4**.
3. Verify the OPNsense firewall is functioning normally.
4. Resolve the issue preventing the update check.
5. Repeat **Step 3.1** after corrective actions have been completed.

Do **not** proceed until the firmware update check completes successfully.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes:**

____________________________________________________________

____________________________________________________________

____________________________________________________________

# Step 3.2 — Install Firmware Update

## Purpose

Install the available OPNsense firmware update while monitoring the update process for successful completion.

---

## Procedure

1. Verify **Step 3.1** has been successfully completed.
2. From **System → Firmware → Status**, verify the target firmware version is displayed.
3. Click **Update**.
4. Review the list of packages that will be upgraded.
5. Verify the package list appears reasonable for the expected firmware version.
6. Confirm the firmware update.
7. Monitor the update process until all firmware packages have been downloaded and installed.
8. Verify the update process completes without reporting any errors.
9. Verify the update process reports successful completion (for example, `***DONE***` or an equivalent success message).
10. If prompted, reboot the firewall and wait for the system to return to service.
11. Verify the OPNsense login page becomes accessible.

---

## Expected Result

- The firmware update completes successfully.
- No installation errors are reported.
- If required, the firewall reboots successfully.
- The OPNsense login page is accessible after the update.

---

## Failure Action

If the firmware update fails or the firewall does not return to service:

1. Stop the maintenance procedure.
2. Record any error messages displayed during the update.
3. Attempt to regain administrative access to the firewall.
4. If necessary, recover the firewall using one of the recovery methods prepared during **Phase 2**.
5. Resume this SOP only after the firewall has been restored to a known operational state.

Do **not** continue until the firewall has been successfully recovered.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes:**

____________________________________________________________

____________________________________________________________

____________________________________________________________

# Step 4.1 — Verify Installed Firmware Version

## Purpose

Verify the firmware update completed successfully by confirming the installed firmware version and update information.

---

## Procedure

1. Log in to the OPNsense Web GUI.
2. Navigate to **System → Firmware → Status**.
3. Verify the **Firmware Status** page loads successfully.
4. Confirm the following information is displayed:
   - **Type**
   - **Version**
   - **Architecture**
   - **Commit**
   - **Repositories**
   - **Updated on**
5. Verify the **Version** matches the target firmware version identified during **Step 3.1**.
6. Verify the **Updated on** date and time correspond to the maintenance activity.
7. Record the installed firmware version and update completion time in the maintenance record.

---

## Expected Result

- The firmware status page loads successfully.
- The installed firmware version matches the expected target version.
- The update timestamp reflects the completed maintenance activity.
- Firmware information is displayed without errors.
- The maintenance record has been updated.

---

## Failure Action

If the installed firmware version does not match the expected version or the firmware information cannot be verified:

1. Stop the maintenance procedure.
2. Verify the firmware update completed successfully.
3. Review the firmware update logs for errors.
4. Resolve any issues preventing successful installation.
5. Repeat **Step 4.1** after corrective actions have been completed.

Do **not** continue until the installed firmware version has been successfully verified.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes:**

____________________________________________________________

____________________________________________________________

____________________________________________________________

# Step 4.2 — Perform OPNsense System Audit

## Purpose

Verify the operational health of the OPNsense firewall following the firmware update by performing the built-in OPNsense system audits.

---

## Procedure

1. Log in to the OPNsense Web GUI.
2. Navigate to **System → Firmware → Status**.
3. Select **Run an Audit**.
4. Run each of the following audits individually:
   - **Cleanup**
   - **Connectivity**
   - **Health**
   - **Security**
5. Wait for each audit to complete before starting the next audit.
6. Complete all four audits regardless of the results of any previous audit.
7. Review the results of each audit.
8. Record any warnings, security findings, informational messages, or corrective actions identified during the audits in the maintenance record.
9. Determine whether any reported findings require immediate corrective action before continuing the maintenance procedure.

---

## Expected Result

- All four audits complete successfully.
- No critical errors are reported.
- Any warnings or informational messages have been documented.
- Any reported security findings have been documented.
- The operator has determined whether any warnings or security findings require immediate corrective action before continuing.
- The firewall is determined to be operating normally following the firmware update.

---

## Failure Action

### Critical Errors

If any audit reports a critical error:

1. Stop the maintenance procedure.
2. Record the audit results and associated error messages.
3. Investigate and resolve the reported issue.
4. Repeat the affected audit after corrective actions have been completed.
5. Repeat **Step 4.2** until all critical errors have been resolved.

### Warnings or Security Findings

If any audit reports warnings or security findings:

1. Record the reported findings in the maintenance record.
2. Investigate the reported condition.
3. Determine whether continued operation presents an acceptable operational risk.
4. If the finding represents an unacceptable operational risk, stop the maintenance procedure and initiate the appropriate recovery procedures established in **Phase 2**.
5. If the finding does not present an unacceptable operational risk:
   - Document the justification for continuing operation.
   - Schedule any required follow-up remediation.
   - Continue with the maintenance procedure.

Do **not** continue until:
- All critical errors have been resolved, and
- Any remaining warnings or security findings have been evaluated and determined to present an acceptable operational risk.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes:**

____________________________________________________________

____________________________________________________________

____________________________________________________________

# Step 4.3 — Verify Firewall Operational Health

## Purpose

Verify the OPNsense firewall is operating normally following the firmware update by confirming the status of system resources, network interfaces, and critical services.

---

## Procedure

1. Log in to the OPNsense Web GUI.
2. Navigate to **Dashboard**.
3. Verify the Dashboard loads successfully.
4. Review the Dashboard and verify:
   - CPU utilization is within normal operating levels.
   - Memory utilization is within normal operating levels.
   - Storage utilization is within normal operating levels.
5. Verify the following interfaces are present and operational:
   - WAN
   - LAN
6. Verify each interface reports the expected link status and assigned IP address.
7. Review the Services widget (or navigate to **System → Diagnostics → Services**, if required).
8. Verify all configured critical services are running.
9. Verify no new system alerts, fault indicators, or critical notifications have been generated since completing the firmware update.
10. Record any abnormalities or corrective actions in the maintenance record.

---

## Expected Result

- The Dashboard loads successfully.
- CPU, memory, and storage utilization are within expected operating ranges.
- WAN and LAN interfaces are operational.
- Configured critical services are running.
- No unexpected alerts or fault conditions are present.
- The firewall is operating normally following the firmware update.

---

## Failure Action

If any abnormal condition is identified:

1. Stop the maintenance procedure.
2. Record the observed condition in the maintenance record.
3. Investigate the affected resource, interface, or service.
4. Restore normal operation before continuing.
5. Repeat **Step 4.3** after corrective actions have been completed.

Do **not** continue until the firewall has been verified to be operating normally.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes:**

____________________________________________________________

____________________________________________________________

____________________________________________________________

# Step 4.4 — Validate Cyber Range Connectivity and Security Boundaries

## Purpose

Verify that OPNsense is providing Internet connectivity to the Cyber Range while enforcing the approved Project Polaris security boundaries before restoring the remaining Cyber Range virtual machines.

---

## Precaution

- Start only **kali01** during this step.
- Leave all remaining Cyber Range virtual machines powered off.
- Do not restore additional Cyber Range systems until this step has successfully completed.

---

## Procedure

### 1. Start kali01

Open the Proxmox VE Web Interface.

Navigate to:

**Datacenter → Proxmox Host → kali01**

Select **Start**.

Wait for kali01 to complete the boot process.

**Expected Result**

- kali01 starts successfully.
- The login prompt is displayed.

---

### 2. Verify Network Configuration

Log in to kali01.

Run:

```bash
ip addr show
```

**Expected Result**

- The primary network interface is **eth0**.
- The interface state is **UP**.
- The IPv4 address is **10.10.1.85/24**.
- The broadcast address is **10.10.1.255**.

---

### 3. Verify Default Gateway

Run:

```bash
ip route
```

**Expected Result**

- A default route is present.
- The default gateway is **10.10.1.1**.
- The default route uses **eth0**.

---

### 4. Verify DNS Configuration

Run:

```bash
cat /etc/resolv.conf
```

**Expected Result**

The configured nameserver is:

```text
nameserver 10.10.1.1
```

- No unexpected DNS servers are configured.

---

### 5. Verify Internet Connectivity

Run:

```bash
ping -c 4 8.8.8.8
```

**Expected Result**

- 4 packets transmitted.
- 4 packets received.
- 0% packet loss.

---

### 6. Verify DNS Resolution

Run:

```bash
ping -c 4 google.com
```

**Expected Result**

- The hostname resolves successfully.
- 4 packets transmitted.
- 4 packets received.
- 0% packet loss.

---

### 7. Verify Cyber Range Security Boundaries

Verify that kali01 cannot communicate with protected Trusted Infrastructure systems.

#### Test 1 — firewall01 (192.168.10.1)

Run:

```bash
ping -c 4 192.168.10.1
```

**Expected Result**

- 4 packets transmitted.
- 0 packets received.
- 100% packet loss.

---

#### Test 2 — admin01 (192.168.10.41)

Run:

```bash
ping -c 4 192.168.10.41
```

**Expected Result**

- 4 packets transmitted.
- 0 packets received.
- 100% packet loss.

---

#### Test 3 — DC01 (192.168.10.40)

Run:

```bash
ping -c 4 192.168.10.40
```

**Expected Result**

- 4 packets transmitted.
- 0 packets received.
- 100% packet loss.

These tests confirm that OPNsense is enforcing the approved security boundary between the Cyber Range and the Trusted Infrastructure network.

---

### 8. Verify OPNsense Management Access

Open Firefox on kali01.

Browse to:

```text
https://192.168.10.120
```

Log in using an authorized administrative account.

Verify the Dashboard loads successfully.

**Expected Result**

- The OPNsense login page loads.
- Authentication succeeds.
- The Dashboard loads successfully.
- No unexpected errors are displayed.
- CPU, memory, interfaces, and services display normal operational status.

---

### 9. Review Firewall Logs

Within the OPNsense Web GUI navigate to:

**Firewall → Log Files → Live View**

Apply the following filter:

- Source IP: **10.10.1.85**

Review the log entries generated during Steps 5 through 8.

**Expected Result**

- Internet traffic is logged as **Pass**.
- Blocked traffic to **firewall01 (192.168.10.1)** is logged as **Block**.
- Blocked traffic to **admin01 (192.168.10.41)** is logged as **Block**.
- Blocked traffic to **DC01 (192.168.10.40)** is logged as **Block**.
- Logged firewall rules match the approved Project Polaris firewall policy.

---

### 10. Record Results

Document:

- Network configuration verification.
- Default gateway verification.
- DNS verification.
- Internet connectivity results.
- Cyber Range security boundary validation.
- OPNsense management access verification.
- Firewall log verification.
- Any abnormalities or corrective actions performed.

---

## Expected Result

- kali01 boots successfully.
- kali01 receives the expected Project Polaris network configuration.
- Internet connectivity through OPNsense is operational.
- DNS resolution functions correctly.
- Trusted Infrastructure systems remain inaccessible from the Cyber Range.
- HTTPS management access to OPNsense functions correctly.
- Firewall logs confirm the approved permit and deny actions.
- The Cyber Range security boundary has been fully validated before additional Cyber Range virtual machines are restored.

---

## Failure Action

### Internet Connectivity Failure

If Internet connectivity fails:

1. Stop the maintenance procedure.
2. Verify the kali01 network configuration.
3. Verify the OPNsense LAN interface configuration.
4. Verify the default gateway.
5. Verify outbound NAT.
6. Verify DNS configuration.
7. Verify the applicable firewall rules.
8. Correct the identified issue.
9. Repeat **Step 4.4**.

---

### Security Boundary Failure

If any security boundary validation fails:

1. Stop the maintenance procedure.
2. Leave all remaining Cyber Range virtual machines powered off.
3. Record the unexpected behavior.
4. Review the applicable firewall rules.
5. Review the firewall logs.
6. Correct the security policy.
7. Repeat **Step 4.4** until all boundary tests pass.

Do **not** continue until Internet connectivity has been restored and all security boundary validations have passed.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes**

____________________________________________________________

____________________________________________________________

____________________________________________________________

# Step 4.5 — Validate Cyber Range Fail-Safe Operation

## Purpose

Validate that the Cyber Range fails securely when OPNsense is unavailable by confirming that Internet connectivity, Trusted Infrastructure connectivity, and firewall management access are unavailable until OPNsense is restored.

---

## Precaution

- Perform this step only after **Step 4.4** has completed successfully.
- Only **kali01** and **OPNsense** should be running.
- All remaining Cyber Range virtual machines shall remain powered off.
- This validation intentionally interrupts Cyber Range connectivity.

---

## Procedure

### 1. Verify Current Operating State

Confirm:

- OPNsense is running.
- kali01 is running.
- All other Cyber Range virtual machines are powered off.

**Expected Result**

- Only OPNsense and kali01 are operational within the Cyber Range.

---

### 2. Gracefully Shut Down OPNsense

Open the OPNsense Web GUI.

Navigate to:

**System → Power → Halt**

Confirm the shutdown.

Wait until the OPNsense virtual machine reports **Stopped** within the Proxmox VE Web Interface.

**Expected Result**

- OPNsense shuts down cleanly.
- The virtual machine status changes to **Stopped**.

---

### 3. Verify Internet Connectivity Is Lost

On **kali01**, open a terminal.

Verify IPv4 Internet connectivity:

```bash
ping -c 4 8.8.8.8
```

Verify DNS-based connectivity:

```bash
ping -c 4 google.com
```

**Expected Result**

- Both commands fail.
- No replies are received.
- Internet connectivity is unavailable.

---

### 4. Verify Trusted Infrastructure Is Unreachable

On **kali01**, verify connectivity to:

- firewall01 (192.168.10.1)
- admin01 (192.168.10.41)
- DC01 (192.168.10.40)

```bash
ping -c 4 192.168.10.1
ping -c 4 192.168.10.41
ping -c 4 192.168.10.40
```

**Expected Result**

- All tests fail.
- No replies are received.

---

### 5. Verify Firewall Management Is Unavailable

Open Firefox on **kali01**.

Browse to:

```
https://192.168.10.120
```

**Expected Result**

- Connection fails.
- OPNsense Web GUI is unavailable.

---

### 6. Start OPNsense

Within the Proxmox VE Web Interface:

Select the OPNsense virtual machine.

Select:

**Start**

Wait until the virtual machine reports **Running**.

Allow sufficient time for OPNsense services to initialize completely.

**Expected Result**

- OPNsense boots successfully.
- The virtual machine reports **Running**.

---

### 7. Verify Connectivity Has Been Restored

Repeat the following tests from **kali01**.

Verify Internet connectivity:

```bash
ping -c 4 8.8.8.8
ping -c 4 google.com
```

Verify OPNsense management:

Browse to:

```
https://192.168.10.120
```

Verify successful login to the OPNsense dashboard.

**Expected Result**

- Internet connectivity is restored.
- DNS resolution functions normally.
- OPNsense Web GUI is available.
- Successful login to the dashboard.

---

### 8. Record Results

Document:

- OPNsense shutdown completed successfully.
- Fail-safe behavior verified.
- Connectivity restored successfully after startup.
- Any unexpected observations.

---

## Expected Result

- Cyber Range loses all external connectivity while OPNsense is offline.
- Trusted Infrastructure remains inaccessible.
- OPNsense management interface is unavailable while offline.
- Connectivity is restored only after OPNsense has fully returned to service.

---

## Failure Action

If any connectivity remains available while OPNsense is shut down:

1. Stop the maintenance procedure.
2. Do not restore additional Cyber Range virtual machines.
3. Investigate routing, virtual networking, firewall rules, and Proxmox bridge configuration.
4. Correct the identified issue.
5. Repeat this step until all validations pass.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes**

____________________________________________________________

____________________________________________________________

____________________________________________________________


# Step 4.6 — Restore Cyber Range Virtual Machines

## Purpose

Restore the Cyber Range virtual machines to their normal operational state following successful validation of the OPNsense firewall and Cyber Range security boundaries.

---

## Precaution

- Do not begin this step until **Step 4.4** has successfully completed.
- Restore only the Cyber Range virtual machines required for normal Cyber Range operation.
- Monitor each virtual machine during startup before starting the next virtual machine.

---

## Procedure

### 1. Open the Proxmox VE Web Interface

Navigate to:

**Datacenter → Proxmox Host**

---

### 2. Start the Cyber Range Virtual Machines

Start each Cyber Range virtual machine according to the approved Cyber Range Startup SOP.

Reference:
<Project Polaris Documentation Path>/<Cyber Range Startup SOP Filename>

Wait for each virtual machine to complete its boot process before starting the next virtual machine.

**Expected Result**

- The virtual machine starts successfully.
- No boot errors are reported.
- The virtual machine reaches its login screen or normal operating state.

---

### 3. Verify Virtual Machine Status

Navigate to:

**Datacenter → Proxmox Host**

Verify each Cyber Range virtual machine displays:

- Running
- Green status indicator
- No active Proxmox task errors

**Expected Result**

- All required Cyber Range virtual machines are running.
- No startup failures are reported.
- No Proxmox task failures are present.

---

### 4. Verify OPNsense DHCP Leases (if applicable)

Within the OPNsense Web GUI navigate to:

**Services → ISC DHCPv4 → Leases**

or

**Services → Kea DHCP → Leases**

(depending on the configured DHCP service)

Verify newly started Cyber Range virtual machines have obtained DHCP leases if configured for DHCP.

**Expected Result**

- DHCP-enabled systems receive an IP lease.
- Lease information matches the expected subnet.

If static IP addressing is used for a virtual machine, document that DHCP verification is not applicable.

---

### 5. Record Results

Document:

- Virtual machines restored.
- Startup order completed successfully.
- Any startup errors.
- Any corrective actions performed.

---

## Expected Result

- All required Cyber Range virtual machines have been restored.
- Each virtual machine boots successfully.
- No Proxmox task failures are present.
- DHCP-enabled systems obtain network leases if applicable.
- The Cyber Range is ready for operational validation.

---

## Failure Action

If any virtual machine fails to start:

1. Stop the restoration process.
2. Record the affected virtual machine.
3. Review the Proxmox task log.
4. Review the virtual machine console.
5. Correct the identified issue.
6. Repeat **Step 4.5** for the affected virtual machine.

Do **not** continue until all required Cyber Range virtual machines have been successfully restored.

---

## Validation Status

☐ Pass

☐ Fail

**Operator Notes**

____________________________________________________________

____________________________________________________________

____________________________________________________________
