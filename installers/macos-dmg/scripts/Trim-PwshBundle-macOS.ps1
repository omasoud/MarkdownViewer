# Trim-PwshBundle-macOS.ps1
# Trims an extracted macOS PowerShell runtime to the minimum needed by MarkView.

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

Write-Host '  [2/7] Removing ref/ and preview/ directories...'
Remove-DirIfExists (Join-Path $pwshRootFull 'ref')
Remove-DirIfExists (Join-Path $pwshRootFull 'preview')

Write-Host '  [3/7] Trimming modules...'
$modulesRoot = Join-Path $pwshRootFull 'Modules'
if (Test-Path $modulesRoot) {
    $modDirs = Get-ChildItem -LiteralPath $modulesRoot -Directory -Force
    foreach ($md in $modDirs) {
        if ($KeepModuleDirs -contains $md.Name) { continue }
        Remove-DirIfExists $md.FullName
    }
}

Write-Host '  [4/7] Removing XML help files...'
Remove-Glob -root $pwshRootFull -pattern '*.xml'

Write-Host '  [5/7] Removing Roslyn/compiler assemblies...'
@(
    'Microsoft.CodeAnalysis.dll',
    'Microsoft.CodeAnalysis.CSharp.dll',
    'System.Reflection.Metadata.dll',
    'Microsoft.CSharp.dll',
    'System.CodeDom.dll'
) | ForEach-Object { Remove-FileIfExists (Join-Path $pwshRootFull $_) }

Write-Host '  [6/7] Removing diagnostics tooling...'
@(
    'createdump',
    'libmscordaccore.dylib',
    'libmscordbi.dylib',
    'libclrgcexp.dylib',
    'libclrgc.dylib',
    'libmscorrc.dylib'
) | ForEach-Object { Remove-FileIfExists (Join-Path $pwshRootFull $_) }

Get-ChildItem -LiteralPath $pwshRootFull -Filter 'libmscordaccore_*' -File -Force -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-FileIfExists $_.FullName }

Remove-DirIfExists (Join-Path $pwshRootFull 'Schemas')

@(
    'Install-PowerShellRemoting.ps1',
    'InstallPSCorePolicyDefinitions.ps1',
    'RegisterMicrosoftUpdate.ps1',
    'RegisterManifest.ps1'
) | ForEach-Object { Remove-FileIfExists (Join-Path $pwshRootFull $_) }

Write-Host '  [7/7] Removing design-time assemblies...'
@(
    'System.Windows.Forms.Design.dll',
    'System.Windows.Forms.Design.Editors.dll',
    'System.Private.ServiceModel.dll'
) | ForEach-Object { Remove-FileIfExists (Join-Path $pwshRootFull $_) }

$pwshBin = Join-Path $pwshRootFull 'pwsh'
if (Test-Path $pwshBin) {
    chmod +x $pwshBin
}

$sizeAfter = (Get-ChildItem -LiteralPath $pwshRootFull -Recurse -Force -File | Measure-Object -Property Length -Sum).Sum
$savedMB = [math]::Round(($sizeBefore - $sizeAfter) / 1MB, 1)
$afterMB = [math]::Round($sizeAfter / 1MB, 1)

Write-Host ''
Write-Host "DONE. Saved ${savedMB} MB. Trimmed size: ${afterMB} MB"
