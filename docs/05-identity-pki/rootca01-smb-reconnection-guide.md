# Project Polaris — ROOTCA01 SMB Recovery Share Reconnection Guide

## Purpose

This guide documents how to verify the dedicated ROOTCA01 SMB transfer account, reconnect Admin-WS to the `Recovery$` share, validate access, and perform the next expected recovery actions if the persistent connection does not automatically return after an Admin-WS logoff/reboot or ROOTCA01 restart.

This is intentionally separate from the active RB-010 / CA01 implementation work so SMB persistence can be tested later without interrupting the Active Directory milestone.

## 1. Verify the ROOTCA01 transfer account and share

Run on **ROOTCA01** from elevated Windows PowerShell.

```powershell
Get-SmbShare -Name 'Recovery$' |
    Select-Object Name, Path, Description, EncryptData, FolderEnumerationMode
```

Expected share root:

```text
Recovery$ -> C:\Recovery
```

Verify share permissions:

```powershell
Get-SmbShareAccess -Name 'Recovery$' |
    Select-Object Name, AccountName, AccessControlType, AccessRight
```

Expected dedicated transfer identity:

```text
ROOTCA01\recoverytransfer    Allow    Change
```

Verify the local transfer account:

```powershell
Get-LocalUser -Name 'recoverytransfer' |
    Select-Object Name, Enabled, PasswordRequired, PasswordExpires
```

Expected:

```text
Enabled          : True
PasswordRequired : False
PasswordExpires  : False
```

Verify NTFS permissions:

```powershell
(Get-Acl 'C:\Recovery').Access |
    Select-Object IdentityReference, FileSystemRights, AccessControlType, IsInherited
```

## 2. Reconnect Admin-WS to ROOTCA01

Run on **Admin-WS** from elevated Windows PowerShell.

Remove any stale connection:

```powershell
net use \\192.168.10.45\Recovery$ /delete
```

If Windows reports that the connection could not be found, continue.

Reconnect with the dedicated transfer identity:

```powershell
net use \\192.168.10.45\Recovery$ "" /user:ROOTCA01\recoverytransfer /persistent:yes
```

Expected:

```text
The command completed successfully.
```

Verify Windows remembers the connection:

```powershell
net use
```

Verify access:

```powershell
Get-ChildItem '\\192.168.10.45\Recovery$' |
    Select-Object Name, Length, LastWriteTime
```

Verify the outbound staging directory:

```powershell
Get-ChildItem '\\192.168.10.45\Recovery$\Outgoing' |
    Select-Object Name, Length, LastWriteTime
```

For the current PKI publication package, expect:

```text
checksums.sha256
Polaris Root CA.crl
Polaris Root CA.crt
```

## 3. Additional verification

```powershell
Test-NetConnection 192.168.10.45 -Port 445
```

Expected:

```text
TcpTestSucceeded : True
```

Inspect active SMB sessions:

```powershell
Get-SmbConnection |
    Select-Object ServerName, ShareName, UserName, Credential, Dialect
```

Verify the share directly from ROOTCA01:

```powershell
Get-SmbShare -Name 'Recovery$' |
    Select-Object Name, Path, Description
```

## 4. If persistence does not work after reboot or logoff

Do not change firewall01, DC01 DNS, or the Project Polaris architecture. Troubleshoot only the Admin-WS ↔ ROOTCA01 SMB relationship.

First check:

```powershell
net use
Get-ChildItem '\\192.168.10.45\Recovery$'
```

If needed, re-establish the persistent connection:

```powershell
net use \\192.168.10.45\Recovery$ /delete
net use \\192.168.10.45\Recovery$ "" /user:ROOTCA01\recoverytransfer /persistent:yes
```

Then verify:

```powershell
Get-ChildItem '\\192.168.10.45\Recovery$\Outgoing'
```

If Windows still does not reconnect automatically at logon, create a reconnect script.

Create the script file:

```powershell
New-Item -ItemType Directory -Path 'C:\ProgramData\ProjectPolaris\RecoveryTransport\Scripts' -Force
New-Item -ItemType File -Path 'C:\ProgramData\ProjectPolaris\RecoveryTransport\Scripts\Connect-ROOTCA01RecoveryShare.ps1' -Force
notepad.exe 'C:\ProgramData\ProjectPolaris\RecoveryTransport\Scripts\Connect-ROOTCA01RecoveryShare.ps1'
```

Script content:

```powershell
$Share = '\\192.168.10.45\Recovery$'

if (-not (Test-Path -LiteralPath $Share)) {
    & net.exe use $Share '""' /user:ROOTCA01\recoverytransfer /persistent:yes
}

if (-not (Test-Path -LiteralPath $Share)) {
    throw 'ROOTCA01 Recovery$ share could not be reconnected.'
}
```

If normal `/persistent:yes` still fails after a later reboot/logoff test, create a logon task:

```powershell
$Action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\ProjectPolaris\RecoveryTransport\Scripts\Connect-ROOTCA01RecoveryShare.ps1"'

$Trigger = New-ScheduledTaskTrigger -AtLogOn

Register-ScheduledTask `
    -TaskName 'ProjectPolaris-Connect-ROOTCA01-RecoveryShare' `
    -Action $Action `
    -Trigger $Trigger `
    -RunLevel Highest `
    -Force
```

Verify:

```powershell
Get-ScheduledTask -TaskName 'ProjectPolaris-Connect-ROOTCA01-RecoveryShare'
```

This scheduled task is a fallback only. Test normal `/persistent:yes` behavior first during a later maintenance window.

## 5. Current design

```text
ROOTCA01
└── Recovery$ -> C:\Recovery
    ├── Incoming
    ├── Outgoing
    ├── Archive
    └── Logs

Dedicated transfer identity:
ROOTCA01\recoverytransfer

Admin-WS connection:
\\192.168.10.45\Recovery$
```

The SMB connection is an operational transfer path only. It does not alter the Project Polaris DNS/environment separation or integrate ROOTCA01 with firewall01.


establishing ADMIN-WS with CA01 SmbShare
net use \\192.168.10.44\C$ /user:AD\Administrator *