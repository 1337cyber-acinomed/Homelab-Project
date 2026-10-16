<!-- Converted from Word document: Backing up DC.docx -->

Backing up DC-01 to NAS:

\$ShareRoot = '\\192.168.10.4\Backups'

\$BackupTarget = Join-Path \`

\$ShareRoot \`

'ActiveDirectory\DC01-SystemState'

\# Establish the SMB session securely.

\# The asterisk prompts locally for the password.

net.exe use \$ShareRoot /user:storage-admin \*

\$NetUseExitCode = \$LASTEXITCODE

if (\$NetUseExitCode -ne 0) {

throw "NAS authentication failed with exit code \$NetUseExitCode."

}

\$PathAccessible = Test-Path \`

-LiteralPath \$BackupTarget

if (-not \$PathAccessible) {

throw "Backup target is not accessible: \$BackupTarget"

}

\# Confirm write/delete access.

\$ProbeFile = Join-Path \$BackupTarget \`

"DC01-write-test-\$(\[guid\]::NewGuid()).tmp"

try {

\[System.IO.File\]::WriteAllText(

\$ProbeFile,

"DC01 backup validation \$(Get-Date -Format o)"

)

Remove-Item \$ProbeFile -Force

\$WriteAccess = \$true

}

catch {

\$WriteAccess = \$false

throw "NAS write test failed: \$(\$\_.Exception.Message)"

}

\[pscustomobject\]@{

BackupTarget = \$BackupTarget

NetUseExitCode = \$NetUseExitCode

PathAccessible = \$PathAccessible

WriteAccess = \$WriteAccess

} \| Format-List

\# Start the AD-aware system-state backup only after all gates pass.

& "\$env:SystemRoot\System32\wbadmin.exe" \`

start systemstatebackup \`

"-backupTarget:\$BackupTarget" \`

-quiet

\$BackupExitCode = \$LASTEXITCODE

\[pscustomobject\]@{

SystemStateBackupExitCode = \$BackupExitCode

BackupTarget = \$BackupTarget

} \| Format-List
