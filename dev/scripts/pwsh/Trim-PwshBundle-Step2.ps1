# Trim-PwshBundle-Step2.ps1
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$PwshRoot = ".\pwsh",
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

$pwshRootFull = Resolve-Path $PwshRoot
$pwshRootFull = $pwshRootFull.Path
Write-Host $pwshRootFull

function RmFile($name) {
  $p = Join-Path $pwshRootFull $name
  if (Test-Path $p) {
    if ($PSCmdlet.ShouldProcess($p, "Remove file")) {
      Remove-Item -LiteralPath $p -Force:$Force
    }
  }
}

function RmDir2($name) {
  $p = Join-Path $pwshRootFull $name
  Write-Host $p
  if (Test-Path $p) {
    if ($PSCmdlet.ShouldProcess($p, "Remove directory recursively")) {
      Remove-Item -LiteralPath $p -Recurse -Force:$Force
    }
  }
}

# 1) Schemas (usually safe)
RmDir2 "Schemas"

# 2) Diagnostics / dump tooling (safe for normal runtime)
@(
  "createdump.exe",
  "mscordaccore.dll",
  "mscordbi.dll",
  "clrgcexp.dll",
  "clrgc.dll",
  "clretwrc.dll",
  "mscorrc.dll"
) | ForEach-Object { RmFile $_ }

# Any mscordaccore_* variant
Get-ChildItem -LiteralPath $pwshRootFull -Filter "mscordaccore_*.dll" -File -Force -ErrorAction SilentlyContinue |
  ForEach-Object {
    if ($PSCmdlet.ShouldProcess($_.FullName, "Remove file")) {
      Remove-Item -LiteralPath $_.FullName -Force:$Force
    }
  }

# 3) Setup/registration scripts (safe for app scenario)
@(
  "Install-PowerShellRemoting.ps1",
  "InstallPSCorePolicyDefinitions.ps1",
  "RegisterMicrosoftUpdate.ps1",
  "RegisterManifest.ps1"
) | ForEach-Object { RmFile $_ }

Write-Host "DONE. Re-run:"
Write-Host "  .\pwsh\pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Verify-MarkViewPwsh.ps1"
