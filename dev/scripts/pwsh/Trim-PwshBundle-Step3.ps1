# Trim-PwshBundle-Step3.ps1
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$PwshRoot = ".\pwsh",
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$pwshRootFull = (Resolve-Path $PwshRoot).Path

function RmFile($name) {
  $p = Join-Path $pwshRootFull $name
  if (Test-Path $p) {
    if ($PSCmdlet.ShouldProcess($p, "Remove file")) {
      Remove-Item -LiteralPath $p -Force:$Force
    }
  }
}

# Design-time assemblies (usually safe to remove)
RmFile "System.Windows.Forms.Design.dll"
RmFile "System.Windows.Forms.Design.Editors.dll"

# WCF/ServiceModel (often safe for your scenario)
RmFile "System.Private.ServiceModel.dll"

Write-Host "DONE. Re-run:"
Write-Host "  .\pwsh\pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Verify-MarkViewPwsh.ps1"
