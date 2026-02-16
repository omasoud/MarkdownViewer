# Trim-PwshBundle-Linux.ps1
# Trims an extracted PowerShell runtime for Linux to the minimum needed by MarkView.
# Adapted from the Windows trimming scripts (Trim-PwshBundle.ps1 + Step2 + Step3).
#
# Deletes:
#  - All localization dirs except en-US
#  - ref/, preview/ directories
#  - Help/doc XML files
#  - Roslyn compiler DLLs
#  - Diagnostics / dump tooling (createdump, mscordaccore, etc.)
#  - Setup/registration scripts
#  - Modules trimmed to Microsoft.PowerShell.Management + Microsoft.PowerShell.Utility
#
# Usage:
#   pwsh -NoProfile -File Trim-PwshBundle-Linux.ps1 -PwshRoot ./pwsh
#   pwsh -NoProfile -File Trim-PwshBundle-Linux.ps1 -PwshRoot ./pwsh -WhatIf

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$PwshRoot = './pwsh',
    [string[]]$KeepLocaleDirs = @('en-US'),
    [string[]]$KeepModuleDirs = @('Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Utility'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Remove-DirIfExists([string]$path) {
    if (Test-Path $path) {
        if ($PSCmdlet.ShouldProcess($path, 'Remove directory recursively')) {
            Remove-Item -LiteralPath $path -Recurse -Force:$Force -ErrorAction Stop
        }
    }
}

function Remove-FileIfExists([string]$path) {
    if (Test-Path $path) {
        if ($PSCmdlet.ShouldProcess($path, 'Remove file')) {
            Remove-Item -LiteralPath $path -Force:$Force -ErrorAction Stop
        }
    }
}

function Remove-Glob([string]$root, [string]$pattern) {
    $items = Get-ChildItem -LiteralPath $root -Filter $pattern -File -Force -ErrorAction SilentlyContinue
    foreach ($it in $items) {
        Remove-FileIfExists $it.FullName
    }
}

$pwshRootFull = (Resolve-Path $PwshRoot).Path
Write-Host "PwshRoot: $pwshRootFull"

$sizeBefore = (Get-ChildItem -LiteralPath $pwshRootFull -Recurse -Force -File | Measure-Object -Property Length -Sum).Sum

# --- 1) Remove locale dirs except KeepLocaleDirs ---
Write-Host '  [1/7] Removing non-en-US locale directories...'
$localeDirs = @(
    Get-ChildItem -LiteralPath $pwshRootFull -Directory -Force |
        Where-Object {
            $_.Name -match '^[a-z]{2}(-[A-Za-z]{2,4})?$' -or
            $_.Name -match '^[a-z]{2,3}-[A-Za-z]{4}$' -or
            $_.Name -match '^zh-(Hans|Hant)$'
        }
)
foreach ($d in $localeDirs) {
    if ($KeepLocaleDirs -contains $d.Name) { continue }
    Remove-DirIfExists $d.FullName
}

# --- 2) Remove ref/ and preview/ ---
Write-Host '  [2/7] Removing ref/ and preview/ directories...'
Remove-DirIfExists (Join-Path $pwshRootFull 'ref')
Remove-DirIfExists (Join-Path $pwshRootFull 'preview')

# --- 3) Trim Modules/ to minimal set ---
Write-Host '  [3/7] Trimming modules...'
$modulesRoot = Join-Path $pwshRootFull 'Modules'
if (Test-Path $modulesRoot) {
    $modDirs = Get-ChildItem -LiteralPath $modulesRoot -Directory -Force
    foreach ($md in $modDirs) {
        if ($KeepModuleDirs -contains $md.Name) { continue }
        Remove-DirIfExists $md.FullName
    }
}

# --- 4) Remove help/docs XML files ---
Write-Host '  [4/7] Removing XML help files...'
Remove-Glob -root $pwshRootFull -pattern '*.xml'

# --- 5) Remove Roslyn compiler DLLs ---
Write-Host '  [5/7] Removing Roslyn/compiler DLLs...'
@(
    'Microsoft.CodeAnalysis.dll',
    'Microsoft.CodeAnalysis.CSharp.dll',
    'System.Collections.Immutable.dll',
    'System.Reflection.Metadata.dll',
    'Microsoft.CSharp.dll',
    'System.CodeDom.dll'
) | ForEach-Object { Remove-FileIfExists (Join-Path $pwshRootFull $_) }

# --- 6) Remove diagnostics / dump tooling ---
Write-Host '  [6/7] Removing diagnostics tooling...'
@(
    'createdump',
    'libmscordaccore.so',
    'libmscordbi.so',
    'libclrgcexp.so',
    'libclrgc.so',
    'libclretwrc.so',
    'libmscorrc.so'
) | ForEach-Object { Remove-FileIfExists (Join-Path $pwshRootFull $_) }

# Also remove any mscordaccore_* variants
Get-ChildItem -LiteralPath $pwshRootFull -Filter 'libmscordaccore_*' -File -Force -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-FileIfExists $_.FullName }

# Remove Schemas/ directory
Remove-DirIfExists (Join-Path $pwshRootFull 'Schemas')

# Remove setup/registration scripts (if present on Linux builds)
@(
    'Install-PowerShellRemoting.ps1',
    'InstallPSCorePolicyDefinitions.ps1',
    'RegisterMicrosoftUpdate.ps1',
    'RegisterManifest.ps1'
) | ForEach-Object { Remove-FileIfExists (Join-Path $pwshRootFull $_) }

# --- 7) Remove design-time / WCF assemblies (Step3 items) ---
Write-Host '  [7/7] Removing design-time assemblies...'
@(
    'System.Windows.Forms.Design.dll',
    'System.Windows.Forms.Design.Editors.dll',
    'System.Private.ServiceModel.dll'
) | ForEach-Object { Remove-FileIfExists (Join-Path $pwshRootFull $_) }

$sizeAfter = (Get-ChildItem -LiteralPath $pwshRootFull -Recurse -Force -File | Measure-Object -Property Length -Sum).Sum
$savedMB = [math]::Round(($sizeBefore - $sizeAfter) / 1MB, 1)
$afterMB = [math]::Round($sizeAfter / 1MB, 1)

# Ensure pwsh binary retains execute permission
$pwshBin = Join-Path $pwshRootFull 'pwsh'
if ((Test-Path $pwshBin) -and $IsLinux) {
    chmod +x $pwshBin
}

Write-Host ''
Write-Host "DONE. Saved ${savedMB} MB. Trimmed size: ${afterMB} MB"
Write-Host "Verify with:"
Write-Host "  pwsh -NoProfile -File $(Split-Path $MyInvocation.MyCommand.Path -Parent)/Verify-MarkViewPwsh-Linux.ps1"
