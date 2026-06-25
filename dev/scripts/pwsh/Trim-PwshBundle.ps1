# Trim-PwshBundle.ps1
# Runs in the staging root that contains .\pwsh\ and .\app\
# Deletes:
#  - All localization dirs except en-US
#  - ref\
#  - preview\
#  - Help/doc XML files (not deps/runtimeconfig/config)
#  - WPF stack + GraphicalHost (files listed below)
#  - Roslyn (Microsoft.CodeAnalysis*.dll)
#  - Modules trimmed to Microsoft.PowerShell.Management + Microsoft.PowerShell.Utility
#
# Usage:
#   pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Trim-PwshBundle.ps1
#   pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Trim-PwshBundle.ps1 -WhatIf
#
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$PwshRoot = ".\pwsh",
  [string[]]$KeepLocaleDirs = @("en-US"),
  [string[]]$KeepModuleDirs = @("Microsoft.PowerShell.Management","Microsoft.PowerShell.Utility"),
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Remove-DirIfExists([string]$path) {
  if (Test-Path $path) {
    if ($PSCmdlet.ShouldProcess($path, "Remove directory recursively")) {
      Remove-Item -LiteralPath $path -Recurse -Force:$Force -ErrorAction Stop
    }
  }
}

function Remove-FileIfExists([string]$path) {
  if (Test-Path $path) {
    if ($PSCmdlet.ShouldProcess($path, "Remove file")) {
      Remove-Item -LiteralPath $path -Force:$Force -ErrorAction Stop
    }
  }
}

function Remove-Glob([string]$root, [string]$pattern, [string[]]$excludeNames = @()) {
  $items = Get-ChildItem -LiteralPath $root -Filter $pattern -File -Force -ErrorAction SilentlyContinue
  foreach ($it in $items) {
    if ($excludeNames -contains $it.Name) { continue }
    Remove-FileIfExists $it.FullName
  }
}

$pwshRootFull = Resolve-Path $PwshRoot
$pwshRootFull = $pwshRootFull.Path

Write-Host "PwshRoot: $pwshRootFull"

# --- 1) Remove locale dirs except KeepLocaleDirs (only at pwsh root) ---
$localeDirs = @(
  Get-ChildItem -LiteralPath $pwshRootFull -Directory -Force |
    Where-Object { $_.Name -match '^[a-z]{2}(-[A-Za-z]{2,4})?$' -or $_.Name -match '^[a-z]{2,3}-[A-Za-z]{4}$' -or $_.Name -match '^zh-(Hans|Hant)$' }
)

foreach ($d in $localeDirs) {
  if ($KeepLocaleDirs -contains $d.Name) { continue }
  Remove-DirIfExists $d.FullName
}

# --- 2) Remove ref\ and preview\ ---
Remove-DirIfExists (Join-Path $pwshRootFull 'ref')
Remove-DirIfExists (Join-Path $pwshRootFull 'preview')

# --- 3) Trim Modules\ to a minimal set ---
$modulesRoot = Join-Path $pwshRootFull 'Modules'
if (Test-Path $modulesRoot) {
  $modDirs = Get-ChildItem -LiteralPath $modulesRoot -Directory -Force
  foreach ($md in $modDirs) {
    if ($KeepModuleDirs -contains $md.Name) { continue }
    Remove-DirIfExists $md.FullName
  }
} else {
  Write-Warning "Modules folder not found: $modulesRoot"
}

# --- 4) Remove help/docs XML files in pwsh root (keep deps/runtimeconfig/config) ---
$xmlKeep = @(
  'pwsh.deps.json',              # not xml, here for clarity
  'pwsh.runtimeconfig.json',     # not xml
  'powershell.config.json'       # not xml
)

# Remove *.xml, but keep any file that is required by policy (none are required by runtime here)
Remove-Glob -root $pwshRootFull -pattern '*.xml' -excludeNames @()

# --- 5) Remove Roslyn (checks were negative) ---
Remove-FileIfExists (Join-Path $pwshRootFull 'Microsoft.CodeAnalysis.dll')
Remove-FileIfExists (Join-Path $pwshRootFull 'Microsoft.CodeAnalysis.CSharp.dll')
Remove-FileIfExists (Join-Path $pwshRootFull 'System.Reflection.Metadata.dll')
Remove-FileIfExists (Join-Path $pwshRootFull 'Microsoft.CSharp.dll')
Remove-FileIfExists (Join-Path $pwshRootFull 'System.CodeDom.dll')

# --- 6) Remove WPF stack + GraphicalHost (checks were negative) ---
$wpfFiles = @(
  # PowerShell graphical host
  'Microsoft.PowerShell.GraphicalHost.dll',
  'Microsoft.PowerShell.GraphicalHost.dll.config',

  # Core WPF assemblies
  'PresentationFramework.dll',
  'PresentationCore.dll',
  'WindowsBase.dll',
  'System.Xaml.dll',
  'ReachFramework.dll',
  'PresentationUI.dll',
  'System.Printing.dll',
  'WindowsFormsIntegration.dll',

  # WPF native/runtime bits commonly present in the pwsh bundle
  'wpfgfx_cor3.dll',
  'PresentationNative_cor3.dll',
  'D3DCompiler_47_cor3.dll',
  'PenImc_cor3.dll',
  'DirectWriteForwarder.dll',
  'System.Private.Windows.Core.dll',
  'System.Windows.Presentation.dll',
  'System.Windows.dll',
  'System.Windows.Extensions.dll',
  'System.Windows.Input.Manipulations.dll',

  # Optional WPF theme/framework satellite assemblies present in your listing
  'PresentationFramework.Aero.dll',
  'PresentationFramework.Aero2.dll',
  'PresentationFramework.AeroLite.dll',
  'PresentationFramework.Classic.dll',
  'PresentationFramework.Fluent.dll',
  'PresentationFramework.Luna.dll',
  'PresentationFramework.Royale.dll',
  'PresentationFramework-SystemCore.dll',
  'PresentationFramework-SystemData.dll',
  'PresentationFramework-SystemDrawing.dll',
  'PresentationFramework-SystemXml.dll',
  'PresentationFramework-SystemXmlLinq.dll'
)

foreach ($f in $wpfFiles) {
  Remove-FileIfExists (Join-Path $pwshRootFull $f)
}

# --- 7) Optional: remove Schemas\ (typically only for formatting/metadata; keep if unsure)
# Commented out by default.
# Remove-DirIfExists (Join-Path $pwshRootFull 'Schemas')

Write-Host "DONE. Re-run your verifier:"
Write-Host "  .\pwsh\pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Verify-MarkViewPwsh.ps1"
