<#
.SYNOPSIS
    Renames and moves manually exported Project Polaris configuration backups
    from the local Downloads folder to the correct NAS01 backup directory.

.DESCRIPTION
    Run the script after downloading a configuration export. Select the system,
    and the script will locate the newest matching file in Downloads, rename it
    using the Project Polaris naming convention, and move it to NAS01.

    Standard format:
        SystemName-YYYY-MM-DD.extension

    If a file with the same name already exists:
        SystemName-YYYY-MM-DD-HHmmss.extension

.PARAMETER SourceFile
    Optional full path to a specific downloaded configuration file.

.NOTES
    Default NAS path:
        \\192.168.10.4\Backups\Configurations
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$SourceFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$NasRoot = '\\192.168.10.4\Backups\Configurations'
$DownloadsFolder = Join-Path $env:USERPROFILE 'Downloads'

$Systems = [ordered]@{
    '1' = @{ Name='Gateway01';         Folder='Gateway';     Extensions=@('.xml'); SearchTerms=@('config','pfsense','gateway') }
    '2' = @{ Name='Firewall01';        Folder='PfSense';     Extensions=@('.xml'); SearchTerms=@('config','pfsense','firewall') }
    '3' = @{ Name='Cyber-FW01';        Folder='OPNsense';    Extensions=@('.xml','.json','.backup'); SearchTerms=@('config','opnsense','cyber') }
    '4' = @{ Name='Proxmox-Homelab';   Folder='Proxmox';     Extensions=@('.tar','.gz','.tgz','.zst','.zip'); SearchTerms=@('proxmox','pve','config') }
    '5' = @{ Name='Proxmox-CyberRange';Folder='Proxmox';     Extensions=@('.tar','.gz','.tgz','.zst','.zip'); SearchTerms=@('proxmox','pve','config') }
    '6' = @{ Name='NAS01';             Folder='NAS';         Extensions=@('.bak','.backup','.bin','.cfg','.tar','.gz','.zip'); SearchTerms=@('nas','adm','backup','config') }
    '7' = @{ Name='Switch01';          Folder='Switch';      Extensions=@('.bin','.cfg','.conf','.txt'); SearchTerms=@('switch','config','backup') }
    '8' = @{ Name='NanoStation-AP';    Folder='NanoStation'; Extensions=@('.cfg','.conf','.tar','.bin'); SearchTerms=@('nanostation','backup','config') }
    '9' = @{ Name='NanoStation-STA';   Folder='NanoStation'; Extensions=@('.cfg','.conf','.tar','.bin'); SearchTerms=@('nanostation','backup','config') }
}

function Show-SystemMenu {
    Write-Host ''
    Write-Host 'Project Polaris Configuration Backup Organizer' -ForegroundColor Cyan
    Write-Host '------------------------------------------------'
    foreach ($key in $Systems.Keys) {
        Write-Host ("[{0}] {1}" -f $key, $Systems[$key].Name)
    }
    Write-Host '[Q] Quit'
    Write-Host ''
}

function Get-SystemSelection {
    do {
        Show-SystemMenu
        $selection = Read-Host 'Select the configuration source'
        if ($selection -match '^[Qq]$') { exit 0 }
    } until ($Systems.Contains($selection))
    return $Systems[$selection]
}

function Get-NewestCandidate {
    param([Parameter(Mandatory)][hashtable]$System)

    if (-not (Test-Path -LiteralPath $DownloadsFolder -PathType Container)) {
        throw "Downloads folder was not found: $DownloadsFolder"
    }

    $files = Get-ChildItem -LiteralPath $DownloadsFolder -File |
        Where-Object {
            $extensionMatch = $System.Extensions -contains $_.Extension.ToLowerInvariant()
            $nameLower = $_.Name.ToLowerInvariant()
            $termMatch = $false
            foreach ($term in $System.SearchTerms) {
                if ($nameLower -like "*$($term.ToLowerInvariant())*") { $termMatch = $true; break }
            }
            $extensionMatch -and $termMatch
        } |
        Sort-Object LastWriteTime -Descending

    if (-not $files) {
        $files = Get-ChildItem -LiteralPath $DownloadsFolder -File |
            Where-Object { $System.Extensions -contains $_.Extension.ToLowerInvariant() } |
            Sort-Object LastWriteTime -Descending
    }

    if (-not $files) {
        throw "No matching configuration file was found in $DownloadsFolder."
    }

    $candidate = $files[0]
    Write-Host ''
    Write-Host 'Newest matching file:' -ForegroundColor Yellow
    Write-Host "  $($candidate.FullName)"
    Write-Host "  Modified: $($candidate.LastWriteTime)"
    Write-Host "  Size: $([math]::Round($candidate.Length / 1KB, 2)) KB"
    Write-Host ''

    $confirmation = Read-Host 'Use this file? (Y/N)'
    if ($confirmation -notmatch '^[Yy]$') {
        $manualPath = Read-Host 'Enter the full path to the correct file'
        if (-not (Test-Path -LiteralPath $manualPath -PathType Leaf)) {
            throw "The specified file does not exist: $manualPath"
        }
        return Get-Item -LiteralPath $manualPath
    }

    return $candidate
}

function Get-DestinationPath {
    param(
        [Parameter(Mandatory)][hashtable]$System,
        [Parameter(Mandatory)][System.IO.FileInfo]$File
    )

    $destinationFolder = Join-Path $NasRoot $System.Folder
    if (-not (Test-Path -LiteralPath $destinationFolder -PathType Container)) {
        Write-Host "Creating destination folder: $destinationFolder"
        New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
    }

    $dateStamp = Get-Date -Format 'yyyy-MM-dd'
    $extension = $File.Extension.ToLowerInvariant()
    $baseName = '{0}-{1}' -f $System.Name, $dateStamp
    $destinationPath = Join-Path $destinationFolder ($baseName + $extension)

    if (Test-Path -LiteralPath $destinationPath) {
        $timeStamp = Get-Date -Format 'HHmmss'
        $destinationPath = Join-Path $destinationFolder ('{0}-{1}-{2}{3}' -f $System.Name, $dateStamp, $timeStamp, $extension)
    }

    return $destinationPath
}

try {
    $selectedSystem = Get-SystemSelection
    $file = if ($SourceFile) { Get-Item -LiteralPath $SourceFile } else { Get-NewestCandidate -System $selectedSystem }
    $destination = Get-DestinationPath -System $selectedSystem -File $file

    Write-Host ''
    Write-Host 'Planned operation:' -ForegroundColor Cyan
    Write-Host "  Source:      $($file.FullName)"
    Write-Host "  Destination: $destination"
    Write-Host ''

    $confirmation = Read-Host 'Rename and move this file? (Y/N)'
    if ($confirmation -notmatch '^[Yy]$') {
        Write-Host 'Operation cancelled. No files were changed.' -ForegroundColor Yellow
        exit 0
    }

    Move-Item -LiteralPath $file.FullName -Destination $destination

    if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
        throw 'The move operation completed without an error, but the destination file could not be verified.'
    }

    Write-Host ''
    Write-Host 'Configuration backup stored successfully.' -ForegroundColor Green
    Write-Host "  $destination"
}
catch {
    Write-Host ''
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
